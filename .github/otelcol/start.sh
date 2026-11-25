#!/usr/bin/env bash
# Starts the Collector in the background with the given configs and waits until its OTLP receiver answers.
# Usage: start.sh config.yaml [overlay.yaml ...]
set -euo pipefail

args=()
for config in "$@"; do args+=(--config "/etc/otelcol-ci/$config"); done

# -e passes a variable only when it is set in this step's environment.
docker run -d --name otelcol --network host \
  -v "$GITHUB_WORKSPACE/.github/otelcol:/etc/otelcol-ci:ro" \
  -e DASH0_ENDPOINT -e DASH0_AUTH_KEY -e GITHUB_TOKEN -e GITHUB_REPOSITORY -e GITHUB_REPOSITORY_OWNER \
  "$OTELCOL_IMAGE" "${args[@]}" > /dev/null

for _ in $(seq 1 30); do
  curl -s -o /dev/null http://localhost:4318/v1/traces && exit 0
  sleep 1
done

echo "::error::The Collector did not start"
docker logs otelcol
exit 1
