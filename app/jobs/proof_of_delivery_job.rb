class ProofOfDeliveryJob
  include Sidekiq::Job

  sidekiq_options queue: :storage, retry: 5

  def perform(outbox_event_id)
    event = OutboxEvent.find(outbox_event_id)
    delivery = Delivery.find(event.aggregate_id)
    return if delivery.proof_stored_at?

    AwsClients.s3.put_object(
      bucket: ENV.fetch("PROOF_BUCKET"),
      key: "deliveries/#{delivery.id}/proof.json",
      body: JSON.generate(event.payload.fetch("proof")),
      content_type: "application/json"
    )
    delivery.update!(proof_stored_at: Time.current)
  end
end
