class DeliveryStateMachine
  include Statesman::Machine

  state :pending, initial: true
  state :assigning
  state :assigned
  state :picked_up
  state :delivered
  state :cancelled
  state :failed

  transition from: :pending, to: %i[assigning cancelled]
  transition from: :assigning, to: %i[assigned pending failed cancelled]
  transition from: :assigned, to: %i[picked_up pending cancelled failed]
  transition from: :picked_up, to: %i[delivered failed]
end
