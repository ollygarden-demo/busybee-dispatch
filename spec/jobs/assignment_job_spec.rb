require "rails_helper"

RSpec.describe AssignmentJob do
  let(:delivery) { instance_double(Delivery) }

  before { allow(Delivery).to receive(:find).with("delivery-id").and_return(delivery) }

  it "finishes a successful assignment" do
    service = instance_double(AssignmentService, call: AssignmentService::Result.new(outcome: :assigned, reason: nil))
    allow(AssignmentService).to receive(:new).with(delivery).and_return(service)

    expect { described_class.new.perform("delivery-id") }.not_to raise_error
  end

  it "raises transient outcomes so Sidekiq retries them" do
    service = instance_double(AssignmentService, call: AssignmentService::Result.new(outcome: :transient, reason: "no_available_courier"))
    allow(AssignmentService).to receive(:new).with(delivery).and_return(service)

    expect { described_class.new.perform("delivery-id") }.to raise_error(/will be retried/)
  end
end
