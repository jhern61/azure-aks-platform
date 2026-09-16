# Observability

Metrics land in Azure Monitor managed Prometheus (provisioned by Terraform in
`terraform/modules/monitoring`) and are visualized in Azure Managed Grafana.

## Dashboards

`golden-signals-dashboard.json` is an importable Grafana dashboard covering the
four golden signals for the `web` service:

- **Latency** — request duration p50/p95/p99
- **Traffic** — requests per second by response code
- **Errors** — 5xx error ratio against the 0.1% budget line
- **Saturation** — pod CPU/memory against requests, HPA replica count

Import it in Grafana via *Dashboards → New → Import*, then select the Azure
Monitor workspace Prometheus data source.

## Scraping

The sample workload is annotated with `prometheus.io/scrape: "true"`. The AKS
managed Prometheus addon is configured via the data collection rule in the AKS
module. To scrape custom targets, add a `ama-metrics-prometheus-config`
ConfigMap in the `kube-system` namespace; see the Azure Monitor docs for the
scrape config schema.
