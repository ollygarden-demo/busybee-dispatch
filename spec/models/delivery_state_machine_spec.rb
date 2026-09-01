require "rails_helper"

RSpec.describe DeliveryStateMachine do
  subject(:machine) { described_class.new(Object.new) }

  it "allows the happy-path transitions" do
    expect(machine.allowed_transitions).to contain_exactly("assigning", "cancelled")
  end

  it "does not allow terminal states to transition" do
    machine.transition_to!(:assigning)
    machine.transition_to!(:assigned)
    machine.transition_to!(:picked_up)
    machine.transition_to!(:delivered)

    expect(machine.allowed_transitions).to be_empty
  end
end
