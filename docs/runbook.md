# Runbook: web service on AKS

Audience: on-call engineer responding to an alert from this platform. Assumes
`kubectl` context is set (`make kubeconfig`) and access to Grafana.

## First 5 minutes (any alert)

1. Open the **web - Golden Signals** dashboard in Grafana.
2. Read the four signals in order: latency, traffic, errors, saturation.
3. Note whether the change is **gradual** (capacity/dependency) or **step**
   (deploy/config). Correlate the start time with recent deploys:
   ```bash
   kubectl -n demo rollout history deployment/web
   ```
4. Post an initial status: what is affected, since when, and that you are engaged.

## Alert: availability burn

Trigger: `WebAvailabilityBudgetBurnFast` (page) or `...Slow` (ticket).

Likely causes, cheapest to check first:

1. **Bad deploy.** If errors started at a rollout, roll back:
   ```bash
   kubectl -n demo rollout undo deployment/web
   kubectl -n demo rollout status deployment/web
   ```
2. **Crash-looping pods.**
   ```bash
   kubectl -n demo get pods -l app=web
   kubectl -n demo logs -l app=web --tail=100 --prefix
   kubectl -n demo describe pod -l app=web | sed -n '/Events/,$p'
   ```
3. **Dependency failure.** Check downstream error codes and the dependency's own
   dashboards. If the failure is external, communicate impact and consider
   shedding load or enabling a degraded mode rather than firefighting theirs.

Exit criteria: error ratio back under budget on the 5m and 1h windows, rollout
healthy, status updated to resolved.

## Alert: latency burn

Trigger: `WebLatencyObjectiveAtRisk`.

1. **Saturation?** Check CPU/memory vs requests on the dashboard. If pods are
   pinned, confirm the HPA is scaling:
   ```bash
   kubectl -n demo get hpa web
   kubectl -n demo describe hpa web
   ```
   If the HPA is at `maxReplicas`, raise the ceiling or the node pool max.
2. **Node pressure?** If pods are Pending, the cluster autoscaler may be adding
   nodes:
   ```bash
   kubectl get nodes
   kubectl -n kube-system logs -l app=cluster-autoscaler --tail=50
   ```
3. **Slow dependency?** Latency that tracks a downstream call points there, not
   at this service.

## Node pool maintenance (drain and roll)

To safely cycle a node (patch, hardware, taints):

```bash
kubectl cordon <node>
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data --grace-period=60
# perform maintenance / let AKS replace it
kubectl uncordon <node>
```

AKS node image upgrades handle surge automatically (`max_surge = 33%`), so
prefer `az aks nodepool upgrade` over manual draining for routine patching.

## Rolling back infrastructure

Terraform changes are gated by CI plan on PR. If an applied change caused an
incident, revert the PR and re-run apply from `main`; never hand-edit resources
in the portal, or the next `terraform apply` will fight the drift.

## Escalation

If not making progress within the burn-rate budget (fast burn = act within
hours, not days), escalate to the platform owner and, for customer-facing
impact, open a formal incident and start a timeline for the postmortem.
