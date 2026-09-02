# BusyBee Dispatch

BusyBee Dispatch is a small Rails delivery API built as a realistic starting point for a Rose instrumentation demo. The application keeps a handful of plain Rails log messages and adds minimal OpenTelemetry instrumentation at its meaningful technical and business boundaries. A local Grafana LGTM backend is included for inspection.

The application uses PostgreSQL/PostGIS for delivery and courier state, Redis and Sidekiq for internal jobs, SQS and Shoryuken for inbound events, and a fault-controllable routing service for outbound HTTP behavior. LocalStack supplies the AWS services locally.

## Run it

The host needs Docker with either `docker compose` or `docker-compose`, plus `curl` and `uuidgen`.

```sh
script/setup
curl http://localhost:3000/health
```

`script/setup` starts the dependencies, prepares and seeds the database, and starts the API and workers. The development JWT secret and LocalStack credentials are local-only placeholders.

Useful commands:

```sh
docker compose logs -f api sidekiq shoryuken
docker compose run --rm api bundle exec rspec
docker compose down
```

## Local telemetry backend

Grafana is available at <http://localhost:3001>. LGTM exposes OTLP/gRPC on
`localhost:4317` and OTLP/HTTP on `localhost:4318`; the application sends telemetry to
LGTM over OTLP/HTTP. LGTM data is stored in the `lgtm-data` Docker
volume and survives `docker compose down`; use `docker compose down --volumes` to remove it.
Set `BUSYBEE_API_PORT`, `BUSYBEE_OTLP_GRPC_PORT`, or `BUSYBEE_OTLP_HTTP_PORT` before
starting Compose when one of the default host ports is already occupied.

The Rack, Action Pack, Active Record, Redis, Faraday, AWS SDK, Sidekiq, and Logger contrib
instrumentations are enabled explicitly; Rack suppresses `/health` server spans. The Shoryuken consumer uses a small manual
receive span and converts AWS message-attribute objects to string carriers before W3C
extraction. Assignment and delivery-event workflows add bounded business spans and
metrics; existing Rails logs are exported with trace and span correlation. Compose uses
100% trace sampling for deterministic local demos; production should set
`OTEL_TRACES_SAMPLER_ARG` to an appropriate ratio.

In Grafana, inspect traces in Explore with the Tempo data source, metrics in Explore
with Prometheus, and logs in Explore with Loki. Filter all three by
`service.name="busybee-dispatch"`.

See [the instrumentation overview](docs/instrumentation.md) for an example trace.

The seed is repeatable. It restores one Berlin hub and three couriers without changing the availability of couriers attached to active deliveries.

## Demo scenarios

Run a scenario against the Compose stack with `script/demo NAME`:

```sh
script/demo happy-path
script/demo no-courier
script/demo slow-routing
script/demo circuit-open
script/demo duplicate-event
script/demo lock-contention
script/demo queue-backlog
script/demo aws-retry
script/demo invalid-event
```

Each invocation stops the workers, clears prior demo queues and deliveries, reseeds reference data, resets routing and circuit state, and restarts the workers. `queue-backlog` briefly pauses Sidekiq, while `aws-retry` stops LocalStack long enough to verify a failed notification enters Sidekiq's retry set before succeeding after recovery. Exit traps restore paused or stopped services.

The mock routing service accepts `POST /control` with `{"mode":"normal|error|malformed","delay_ms":0,"failures":0}` and `POST /control/reset`. Application code calls `POST /route` and receives a deterministic ETA.

## Local AWS resources

LocalStack creates these resources at startup:

- `busybee-deliveries` SQS queue with `busybee-deliveries-dlq` redrive after five receives
- `busybee-events` SNS topic
- `busybee-proofs` S3 bucket
- `busybee-consumed-events` DynamoDB table with a 24-hour TTL
- `/busybee/dispatch/max_radius_m` SSM parameter
- CloudWatch API support for application calls

See [SPEC.md](SPEC.md) for the current behavior and contracts.
