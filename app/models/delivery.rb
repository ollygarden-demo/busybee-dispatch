class Delivery < ApplicationRecord
  belongs_to :hub
  belongs_to :courier, optional: true
  has_many :delivery_transitions, -> { order(:sort_key) }, dependent: :destroy, inverse_of: :delivery
  has_many :dispatch_attempts, dependent: :destroy

  validates :external_id, :pickup, :dropoff, :recipient_name, :recipient_phone, presence: true
  validates :external_id, uniqueness: true
  validates :recipient_phone, format: { with: /\A\+[1-9]\d{7,14}\z/ }

  def state_machine
    @state_machine ||= DeliveryStateMachine.new(
      self,
      transition_class: DeliveryTransition,
      association_name: :delivery_transitions
    )
  end

  delegate :current_state, to: :state_machine
end
