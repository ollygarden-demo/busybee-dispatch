class OutboxEvent < ApplicationRecord
  scope :pending, -> { where(dispatched_at: nil).order(:created_at) }

  validates :event_type, :aggregate_id, presence: true
end
