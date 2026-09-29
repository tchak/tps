# frozen_string_literal: true

require 'rails_helper'

describe API::Client do
  describe 'CA_BUNDLES' do
    it 'holds only the root CA published at interieur.gouv.fr/IGC/Certificat' do
      anchors = OpenSSL::X509::Certificate.load(File.read(described_class::CA_BUNDLES.fetch(URI(API_RNF_URL).host)))

      expect(anchors.map { OpenSSL::Digest::SHA256.hexdigest(it.to_der) })
        .to eq(['79a1c910207c63a9875641c3955ccd1341338a5c5ebd8276846f8d2b3ce16727'])
    end
  end

  describe '#call' do
    let(:response) { instance_double(Typhoeus::Response, success?: true, body: '{}', code: 200, headers: { 'content-type' => 'application/json' }) }

    # le bundle suit le domaine appelé : le RNF comme un référentiel configuré sur la même API
    it 'passes the CA bundle of the called domain, and nothing on the other domains' do
      allow(Typhoeus).to receive(:get).and_return(response)

      described_class.new.call(url: "#{API_RNF_URL}/api/foundations/075-FDD-00003-01")
      described_class.new.call(url: "https://example.org/thing")

      expect(Typhoeus).to have_received(:get).with(anything, hash_including(cainfo: described_class::CA_BUNDLES.fetch(URI(API_RNF_URL).host)))
      expect(Typhoeus).to have_received(:get).with("https://example.org/thing", hash_excluding(:cainfo))
    end

    it 'sends a body on a PUT' do
      allow(Typhoeus).to receive(:put).and_return(response)

      described_class.new.call(url: URI("https://example.org/thing"), json: { a: 1 }, method: :put)

      expect(Typhoeus).to have_received(:put).with(URI("https://example.org/thing"), hash_including(body: '{"a":1}'))
    end
  end

  describe '#handle_response' do
    let(:client) { described_class.new }
    let(:response) { instance_double(Typhoeus::Response, success?: success, body: body, code: code, headers: headers) }
    let(:schema) { instance_double('Schema', valid?: schema_valid, validate: schema_errors) }

    subject { client.send(:handle_response, response, schema: schema) }

    context 'when response is successful' do
      let(:success) { true }
      let(:headers) { { 'content-type' => 'application/json' } }

      context 'and body is a valid JSON object' do
        let(:body) { '{"key":"value"}' }
        let(:code) { 200 }
        let(:schema_valid) { true }
        let(:schema_errors) { [] }

        it 'returns a Success with parsed body' do
          expect(subject).to be_a(Dry::Monads::Success)
          expect(subject.value!.body).to eq({ key: 'value' })
        end
      end

      context 'and body is a valid JSON array' do
        let(:body) { '[{"key":"value"}]' }
        let(:code) { 200 }
        let(:schema_valid) { true }
        let(:schema_errors) { [] }

        it 'returns a Success with parsed array' do
          expect(subject).to be_a(Dry::Monads::Success)
          expect(subject.value!.body).to eq([{ key: 'value' }])
        end
      end

      context 'and body is plain text' do
        let(:headers) { { 'content-type' => 'text/plain' } }
        let(:body) { 'plain text body' }
        let(:code) { 200 }
        let(:schema_valid) { true }
        let(:schema_errors) { [] }

        it 'returns a Success with plain text body' do
          expect(subject).to be_a(Dry::Monads::Success)
          expect(subject.value!.body).to eq('plain text body')
        end
      end

      context 'and schema validation fails' do
        let(:body) { '{"key":"value"}' }
        let(:code) { 200 }
        let(:schema_valid) { false }
        let(:schema_errors) { ['error'] }

        it 'returns a Failure with schema error' do
          expect(subject).to be_a(Dry::Monads::Failure)
          expect(subject.failure.type).to eq(:schema)
        end
      end
    end

    context 'when response is a failure' do
      let(:response) { instance_double(Typhoeus::Response, effective_url: 'https://evil.com/path', timed_out?: false, success?: false, body: '', code: 500, return_message: 'ko', total_time: 0, connect_time: 0, headers: {}) }

      subject { client.send(:handle_response, response, schema: nil) }

      it 'returns a Failure with HTTP error' do
        expect(subject).to be_a(Dry::Monads::Failure)
        expect(subject.failure.type).to eq(:http)
      end
    end

    context 'when response times out' do
      let(:response) { instance_double(Typhoeus::Response, effective_url: 'https://evil.com/path', timed_out?: true, success?: false, body: '', code: 500, return_message: 'ko', total_time: 0, connect_time: 0, headers: {}) }

      subject { client.send(:handle_response, response, schema: nil) }

      it 'returns a Failure with timeout error' do
        expect(subject).to be_a(Dry::Monads::Failure)
        expect(subject.failure.type).to eq(:timeout)
      end
    end
  end
end
