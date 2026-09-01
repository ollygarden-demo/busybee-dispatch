require "rails_helper"

RSpec.describe OutboxDispatcherJob do
  it "enqueues and marks a pending assignment event as dispatched" do
    event = OutboxEvent.create!(
      event_type: "assignment_requested",
      aggregate_id: SecureRandom.uuid,
      payload: {}
    )
    allow(AssignmentJob).to receive(:perform_async)

    described_class.new.perform

    expect(AssignmentJob).to have_received(:perform_async).with(event.aggregate_id)
    expect(event.reload.dispatched_at).to be_present
  end
end
