require "rails_helper"

RSpec.describe DeliveryEventWorker do
  it "passes the unlogged message body to the event processor" do
    allow(DeliveryEventProcessor).to receive(:call).with("event-json").and_return(:created)

    described_class.new.perform(nil, "event-json")

    expect(DeliveryEventProcessor).to have_received(:call).with("event-json")
  end
end
