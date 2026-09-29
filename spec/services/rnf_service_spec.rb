# frozen_string_literal: true

describe RNFService do
  describe '#call' do
    let(:rnf_id) { '075-FDD-00003-01' }
    let(:url) { described_class.new.send(:url) }

    before do
      stub_request(:get, "#{url}/#{rnf_id}").to_return(body: '{}')
      allow(Typhoeus).to receive(:get).and_call_original
    end

    it 'gets the CA bundle attached to the domain, and leaves the TLS verification on' do
      described_class.new.(rnf_id:)

      expect(Typhoeus).to have_received(:get).with(anything, hash_including(cainfo: API::Client::CA_BUNDLES.fetch(URI(API_RNF_URL).host)))
      expect(Typhoeus).to have_received(:get).with(anything, hash_excluding(:ssl_verifypeer, :ssl_verifyhost))
    end
  end
end
