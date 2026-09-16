# Azure AKS Platform

A production-shaped, reproducible Azure Kubernetes Service platform provisioned entirely with Terraform, wired for observability, service-level objectives, and GitOps-friendly CI. Built as a reference for how I approach reliability engineering on Azure: infrastructure as code, security scanning in the pipeline, golden-signal monitoring, and runbooks that make the system operable by someone who has never seen it before.

> This repository is a portfolio reference platform. It is deliberately self-contained and destroyable, so the whole thing can be stood up, demonstrated, and torn down for the price of a few hours of AKS.

## Why this exists

Most "Terraform + AKS" examples stop at `terraform apply`. Running a cluster is the easy 20%. This project models the other 80% that an SRE actually owns:

- **Repeatable provisioning** with a modular Terraform layout and a remote-state backend.
- **Policy and security enforced in CI**, not by convention: `fmt`, `validate`, `tflint`, and `checkov` gate every pull request, and `terraform plan` is posted back to the PR.
- **Observability from day zero**: managed Prometheus scraping, Grafana dashboards, and container insights, rather than bolting monitoring on after an incident.
- **SLOs as code**: latency and availability objectives expressed as Prometheus recording and alerting rules with multi-window burn-rate alerts.
- **Operability**: an architecture doc, an SLO doc, and an incident runbook that a rotating on-call can follow at 3am.

## Architecture

```
                          ┌─────────────────────────────────────────────┐
                          │                Azure Subscription            │
                          │                                              │
  Developer ──PR──▶ GitHub Actions                                       │
     │              (fmt/validate/tflint/checkov/plan)                   │
     │                    │ apply (main)                                 │
     │                    ▼                                              │
     │            ┌───────────────┐    ┌──────────────────────────────┐  │
     │            │  VNet /Subnets│    │  Log Analytics + Managed     │  │
     │            │  NSGs         │    │  Prometheus (Azure Monitor)  │  │
     │            └───────┬───────┘    └───────────────┬──────────────┘  │
     │                    │                            │ metrics/logs    │
     │                    ▼                            │                 │
     │            ┌────────────────────────────────────┴─────────────┐  │
     │            │                   AKS Cluster                     │  │
     │            │  - system + user node pools (autoscaling)         │  │
     │            │  - Workload Identity + Azure RBAC                 │  │
     │            │  ┌───────────┐  ┌───────────┐  ┌───────────────┐  │  │
     │            │  │  workload │  │ Prometheus│  │    Grafana    │  │  │
     │            │  │  + HPA    │  │  rules/SLO│  │  dashboards   │  │  │
     │            │  └───────────┘  └───────────┘  └───────────────┘  │  │
     └───browse───────────────────────────────────────────────────────▶ │
                          └─────────────────────────────────────────────┘
```

See [`docs/architecture.md`](docs/architecture.md) for the full component breakdown and the decisions behind it.

## What gets provisioned

| Layer | Resources |
|-------|-----------|
| Network | VNet, system/workload subnets, NSGs, egress via managed NAT |
| Cluster | AKS with a system node pool and an autoscaling user node pool, Workload Identity, OIDC issuer, Azure RBAC for Kubernetes auth |
| Observability | Log Analytics workspace, Azure Monitor managed Prometheus, container insights, Grafana |
| Platform add-ons | Sample workload with a HorizontalPodAutoscaler, SLO recording/alerting rules |

## Repository layout

```
.
├── terraform/              # Root module + reusable child modules
│   ├── modules/network/    # VNet, subnets, NSGs
│   ├── modules/aks/        # Cluster, node pools, identity
│   └── modules/monitoring/ # Log Analytics, managed Prometheus, Grafana
├── kubernetes/
│   ├── workload/           # Sample service, Deployment, Service, HPA
│   ├── observability/      # Grafana dashboard + datasource config
│   └── slo/                # PrometheusRule: SLIs, SLOs, burn-rate alerts
├── .github/workflows/      # Terraform CI (validate/lint/security/plan)
├── docs/                   # architecture, SLO, runbook
├── scripts/                # helper scripts (state bootstrap, kubeconfig)
└── Makefile                # single entrypoint for every workflow
```

## Quickstart

Prerequisites: an Azure subscription, `az` CLI (logged in), Terraform >= 1.6, and `kubectl`.

```bash
# 1. One-time: create the remote state backend (resource group + storage account)
make bootstrap

# 2. Review and apply the infrastructure
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
make plan
make apply

# 3. Pull cluster credentials
make kubeconfig

# 4. Deploy the sample workload, observability config, and SLO rules
make deploy

# 5. Tear everything down when you are done
make destroy
```

Every target is thin and inspectable; run `make help` to see them all.

## Reliability model

The platform ships with explicit objectives rather than implicit hope:

| SLI | SLO | Window | Alert |
|-----|-----|--------|-------|
| Request availability | 99.9% success | 30d rolling | Multi-window burn-rate (fast + slow) |
| Request latency | 95% < 300ms | 30d rolling | Burn-rate on the latency SLI |

Objectives, error budgets, and the reasoning behind the burn-rate thresholds live in [`docs/slo.md`](docs/slo.md). The alert rules that implement them are in [`kubernetes/slo/slo-rules.yaml`](kubernetes/slo/slo-rules.yaml).

## Operating it

[`docs/runbook.md`](docs/runbook.md) covers the on-call basics: how to read the golden signals, what each alert means, first-response steps for a latency or availability burn, how to drain and roll a node pool, and how to safely roll back a bad deploy.

## Design decisions worth calling out

- **Modular, not monolithic.** Network, cluster, and monitoring are separate modules so they can be reviewed, versioned, and reused independently.
- **Security shifts left.** `checkov` runs in CI against the Terraform, so misconfigurations (public API server, unencrypted disks, missing network policy) are caught before merge, not in an audit.
- **Managed over self-hosted for the metrics plane.** Azure Monitor managed Prometheus removes the toil of running Prometheus HA myself; the SLO logic still lives as portable PromQL, so it is not locked in.
- **Autoscaling everywhere.** Cluster autoscaler on the user node pool and an HPA on the workload, so the platform demonstrates elasticity rather than a fixed-size cluster.

## Cost note

This provisions real, billable Azure resources (AKS, Log Analytics, Grafana). Run `make destroy` when finished. The default sizing targets "cheap enough to demo," not production capacity.

## License

MIT. See [LICENSE](LICENSE).
