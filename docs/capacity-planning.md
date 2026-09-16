# Capacity Planning

This document covers how to size this platform correctly, how to detect when it
is running out of headroom, and how to act before saturation becomes an incident.

---

## Current Sizing (Demo Environment)

| Pool | VM SKU | Min nodes | Max nodes | vCPU / node | RAM / node |
|------|--------|-----------|-----------|-------------|------------|
| System | Standard_D2s_v5 | 2 | 3 | 2 | 8 GiB |
| User | Standard_D2s_v5 | 1 | 4 | 2 | 8 GiB |

The sample workload requests `50m` CPU and `64Mi` memory per pod, with limits of
`250m` CPU and `128Mi`. With HPA `minReplicas: 2` and `maxReplicas: 10`, the
maximum aggregate resource demand from the `web` deployment alone is:

| Resource | Per pod (limit) | Max (10 pods) | User pool capacity (4 nodes) |
|----------|-----------------|---------------|------------------------------|
| CPU | 250m | 2,500m (2.5 cores) | ~7,200m allocatable |
| Memory | 128Mi | 1,280Mi (~1.3 GiB) | ~26 GiB allocatable |

> **The demo sizing is intentionally cheap** — designed to run for a few hours
> at minimal cost. Refer to the [Production Sizing](#production-sizing) section
> before deploying real traffic.

---

## Allocatable Resources vs. Capacity

AKS reserves a portion of each node for system overhead. For `Standard_D2s_v5`
(2 vCPU, 8 GiB):

| Resource | Total | AKS/OS reserve | **Allocatable** |
|----------|-------|----------------|-----------------|
| CPU | 2,000m | ~100m | **~1,900m** |
| Memory | 8,192 MiB | ~1,100 MiB | **~7,090 MiB** |

A 4-node user pool therefore provides roughly:
- **~7,600m allocatable CPU** (4 × 1,900m)
- **~27.7 GiB allocatable memory** (4 × 7,090 MiB)

These numbers decrease if DaemonSets (log collectors, security agents) are
scheduled on user nodes. Account for ~150m CPU and ~200Mi memory per DaemonSet
pod per node.

---

## HPA and Cluster Autoscaler Interaction

The HPA scales **pods** horizontally in response to CPU utilisation. The Cluster
Autoscaler scales **nodes** when pods are Pending due to insufficient capacity.
The two work in sequence:

```
Traffic spike
  → HPA adds pods
    → Pods Pending (no room on existing nodes)
      → Cluster Autoscaler provisions a new node (~2–4 min)
        → Pods scheduled and start serving
```

**Implication for sizing:** There is a 2–4 minute gap between a traffic spike
and new nodes being ready. Pre-scale headroom — keeping at least one node
partially free — reduces this gap. For latency-sensitive services, consider
setting `user_node_min` high enough to absorb a 2× spike without waiting for
a new node.

---

## Saturation Signals to Watch

Use the **web - Golden Signals** Grafana dashboard. Saturation is the signal
most closely tied to capacity:

| Signal | Query | Action threshold |
|--------|-------|-----------------|
| Pod CPU utilisation | `rate(container_cpu_usage_seconds_total[5m]) / container_spec_cpu_quota * 100` | > 80% sustained → scale up |
| Pod memory utilisation | `container_memory_working_set_bytes / container_spec_memory_limit_bytes * 100` | > 80% sustained → scale up |
| HPA replicas at max | `kube_horizontalpodautoscaler_status_current_replicas == kube_horizontalpodautoscaler_spec_max_replicas` | Immediate — raise `maxReplicas` or `user_node_max` |
| Node CPU pressure | `1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) by (node)` | > 75% across all nodes → add nodes |
| Pending pods | `kube_pod_status_phase{phase="Pending"}` | > 0 for > 3 min → cluster autoscaler may be stuck |
| Node count at max | `kube_node_status_condition{condition="Ready",status="true"} == <user_node_max>` | Review `user_node_max` in `terraform.tfvars` |

---

## Scaling Levers

All sizing is controlled in [`terraform/terraform.tfvars`](../terraform/terraform.tfvars).
Apply changes via the standard PR → plan → apply workflow.

### Vertical: change VM SKU

Upgrade the node VM size to get more vCPU/RAM per node without adding more nodes.
Recommended progression for the user pool:

| SKU | vCPU | RAM | Suitable for |
|-----|------|-----|--------------|
| Standard_D2s_v5 | 2 | 8 GiB | Demo / dev |
| Standard_D4s_v5 | 4 | 16 GiB | Light production |
| Standard_D8s_v5 | 8 | 32 GiB | Medium production |
| Standard_D16s_v5 | 16 | 64 GiB | High-throughput services |

> **Note:** Changing `user_node_size` forces a node pool replacement. The
> Cluster Autoscaler will drain and recreate all user nodes — ensure your PDB
> (`minAvailable: 1`) and HPA are configured correctly before doing this.

### Horizontal: increase node pool bounds

Raise `user_node_max` to allow the Cluster Autoscaler to provision more nodes
during peak traffic:

```hcl
# terraform/terraform.tfvars
user_node_min = 2   # keep one spare node warm at baseline
user_node_max = 8   # allow up to 8 nodes under load
```

### Horizontal: increase HPA replica ceiling

Raise `maxReplicas` in [`kubernetes/workload/app.yaml`](../kubernetes/workload/app.yaml)
if pods are regularly hitting the ceiling before nodes fill up:

```yaml
spec:
  minReplicas: 2
  maxReplicas: 20   # was 10
```

---

## Production Sizing

For a real service (not the demo), start from these baselines and load-test to
validate:

| Deployment tier | User pool SKU | Min nodes | Max nodes | HPA maxReplicas |
|-----------------|---------------|-----------|-----------|-----------------|
| Low traffic (< 100 rps) | Standard_D4s_v5 | 2 | 5 | 20 |
| Medium traffic (100–1 000 rps) | Standard_D8s_v5 | 3 | 10 | 50 |
| High traffic (> 1 000 rps) | Standard_D16s_v5 | 4 | 20 | 100 |

**Rules of thumb:**
- Target **≤ 70% CPU utilisation** at baseline (matches the HPA `averageUtilization: 70` already set).
- Keep **≥ 20% headroom** on node count at p99 traffic — i.e., don't run at `user_node_max` during normal hours.
- Set `user_node_min` high enough that HPA can absorb a **2× traffic spike** without waiting for new nodes.
- Memory limits should be at least **2× requests** to absorb bursty JVM / Go runtime behaviour.

---

## Quarterly Capacity Review

Run this review against the previous 90 days of Grafana data:

1. **Peak utilisation**: What was the highest sustained CPU and memory
   utilisation across user nodes? If it never exceeded 50%, the pool may be
   over-provisioned. If it regularly hit 80%+, it is under-provisioned.

2. **HPA saturation events**: How many times did the HPA sit at `maxReplicas`?
   Each event is a latency or availability risk. Raise the ceiling or the node
   pool max.

3. **Cluster Autoscaler activity**: How long did pod-pending events last?
   Consistently > 3 minutes suggests the scale-out baseline (`user_node_min`)
   is too low.

4. **Cost vs. utilisation**: Use Azure Cost Management to correlate spend spikes
   with actual traffic. If nodes scale up for short bursts and sit idle the rest
   of the day, consider [KEDA](https://keda.sh/) for event-driven autoscaling
   to drain idle capacity faster.

5. **Kubernetes version skew**: Check that `kubernetes_version` in
   `terraform.tfvars` is still within the AKS support window (N-2 minor
   versions). Plan upgrades before the version reaches end-of-life.
