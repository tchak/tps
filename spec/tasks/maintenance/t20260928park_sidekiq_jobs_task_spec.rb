# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20260928parkSidekiqJobsTask do
    describe "#process" do
      let(:adapter) { ActiveJob::QueueAdapters::SidekiqAdapter.new }
      let(:default) { Sidekiq::Queue.new("default") }
      let(:garage) { Sidekiq::Queue.new("garage") }
      let(:retries) { Sidekiq::RetrySet.new }
      let(:scheduled) { Sidekiq::ScheduledSet.new }

      after { [default, garage, retries, scheduled].each(&:clear) }

      def run!(action)
        described_class.new.tap do
          it.job_class = "APIEntreprise::BilansBdfJob"
          it.action = action
        end.process
      end

      def retrying(job)
        item = {
          "class" => "Sidekiq::ActiveJob::Wrapper",
          "wrapped" => job.class.name,
          "queue" => job.queue_name,
          "args" => [job.serialize],
          "jid" => "retrying",
          "retry_count" => 3,
        }
        Sidekiq.redis { it.zadd("retry", 1.hour.from_now.to_f, Sidekiq.dump_json(item)) }
        item["jid"]
      end

      let!(:jids) do
        [
          adapter.enqueue(APIEntreprise::BilansBdfJob.new(1, 2)),
          retrying(APIEntreprise::BilansBdfJob.new(3, 4)),
          adapter.enqueue_at(APIEntreprise::BilansBdfJob.new(5, 6), 1.hour.from_now.to_f),
        ]
      end

      before { adapter.enqueue(APIEntreprise::TvaJob.new(7)) }

      it "parks the enqueued, retrying and scheduled jobs of the class in the garage" do
        run!("park")

        expect(garage.map(&:jid)).to match_array(jids)
        expect(garage.map { it["queue"] }.uniq).to eq(["garage"])
        expect(default.map(&:display_class)).to eq(["APIEntreprise::TvaJob"])
        expect(retries.size).to eq(0)
        expect(scheduled.size).to eq(0)
      end

      it "releases them back to their queue, one every 20 seconds" do
        run!("park")

        freeze_time do
          run!("release")

          expect(garage.size).to eq(0)
          expect(scheduled.map(&:jid)).to match_array(jids)
          expect(scheduled.map { it["queue"] }.uniq).to eq(["default"])
          expect(scheduled.map { (it.score - Time.current.to_f).round }.sort).to eq([20, 40, 60])
        end
      end
    end
  end
end
