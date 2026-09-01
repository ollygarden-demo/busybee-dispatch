require "rails_helper"

RSpec.describe DeliveryTransitioner do
  it "releases a courier when an assigned delivery returns to pending" do
    courier = Courier.create!(name: "Demo Courier", availability: "reserved", location: Geo.point([13.4, 52.5]))
    delivery = create_delivery(courier)
    delivery.state_machine.transition_to!(:assigning)
    delivery.state_machine.transition_to!(:assigned)

    described_class.call(delivery, :pending, metadata: { reason: "courier_unavailable" })

    expect(delivery.reload.courier).to be_nil
    expect(courier.reload.availability).to eq("available")
  end

  def create_delivery(courier)
    factory = Geo.factory
    ring = factory.linear_ring([
      factory.point(13.3, 52.4), factory.point(13.5, 52.4),
      factory.point(13.5, 52.6), factory.point(13.3, 52.6), factory.point(13.3, 52.4)
    ])
    hub = Hub.create!(name: "Demo Hub", location: Geo.point([13.4, 52.5]), delivery_zone: factory.polygon(ring))
    Delivery.create!(
      hub: hub,
      courier: courier,
      external_id: SecureRandom.uuid,
      pickup: Geo.point([13.4, 52.5]),
      dropoff: Geo.point([13.41, 52.51]),
      recipient_name: "Demo Recipient",
      recipient_phone: "+4915112345678"
    )
  end
end
