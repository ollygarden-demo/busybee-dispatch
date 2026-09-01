class AssignmentJob
  include Sidekiq::Job

  sidekiq_options queue: :dispatch, retry: 5, lock: :until_executed, lock_args_method: :lock_args

  def self.lock_args(args)
    [args.first]
  end

  def perform(delivery_id)
    result = AssignmentService.new(Delivery.find(delivery_id)).call
    raise "Assignment will be retried: #{result.reason}" if result.outcome == :transient

    Rails.logger.info("Assignment job finished with #{result.outcome}")
  end
end
