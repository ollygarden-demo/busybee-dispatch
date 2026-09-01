require "rails_helper"

RSpec.describe RoutingClient do
  subject(:client) { described_class.new(connection: connection) }

  let(:connection) { instance_double(Faraday::Connection) }
  let(:circuit) { double(run: response) }
  let(:point) { Struct.new(:x, :y).new(13.4, 52.5) }

  before { allow(Circuitbox).to receive(:circuit).and_return(circuit) }

  context "with a valid response" do
    let(:response) { double(status: 200, success?: true, body: { "eta_seconds" => 240 }) }

    it "returns the ETA" do
      expect(client.eta_seconds(origin: point, destination: point)).to eq(240)
    end
  end

  context "with a malformed response" do
    let(:response) { double(status: 200, success?: true, body: {}) }

    it "classifies the failure as permanent" do
      expect { client.eta_seconds(origin: point, destination: point) }
        .to raise_error(RoutingClient::PermanentError)
    end
  end
end
