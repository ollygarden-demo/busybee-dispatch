require "rails_helper"

RSpec.describe Geo do
  describe ".point" do
    it "uses GeoJSON longitude, latitude order" do
      point = described_class.point([13.405, 52.52])

      expect(described_class.coordinates(point)).to eq([13.405, 52.52])
    end

    it "rejects out-of-range coordinates" do
      expect { described_class.point([181, 52.52]) }.to raise_error(ArgumentError, /longitude/)
    end
  end
end
