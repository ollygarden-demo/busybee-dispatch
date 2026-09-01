class EventLease
  class Unavailable < StandardError; end

  COMPLETED = :completed
  TABLE_NAME = ENV.fetch("EVENT_LEASE_TABLE", "busybee-consumed-events")
  LEASE_SECONDS = 90
  TTL_SECONDS = 24.hours.to_i

  def self.acquire(event_id)
    token = SecureRandom.uuid
    now = Time.current.to_i
    AwsClients.dynamodb.put_item(
      table_name: TABLE_NAME,
      item: {
        "event_id" => event_id,
        "status" => "processing",
        "lease_token" => token,
        "lease_expires_at" => now + LEASE_SECONDS,
        "expires_at" => now + TTL_SECONDS
      },
      condition_expression: "attribute_not_exists(event_id) OR #expires_at < :now OR (#status = :processing AND lease_expires_at < :now)",
      expression_attribute_names: { "#expires_at" => "expires_at", "#status" => "status" },
      expression_attribute_values: { ":processing" => "processing", ":now" => now }
    )
    token
  rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException
    item = AwsClients.dynamodb.get_item(
      table_name: TABLE_NAME,
      key: { "event_id" => event_id },
      consistent_read: true
    ).item
    return COMPLETED if item["status"] == "complete" && item["expires_at"].to_i > now

    raise Unavailable, "event is already being processed"
  end

  def self.complete(event_id, token)
    AwsClients.dynamodb.update_item(
      table_name: TABLE_NAME,
      key: { "event_id" => event_id },
      update_expression: "SET #status = :complete REMOVE lease_token, lease_expires_at",
      condition_expression: "lease_token = :token",
      expression_attribute_names: { "#status" => "status" },
      expression_attribute_values: { ":complete" => "complete", ":token" => token }
    )
  end

  def self.release(event_id, token)
    AwsClients.dynamodb.delete_item(
      table_name: TABLE_NAME,
      key: { "event_id" => event_id },
      condition_expression: "lease_token = :token",
      expression_attribute_values: { ":token" => token }
    )
  rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException
    nil
  end
end
