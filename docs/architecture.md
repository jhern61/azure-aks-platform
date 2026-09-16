# Architecture

## Goals

1. Stand up a realistic AKS platform from zero with a single `make apply`.
2. Make the platform observable and operable, not just runnable.
3. Enforce security and correctness in CI so the `main` branch is always deployable.
4. Keep the whole thing cheap to run and trivial to destroy.

## Component map

| Component | Purpose | Terraform |
|-----------|---------|-----------|
| Resource group | Blast-radius boundary for the whole platform | `main.tf` |
| VNet + node subnet | Private network for cluster nodes | `modules/network` |
| NSG | Default-deny inbound from the internet | `modules/network` |
| AKS cluster | Managed Kubernetes control plane + system pool | `modules/aks` |
| User node pool | Autoscaling capacity for workloads | `modules/aks` |
| Log Analytics | Container logs + KQL queries | `modules/monitoring` |
| Azure Monitor workspace | Backing store for managed Prometheus | `modules/monitoring` |
| Managed Grafana | Dashboards over Prometheus metrics | `modules/monitoring` |
| Data collection rule | Routes Prometheus metrics from AKS to the workspace | `modules/aks` |

## Key decisions

### Modular Terraform
Network, cluster, and monitoring are separate child modules with narrow inputs
and outputs. This keeps each unit small enough to review in a single PR and lets
the monitoring plane be reused by other clusters without copy-paste.

### Identity and access
- **Local accounts disabled.** Cluster auth is Entra ID only.
- **Azure RBAC for Kubernetes.** Kubernetes authorization is delegated to Azure
  role assignments, so access is managed the same way as the rest of the cloud
  estate rather than in-cluster `RoleBinding` sprawl.
- **Workload Identity + OIDC issuer enabled**, so in-cluster workloads federate
  to Entra ID without long-lived secrets.

### Networking
Azure CNI Overlay with Cilium network policy. Overlay keeps pod IP consumption
off the VNet address space (a common scaling wall with classic Azure CNI), and
Cilium gives enforceable network policy. Egress is through a managed NAT gateway
for a stable, non-SNAT-exhausting outbound path.

### Metrics plane
Azure Monitor managed Prometheus rather than self-hosted Prometheus. Rationale:
running Prometheus HA, long-term storage, and upgrades is real toil with no
differentiation for a platform this size. The SLO logic stays as portable
PromQL (`kubernetes/slo`), so the objectives are not locked to the managed
service and could move to self-hosted Prometheus with only a scrape-config change.

### CI as the quality gate
`terraform fmt`, `validate`, `tflint`, and `checkov` run on every PR that touches
`terraform/`. `checkov` failing the build is deliberate: it is cheaper to fix a
public API server or an unencrypted disk in review than after it is live.

## What is intentionally out of scope
- Multi-environment promotion (dev/stage/prod) — the layout supports it via
  separate `*.tfvars` and backend keys, but only `demo` is wired here.
- Ingress controller and TLS — the sample workload exposes metrics only.
- Secrets management (Key Vault CSI) — noted as the natural next module.

These are called out rather than hidden so the reader knows the boundary between
"built" and "would build next."
