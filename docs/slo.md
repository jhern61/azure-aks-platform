# Service-Level Objectives

This platform treats reliability as a measurable target with an error budget,
not an aspiration. The objectives below apply to the `web` sample service and
are implemented as Prometheus rules in `kubernetes/slo/slo-rules.yaml`.

## Objectives

| SLI | Definition | SLO | Window |
|-----|-----------|-----|--------|
| Availability | Share of HTTP requests that do not return 5xx | 99.9% | 30 days rolling |
| Latency | Share of HTTP requests served in under 300ms | 95% | 30 days rolling |

## Error budget

A 99.9% availability target over 30 days permits **0.1%** of requests to fail.
For a service handling ~1,000,000 requests / 30d, that is roughly **1,000 failed
requests** of budget. The budget is what makes reliability a shared,
quantitative conversation with product: as long as budget remains, ship; when it
is exhausted, reliability work takes priority.

## Why multi-window burn-rate alerts

Alerting directly on "error ratio > 0.1%" is either too noisy (fires on brief
blips) or too slow (waits until the budget is already gone). Instead we alert on
**burn rate** — how fast the budget is being consumed — across two windows, from
the Google SRE workbook:

| Alert | Condition | Meaning | Action |
|-------|-----------|---------|--------|
| Fast burn | 14.4x budget over 5m **and** 1h | Budget gone in ~2 days at this rate | **Page** |
| Slow burn | 6x budget over 6h **and** 1h | Sustained degradation | **Ticket** |

Requiring the short **and** long window together suppresses false positives: a
30-second spike trips the short window but not the long one, so no page fires.

## Latency objective

The latency SLI uses the `le="0.3"` histogram bucket, so it measures the
fraction of requests faster than the 300ms objective directly from the
`http_request_duration_seconds` histogram. `WebLatencyObjectiveAtRisk` opens a
ticket when more than 5% of requests breach 300ms over 5 minutes.

## Reviewing and revising

SLOs are not set once. Review them quarterly against actual traffic: if the
service comfortably beats 99.9% for two quarters, tighten it; if the budget is
routinely exhausted by dependencies outside the team's control, the target or
the architecture needs to change, not the on-call's sleep schedule.
