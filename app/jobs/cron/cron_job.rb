class Cron::CronJob < ApplicationJob
  queue_as :cron
  class_attribute :schedule_expression

  class << self
    def schedulable?
      true && ENV['CRON_JOBS_DISABLED'].blank?
    end

    def schedule
      remove if cron_expression_changed?

      if !scheduled?
        if SIDEKIQ_ENABLED
          Sidekiq::Cron::Job.create(name: name, cron: cron_expression, class: name)
        else
          set(cron: cron_expression).perform_later
        end
      end
    end

    def remove
      enqueued_cron_job.destroy if scheduled?
    end

    def display_schedule
      pp "#{name}: #{schedule_expression} cron(#{cron_expression})"
    end

    def scheduled?
      enqueued_cron_job.present?
    end

    def cron_expression_changed?
      scheduled? && enqueued_cron_job.cron != cron_expression
    end

    def enqueued_cron_job
      if SIDEKIQ_ENABLED
        sidekiq_cron_job
      else
        delayed_job
      end
    end

    def sidekiq_cron_job
      Sidekiq::Cron::Job.find(name)
    end

    def delayed_job
      Delayed::Job
        .where('handler LIKE ?', "%job_class: #{name}%")
        .first
    end

    def cron_expression
      Fugit.do_parse(schedule_expression, multi: :fail).to_cron_s
    end
  end
end
