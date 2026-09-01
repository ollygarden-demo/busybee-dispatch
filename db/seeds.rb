factory = RGeo::Geographic.spherical_factory(srid: 4326)
ring = factory.linear_ring([
  factory.point(13.30, 52.45),
  factory.point(13.50, 52.45),
  factory.point(13.50, 52.58),
  factory.point(13.30, 52.58),
  factory.point(13.30, 52.45)
])

hub = Hub.find_or_initialize_by(id: "11111111-1111-4111-8111-111111111111")
hub.update!(name: "Berlin Mitte", location: factory.point(13.405, 52.52), delivery_zone: factory.polygon(ring))

[
  ["22222222-2222-4222-8222-222222222221", "Maya", 13.406, 52.521],
  ["22222222-2222-4222-8222-222222222222", "Noah", 13.415, 52.515],
  ["22222222-2222-4222-8222-222222222223", "Sam", 13.390, 52.525]
].each do |id, name, longitude, latitude|
  courier = Courier.find_or_initialize_by(id: id)
  active_delivery = courier.persisted? && courier.deliveries.any? { |delivery| %w[assigned picked_up].include?(delivery.current_state) }
  attributes = { name: name }
  unless active_delivery
    attributes.merge!(
      availability: "available",
      location: factory.point(longitude, latitude),
      location_observed_at: Time.current
    )
  end
  courier.update!(attributes)
end

puts "Seeded Berlin Mitte and three available couriers"
