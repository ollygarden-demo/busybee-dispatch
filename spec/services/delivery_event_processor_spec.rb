require "rails_helper"

RSpec.describe DeliveryEventProcessor do
  let(:event) do
    {
      event_id: "8ef34f3f-f43c-4978-b9bd-e542a5dd5634",
      external_id: "777388c7-5344-45d0-b589-fe992cfbefb7",
      hub_id: "16e310fa-586c-44b1-a97f-d7674bfcfde8",
      occurred_at: "2026-09-01T12:00:00Z",
      pickup: { coordinates: [13.405, 52.52] },
      dropoff: { coordinates: [13.3777, 52.5163] },
      recipient: { name: "Demo Recipient", phone: "+4915112345678" }
    }
  end

  it "does not acquire a lease for an invalid event" do
    event.delete(:recipient)
    expect(EventLease).not_to receive(:acquire)

    expect { described_class.call(event.to_json) }.to raise_error(described_class::InvalidEvent)
  end

  it "skips a completed event" do
    allow(EventLease).to receive(:acquire).and_return(EventLease::COMPLETED)

    expect(described_class.call(event.to_json)).to eq(:duplicate)
  end

  it "retries an event that is still being processed" do
    allow(EventLease).to receive(:acquire).and_raise(EventLease::Unavailable)

    expect { described_class.call(event.to_json) }.to raise_error(EventLease::Unavailable)
  end
end
