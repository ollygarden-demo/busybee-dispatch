class Hub < ApplicationRecord
  has_many :deliveries, dependent: :restrict_with_error

  validates :name, :location, :delivery_zone, presence: true
end
