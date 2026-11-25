#!/usr/bin/env bash
# Waits until the local Collector has exported to Dash0 everything it accepted.
# Usage: drain.sh [minimum accepted metric points]
set -euo pipefail

min_points=${1:-0}
exporter='exporter="otlp_http/dash0"'

sum() { awk -v re="$1" '$0 ~ re { s += $NF } END { print s + 0 }' <<<"$metrics"; }

for _ in $(seq 1 120); do
  metrics=$(curl -fsS http://localhost:8888/metrics)
  accepted_spans=$(sum '^otelcol_receiver_accepted_spans[{]')
  accepted_points=$(sum '^otelcol_receiver_accepted_metric_points[{]')
  sent_spans=$(sum "^otelcol_exporter_sent_spans[{].*$exporter")
  sent_points=$(sum "^otelcol_exporter_sent_metric_points[{].*$exporter")
  failed=$(sum "^otelcol_exporter_send_failed_(spans|metric_points)[{].*$exporter")

  if ((failed > 0)); then
    echo "::error::The Collector failed to export $failed items to Dash0"
    exit 1
  fi
  if ((accepted_points >= min_points && sent_spans == accepted_spans && sent_points == accepted_points)); then
    errored=$(sum '^otelcol_scraper_errored_metric_points[{]')
    ((errored == 0)) || echo "::warning::Scrapers reported $errored errored metric points"
    echo "Exported $sent_spans spans and $sent_points metric points to Dash0"
    exit 0
  fi
  sleep 1
done

echo "::error::Timed out: accepted $accepted_spans spans and $accepted_points metric points, exported $sent_spans and $sent_points"
exit 1
