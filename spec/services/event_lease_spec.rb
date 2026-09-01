require "rails_helper"

RSpec.describe EventLease do
  let(:client) { Aws::DynamoDB::Client.new(stub_responses: true) }

  before { allow(AwsClients).to receive(:dynamodb).and_return(client) }

  it "recognizes a completed lease that has not reached its TTL" do
    client.stub_responses(:put_item, "ConditionalCheckFailedException")
    client.stub_responses(:get_item, item: { "event_id" => "event", "status" => "complete", "expires_at" => 1.hour.from_now.to_i })

    expect(described_class.acquire("event")).to eq(described_class::COMPLETED)
  end

  it "does not acknowledge an event with an active processing lease" do
    client.stub_responses(:put_item, "ConditionalCheckFailedException")
    client.stub_responses(:get_item, item: { "event_id" => "event", "status" => "processing", "expires_at" => 1.hour.from_now.to_i })

    expect { described_class.acquire("event") }.to raise_error(described_class::Unavailable)
  end
end
