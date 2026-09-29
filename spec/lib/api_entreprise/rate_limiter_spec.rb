# frozen_string_literal: true

require 'rails_helper'

describe APIEntreprise::RateLimiter do
  let(:pool) { 250 }

  before do
    Kredis.redis.del(described_class.remaining_key(pool), described_class.reset_key(pool))
  end

  after do
    Kredis.redis.del(described_class.remaining_key(pool), described_class.reset_key(pool))
  end

  describe '.throttled?' do
    context 'when Redis has no state' do
      it 'returns false' do
        expect(described_class.throttled?(pool)).to be false
      end
    end

    context 'when remaining > 0' do
      before { Kredis.redis.set(described_class.remaining_key(pool), 10, ex: 60) }

      it 'returns false' do
        expect(described_class.throttled?(pool)).to be false
      end
    end

    context 'when remaining = 0' do
      before { Kredis.redis.set(described_class.remaining_key(pool), 0, ex: 60) }

      it 'returns true' do
        expect(described_class.throttled?(pool)).to be true
      end
    end

    context 'when remaining < 0 (over-decremented)' do
      before { Kredis.redis.set(described_class.remaining_key(pool), -3, ex: 60) }

      it 'returns true' do
        expect(described_class.throttled?(pool)).to be true
      end
    end

    context 'with different pools' do
      before do
        Kredis.redis.set(described_class.remaining_key(250), 10, ex: 60)
        Kredis.redis.set(described_class.remaining_key(50), 0, ex: 60)
      end

      after do
        Kredis.redis.del(described_class.remaining_key(250), described_class.remaining_key(50))
      end

      it 'tracks each pool independently' do
        expect(described_class.throttled?(250)).to be false
        expect(described_class.throttled?(50)).to be true
      end
    end
  end

  describe '.calibrate!' do
    let(:reset_timestamp) { Time.current.to_i + 30 }

    context 'with a response containing RateLimit headers' do
      let(:response) do
        Typhoeus::Response.new(
          effective_url: 'http://host.com/path', code: 200, body: '{}',
          return_message: 'ok', total_time: 1, connect_time: 0,
          headers: { 'RateLimit-Limit' => '250', 'RateLimit-Remaining' => '42', 'RateLimit-Reset' => reset_timestamp.to_s }
        )
      end

      it 'sets remaining in Redis but not reset (remaining > 0)' do
        described_class.calibrate!(response, pool)

        expect(Kredis.redis.get(described_class.remaining_key(pool)).to_i).to eq(42)
        expect(Kredis.redis.get(described_class.reset_key(pool))).to be_nil
      end

      it 'sets TTL based on reset timestamp' do
        described_class.calibrate!(response, pool)

        ttl = Kredis.redis.ttl(described_class.remaining_key(pool))
        expect(ttl).to be_between(1, 30)
      end
    end

    context 'with lowercase ratelimit headers' do
      let(:response) do
        Typhoeus::Response.new(
          effective_url: 'http://host.com/path', code: 200, body: '{}',
          return_message: 'ok', total_time: 1, connect_time: 0,
          headers: { 'ratelimit-limit' => '250', 'ratelimit-remaining' => '42', 'ratelimit-reset' => reset_timestamp.to_s }
        )
      end

      it 'reads lowercase headers' do
        described_class.calibrate!(response, pool)
        expect(Kredis.redis.get(described_class.remaining_key(pool)).to_i).to eq(42)
      end
    end

    context 'when server limit diverges from expected pool' do
      let(:response) do
        Typhoeus::Response.new(
          effective_url: 'http://host.com/path', code: 200, body: '{}',
          return_message: 'ok', total_time: 1, connect_time: 0,
          headers: { 'RateLimit-Limit' => '100', 'RateLimit-Remaining' => '42', 'RateLimit-Reset' => reset_timestamp.to_s }
        )
      end

      it 'logs a warning and still calibrates' do
        expect(Rails.logger).to receive(:warn).with(/pool mismatch.*expected=250.*server=100/)
        described_class.calibrate!(response, pool)
        expect(Kredis.redis.get(described_class.remaining_key(pool)).to_i).to eq(42)
      end
    end

    context 'with a response without RateLimit headers' do
      let(:response) do
        Typhoeus::Response.new(
          effective_url: 'http://host.com/path', code: 200, body: '{}',
          return_message: 'ok', total_time: 1, connect_time: 0, headers: ''
        )
      end

      it 'does not write to Redis' do
        described_class.calibrate!(response, pool)
        expect(Kredis.redis.get(described_class.remaining_key(pool))).to be_nil
      end
    end

    context 'with nil response' do
      it 'does not write to Redis' do
        described_class.calibrate!(nil, pool)
        expect(Kredis.redis.get(described_class.remaining_key(pool))).to be_nil
      end
    end
  end

  describe '.wait_duration' do
    context 'when reset key is not set' do
      it 'returns 2 seconds default' do
        expect(described_class.wait_duration(pool)).to eq(2)
      end
    end

    context 'when reset is in the future' do
      before do
        Kredis.redis.set(described_class.reset_key(pool), Time.current.to_i + 25, ex: 60)
      end

      it 'returns seconds until reset' do
        expect(described_class.wait_duration(pool)).to be_between(23, 25)
      end
    end

    context 'when reset is in the past' do
      before do
        Kredis.redis.set(described_class.reset_key(pool), Time.current.to_i - 5, ex: 60)
      end

      it 'returns minimum of 2 seconds' do
        expect(described_class.wait_duration(pool)).to eq(2)
      end
    end
  end
end
