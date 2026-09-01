module Geo
  module_function

  def point(coordinates)
    longitude, latitude = coordinates
    raise ArgumentError, "coordinates must be finite numbers" unless [longitude, latitude].all? { |value| value.is_a?(Numeric) && value.finite? }
    raise ArgumentError, "longitude is out of range" unless (-180.0..180.0).cover?(longitude)
    raise ArgumentError, "latitude is out of range" unless (-90.0..90.0).cover?(latitude)

    factory.point(longitude, latitude)
  end

  def coordinates(point)
    [point.longitude, point.latitude]
  end

  def factory
    @factory ||= RGeo::Geographic.spherical_factory(srid: 4326)
  end
end
