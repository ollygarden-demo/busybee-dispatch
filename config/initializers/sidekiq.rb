redis_url = ENV.fetch("REDIS_URL", "redis://redis:6379/0")

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }
  config.client_middleware do |chain|
    chain.add SidekiqUniqueJobs::Middleware::Client
  end
  config.server_middleware do |chain|
    chain.add SidekiqUniqueJobs::Middleware::Server
  end

  config.on(:startup) do
    Sidekiq::Cron::Job.create(name: "dispatch stale delivery expiration", cron: "*/5 * * * *", class: "ExpireStaleDeliveriesJob")
    Sidekiq::Cron::Job.create(name: "dispatch proof reconciliation", cron: "*/10 * * * *", class: "ReconcileProofsJob")
    Sidekiq::Cron::Job.create(name: "dispatch hourly summary", cron: "0 * * * *", class: "DispatchSummaryJob")
    Sidekiq::Cron::Job.create(name: "dispatch outbox", cron: "* * * * *", class: "OutboxDispatcherJob")
  end
end

Sidekiq.configure_client { |config| config.redis = { url: redis_url } }
