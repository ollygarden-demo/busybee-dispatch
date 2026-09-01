class DispatchAttempt < ApplicationRecord
  belongs_to :delivery
  belongs_to :courier, optional: true

  validates :outcome, presence: true
  validates :duration_ms, numericality: { greater_than_or_equal_to: 0 }
end
