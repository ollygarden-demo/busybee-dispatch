class Courier < ApplicationRecord
  AVAILABILITIES = %w[offline available reserved carrying].freeze

  has_many :deliveries, dependent: :restrict_with_error

  validates :name, presence: true
  validates :availability, inclusion: { in: AVAILABILITIES }

  def update_location(coordinates:, availability:, observed_at:)
    return false if location_observed_at && observed_at <= location_observed_at

    update(
      location: Geo.point(coordinates),
      availability: availability,
      location_observed_at: observed_at
    )
  end
end
