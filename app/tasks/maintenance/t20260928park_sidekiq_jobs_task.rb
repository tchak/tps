# frozen_string_literal: true

module Maintenance
  class T20260928parkSidekiqJobsTask < MaintenanceTasks::Task
    # Stops the jobs of a class from being processed, and resumes them later.
    #
    # park:    enqueued, retrying and scheduled jobs → `garage` queue, which no worker reads
    # release: `garage` → scheduled set, one job every 20 seconds, back to their own queue
    #
    # Jobs enqueued after a park still land in the class's queue: run it again.

    GARAGE = "garage"
    ACTIONS = ["park", "release"].freeze
    RELEASE_INTERVAL = 20.seconds

    no_collection

    attribute :job_class, :string
    validates :job_class, presence: true

    attribute :action, :string, default: "park"
    validates :action, inclusion: { in: ACTIONS }

    def process
      action == "park" ? park : release
    end

    private

    def park
      Sidekiq.redis { it.sadd("queues", GARAGE) } # lists the queue in the web UI

      queue = Sidekiq::Queue.new(job_class.constantize.queue_name)

      [queue, Sidekiq::RetrySet.new, Sidekiq::ScheduledSet.new].each do |source|
        jobs_of_class(source).each do |job|
          next unless remove(source, job)

          item = job.item.merge("queue" => GARAGE)
          Sidekiq.redis { it.lpush("queue:#{GARAGE}", Sidekiq.dump_json(item)) }
        end
      end
    end

    def release
      garage = Sidekiq::Queue.new(GARAGE)
      at = Time.current

      jobs_of_class(garage).each do |job|
        next unless remove(garage, job)

        at += RELEASE_INTERVAL
        # the ActiveJob payload still carries the queue the job was parked from
        item = job.item.merge("queue" => job.item["args"][0]["queue_name"])
        Sidekiq.redis { it.zadd("schedule", at.to_f, Sidekiq.dump_json(item)) }
      end
    end

    # Collected before removing anything: JobSet#each pages by an offset only
    # its own #delete keeps up to date, so it skips jobs removed mid-iteration.
    def jobs_of_class(source)
      source.filter { it.display_class == job_class }
    end

    # false when a worker or the scheduler took the job in the meantime
    # (SortedEntry#delete can't tell: it returns ZREM's 0 or 1, both truthy)
    def remove(source, job)
      removed = Sidekiq.redis do |conn|
        if source.is_a?(Sidekiq::Queue)
          conn.lrem("queue:#{source.name}", 1, job.value)
        else
          conn.zrem(source.name, job.value)
        end
      end
      removed == 1
    end
  end
end
