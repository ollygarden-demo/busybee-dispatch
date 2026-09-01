# BusyBee Dispatch

## Purpose

BusyBee Dispatch is a Rails 7.2 delivery dispatch API used to demonstrate a production-shaped Ruby workload. It combines geospatial assignment, stateful delivery processing, background jobs, AWS messaging, and outbound HTTP calls in a locally runnable system.

The repository is the intentionally uninstrumented baseline for a future Rose demo, not a complete logistics product. It resembles an application written by a developer who knows basic logging but has not adopted traces, metrics, or OpenTelemetry. Every included integration must generate meaningful behavior that can be exercised through deterministic scenarios.

## Goals

- Exercise Rails, Rack, Active Record, PostgreSQL, and PostGIS through realistic API traffic.
- Run asynchronous work through both Sidekiq/Redis and Shoryuken/SQS.
- Produce realistic application behavior across HTTP, database, Redis, jobs, AWS SDK calls, and outbound Faraday requests without custom observability instrumentation.
- Provide deterministic happy-path and failure scenarios for demos and automated evaluations.
- Start locally with Docker Compose and no dependency on a real AWS account.
- Remain small enough for a new contributor to understand in one session.

## Non-goals

- A customer-facing web interface.
- Production-grade route optimization or turn-by-turn navigation.
- Multi-region deployment, billing, or real courier mobile applications.
- Exhaustive use of every helper and test gem in the reference Gemfile.
- Dependence on paid services for the default local workflow.
- OpenTelemetry, Prometheus, an OpenTelemetry Collector, or a metrics endpoint in the baseline application.

## Domain

The API coordinates deliveries between hubs and recipients. A courier can be assigned when their current location is inside the hub's delivery zone and they are the nearest available courier to the pickup.

Core records:

- `Hub`: pickup location and PostGIS delivery-zone polygon.
- `Courier`: availability and last-known PostGIS location.
- `Delivery`: external ID, pickup and drop-off points, assigned courier, timing data, and current state.
- `DeliveryTransition`: append-only Statesman transition history and metadata.
- `DispatchAttempt`: assignment attempts, outcome, duration, and diagnostic information.

Delivery states:

```text
pending -> assigning -> assigned -> picked_up -> delivered
```

Cancellation, retry, and failure branches are defined explicitly below.

Statesman owns transition validation and persists the transition history. Concurrent assignment attempts are serialized with PostgreSQL advisory locks.

Allowed transitions are:

- `pending -> assigning | cancelled`
- `assigning -> assigned | pending | failed | cancelled`
- `assigned -> picked_up | pending | cancelled | failed`
- `picked_up -> delivered | failed`

An assignment retry returns `assigning` to `pending`. A courier cancellation returns `assigned` to `pending` and clears the reservation. `delivered`, `cancelled`, and `failed` are terminal. Transition attempts from a terminal state return a conflict without changing history.

All geographic columns use PostGIS `geography` with SRID 4326. API coordinates use GeoJSON order `[longitude, latitude]`; distances are meters.

## API

The first version exposes:

- `POST /api/v1/deliveries` creates a delivery and enqueues assignment.
- `GET /api/v1/deliveries/:id` returns the delivery, assignment, and state history.
- `POST /api/v1/deliveries/:id/pick_up` records pickup.
- `POST /api/v1/deliveries/:id/deliver` records completion and optional proof-of-delivery metadata.
- `POST /api/v1/deliveries/:id/cancel` cancels an active delivery.
- `PUT /api/v1/couriers/:id/location` updates courier location and availability.
- `GET /api/v1/hubs/:id/nearby_couriers` performs a bounded PostGIS proximity query.
- `GET /health` reports application, PostgreSQL, and Redis readiness.

Mutating endpoints accept an idempotency key. Controllers validate HTTP parameters, and JSON Schema defines the external event contract. Responses are JSON and use pagination for collections.

### Core contracts

`POST /api/v1/deliveries` requires an `Idempotency-Key` header and accepts:

```json
{
  "external_id": "demo-1001",
  "hub_id": "5d32c906-8b8d-4c96-aee8-4c5822ac65ec",
  "pickup": { "coordinates": [13.405, 52.52] },
  "dropoff": { "coordinates": [13.3777, 52.5163] },
  "recipient": { "name": "Demo Recipient", "phone": "+4915112345678" }
}
```

It returns `202 Accepted` with this representation shape:

```json
{
  "data": {
    "id": "daab9e2d-f8bb-477e-8a85-248f19ca061a",
    "external_id": "demo-1001",
    "hub_id": "5d32c906-8b8d-4c96-aee8-4c5822ac65ec",
    "courier_id": null,
    "state": "pending",
    "pickup": { "type": "Point", "coordinates": [13.405, 52.52] },
    "dropoff": { "type": "Point", "coordinates": [13.3777, 52.5163] },
    "eta_seconds": null,
    "created_at": "2026-09-01T12:00:00Z",
    "updated_at": "2026-09-01T12:00:00Z",
    "transitions": []
  }
}
```

Replaying the same key and canonical payload returns the original status and body. Reusing the key with a different payload returns `409 Conflict`. Errors use `{"errors":[{"code":"invalid_coordinates","path":"pickup.coordinates","message":"..."}]}`. Stable v1 codes are `validation_failed`, `invalid_coordinates`, `idempotency_conflict`, `invalid_transition`, `not_found`, `unauthorized`, and `concurrent_update`.

`PUT /api/v1/couriers/:id/location` accepts `{"coordinates":[13.4,52.5],"availability":"available","observed_at":"2026-09-01T12:00:00Z"}`. `observed_at` is required ISO 8601 UTC and older updates do not overwrite a newer location. Courier availability is a PostgreSQL enum with `offline`, `available`, `reserved`, and `carrying`; assignment changes `available` to `reserved`, pickup changes it to `carrying`, and delivery or release changes it to `available`.

Pickup accepts `{"occurred_at":"..."}`. Delivery accepts `{"occurred_at":"...","proof":{"type":"recipient_confirmation","note":"synthetic demo text"}}`; `proof` is optional, and its JSON object is stored through the outbox when present. Cancellation accepts `{"occurred_at":"...","reason":"recipient_request"}` with reason values `recipient_request`, `courier_unavailable`, or `operator_request`.

Transition endpoints return `200 OK` with the delivery representation, `404 Not Found` for unknown IDs, and `409 Conflict` for invalid or concurrent transitions. Nearby couriers returns `{"data":[{"id":"...","availability":"available","distance_m":125.4}],"meta":{"page":1,"per_page":20,"total":1}}`. Collections default to `page=1` and `per_page=20`, with a maximum page size of 100.

The SQS delivery-created event is a JSON object with no unknown top-level fields. It requires string UUIDs `event_id`, `external_id`, and `hub_id`; an ISO 8601 UTC `occurred_at`; `pickup` and `dropoff` objects containing exactly two finite numeric coordinates within longitude/latitude bounds; and a `recipient` object containing non-empty `name` and E.164 `phone` strings. The checked-in JSON Schema is the executable contract. Generated demo traffic uses globally unique UUIDs for `event_id` and `external_id`.

HTTP idempotency records are scoped to the authenticated subject and key, stored in PostgreSQL for 24 hours, and contain a request hash plus the original response. SQS idempotency uses a DynamoDB conditional write with a 24-hour TTL and a short processing lease. A failed consumer releases or expires the lease; an event is marked complete only after the database transaction commits. A unique PostgreSQL index on `deliveries.external_id` is the final cross-transport duplicate guard.

## Processing paths

### HTTP-created delivery

1. Rails validates and persists the delivery plus an `assignment_requested` outbox row in one transaction.
2. The outbox dispatcher enqueues a unique Sidekiq assignment job and marks the row dispatched.
3. The assignment job obtains an advisory lock and queries nearby couriers with PostGIS.
4. Faraday calls the mock routing service for an ETA.
5. The delivery transitions according to the failure rules below or becomes `assigned`.
6. The service publishes the outcome to SNS.

### SQS-created delivery

1. Shoryuken consumes a delivery event from SQS.
2. DynamoDB records the event ID for cross-process idempotency.
3. The same application service used by the HTTP path creates the delivery.
4. Sidekiq performs assignment and notification work.
5. Invalid events are retried and eventually sent to a dead-letter queue.

### Completion

1. The completion endpoint transitions the delivery to `delivered`.
2. Proof-of-delivery JSON is written to S3.
3. SNS receives a completion notification.
4. A periodic Sidekiq job reconciles delivered records with stored artifacts.

Database changes and outbound effects use a transactional outbox. Creating a delivery, changing its state, and recording assignment, S3, or SNS work happen in one PostgreSQL transaction. A dispatcher delivers outbox operations to Sidekiq or AWS and then marks them complete. A crash after delivery but before marking may duplicate work, so consumers remain idempotent. This prevents a committed state change from silently losing assignment, notification, or artifact work.

Courier assignment uses a maximum radius of 5,000 meters by default, loaded from SSM key `/busybee/dispatch/max_radius_m`. Candidates must be available, inside the hub delivery zone, and within the radius of the pickup. The query sorts by PostGIS distance and then courier UUID for deterministic ties. Candidate rows are locked with `FOR UPDATE SKIP LOCKED`; assignment and courier reservation commit together. A delivery-level advisory lock prevents two jobs from assigning the same delivery.

## Background work

Sidekiq handles internal work:

- courier assignment;
- route and ETA lookup;
- webhook/SNS notification;
- proof-of-delivery reconciliation;
- stale-delivery expiration;
- periodic operational summaries.

`sidekiq-unique-jobs` prevents duplicate assignment and reconciliation jobs. `sidekiq-cron` schedules expiration and summaries. Sidekiq uses Redis database 0 and Circuitbox uses Redis database 2.

Assignment jobs hold their unique lock until execution completes and retry up to five times with exponential backoff. No available courier, routing timeout, routing 5xx, and an open circuit are transient outcomes: the attempt records a reason, the delivery returns to `pending`, and retry scheduling continues. A malformed successful routing response or an impossible domain invariant is permanent and transitions the delivery to `failed` with a reason. A `pending` delivery older than 30 minutes transitions to `cancelled` with reason `assignment_timeout`; there is no separate expired state. An invalid SQS contract creates no delivery, retries five times, and then reaches the dead-letter queue. SQS visibility starts at 120 seconds and Shoryuken extends it while work remains active. A redelivery blocked by an active processing lease fails instead of acknowledging the message, and the SQS redrive policy performs the dead-letter move.

Shoryuken handles externally supplied SQS events. LocalStack supplies SQS, SNS, S3, DynamoDB, SSM, and CloudWatch in local development.

Sidekiq Pro is a private, paid dependency and is not part of this demo. The local topology and public CI use open-source Sidekiq only.

## AWS integration mapping

- SQS: inbound delivery events and dead-letter queue.
- SNS: assignment and completion notifications.
- S3: proof-of-delivery artifacts.
- DynamoDB: consumed-event idempotency records.
- SSM: runtime dispatch configuration, such as maximum assignment radius.
- CloudWatch: its LocalStack API is available for parity with the reference application's AWS footprint, but the uninstrumented baseline does not publish custom metrics.

AWS clients use endpoint overrides in development so the same application code targets LocalStack without real AWS credentials.

## Outbound HTTP and resilience

Faraday with the Typhoeus adapter calls a mock routing service. Circuitbox opens after repeated failures, and Moneta stores circuit state in Redis. The mock service supports normal, slow, error, and malformed responses.

The default circuit opens after five failures within 60 seconds and remains open for 30 seconds. Scenario scripts select fault behavior through explicit mock-service control endpoints and always reset it afterward.

## Baseline logging

The application has only sparse, ordinary Rails logs at useful lifecycle boundaries such as accepting a delivery, completing an assignment job, falling back to default configuration, and reporting an unexpected outbox event. It does not emit traces or application metrics, add trace correlation fields, expose `/metrics`, or run an OpenTelemetry Collector. Logs exclude authorization headers, tokens, event bodies, phone numbers, and precise coordinates.

This limited starting point is deliberate. A later Rose evaluation can assess the repository and propose instrumentation, but that work is outside the current application baseline.

## Demo scenarios

The repository includes scripts or rake tasks for these deterministic scenarios:

1. Happy path: create, assign, pick up, and deliver an order.
2. No courier: create a delivery outside every active courier radius.
3. Slow routing: delay the mock route API and expose request/job latency.
4. Circuit open: repeatedly fail routing until Circuitbox rejects calls.
5. Duplicate event: submit the same idempotency key and SQS event ID multiple times.
6. Lock contention: trigger concurrent assignment attempts for one delivery.
7. Queue backlog: enqueue a controlled batch of assignment jobs faster than workers consume them.
8. AWS retry: inject transient LocalStack-facing failures before successful notification.
9. Invalid event: send a payload that fails JSON Schema validation and reaches the dead-letter path.

Each scenario clears prior demo queues and deliveries, resets routing and circuit state, and reseeds reference data, so it is safe to repeat without manual cleanup.

## Local topology

Docker Compose provides:

- Rails/Puma API;
- Sidekiq worker;
- Shoryuken worker;
- PostgreSQL with PostGIS;
- Redis;
- LocalStack;
- mock routing service;
- no telemetry collector or observability backend.

## Dependency baseline

The application uses the subset of the reference dependency shape exercised by its runtime paths:

- Rails `~> 7.2.3`, Puma `~> 7.1`, Rack CORS, and Bootsnap.
- PostgreSQL through `pg ~> 1.6.2`, Active Record PostGIS Adapter `~> 10.0`, RGeo supplied by that adapter, Statesman `13.1.0`, and With Advisory Lock.
- Redis, Sidekiq, Sidekiq Unique Jobs, Sidekiq Cron, and Shoryuken `~> 6.2.1`.
- AWS SDK clients for DynamoDB, S3, SNS, SQS, and SSM.
- Faraday `~> 2.14`, Faraday Typhoeus, Circuitbox, and Moneta.
- JSON Schema and JWT for event validation and API authentication.
- RSpec Rails for tests.

Reference dependencies without a credible runtime use are omitted rather than included solely to inflate coverage.

## Security and privacy

- JWT protects mutating API endpoints; the health endpoint has an explicit access rule.
- Seed credentials are development-only and clearly marked.
- Phone-number examples and seeds use synthetic values only.
- Logs exclude authorization headers, tokens, raw event bodies, phone numbers, and precise courier coordinates.
- S3 buckets and SQS/SNS policies default to local-only development configuration.
- CI prepares PostGIS, runs the test suite, validates Compose, and checks script syntax.

The initial JWT implementation uses HMAC in local development and validates signature, expiration, issuer `busybee-dispatch`, and audience `busybee-api`. The JWT subject scopes idempotency keys. `/health` is unauthenticated. All `/api` endpoints require a valid bearer token. Production-oriented examples load secrets from environment variables or SSM and contain no committed secret value.

## Testing

The focused test suite covers geographic validation, Statesman transitions, assignment job outcomes, routing responses, SQS event processing, and Shoryuken delegation. Deterministic scenario scripts exercise the full local topology and failure branches. Tests do not contact public APIs or real AWS services.

## Acceptance criteria

- A documented command starts the full local topology.
- Database preparation creates required PostGIS extensions and deterministic seed data.
- Each demo scenario runs from a documented command and returns a clear result.
- The happy path crosses Rails, PostgreSQL/PostGIS, Redis, Sidekiq, Faraday, and at least one LocalStack AWS service.
- The SQS path crosses Shoryuken and then reuses the normal dispatch service.
- No OpenTelemetry, Prometheus, trace propagation, telemetry collector, or metrics endpoint is present in the baseline.
- Tests and static checks pass without paid credentials or external infrastructure.
- The repository contains no secrets, real customer data, or Delivery Hero branding.

## Repository conventions

- Default branch: `main`.
- Application name: `BusyBee Dispatch`.
- Repository name: `busybee-dispatch`.
- Ruby code follows conventional Rails boundaries; domain orchestration lives in explicit service objects rather than controllers or callbacks.
- Documentation describes the system as it currently works and is updated alongside behavioral changes.

Sidekiq Pro is omitted; the local topology and CI use open-source Sidekiq. Rails migrations create the PostgreSQL courier-availability enum directly. Delivery priority is outside v1.
