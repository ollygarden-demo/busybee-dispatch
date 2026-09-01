class DispatchSummaryJob
  include Sidekiq::Job

  sidekiq_options queue: :maintenance, retry: 3

  def perform
    outcomes = DispatchAttempt.where(created_at: 1.hour.ago..).group(:outcome).count
    Rails.logger.info("Hourly dispatch summary: #{outcomes.sort.to_h}")
  end
end
