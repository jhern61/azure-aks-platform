# Contributing

Thank you for contributing to **azure-aks-platform**! This guide explains how to set up your local environment and make changes safely.

---

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Terraform | ≥ 1.9 | [terraform.io](https://developer.hashicorp.com/terraform/install) |
| Azure CLI | ≥ 2.60 | [docs.microsoft.com](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) |
| kubectl | ≥ 1.29 | [kubernetes.io](https://kubernetes.io/docs/tasks/tools/) |
| tflint | v0.53.0 | `brew install tflint` |
| kubeconform | v0.6.7 | `brew install kubeconform` |
| GitHub CLI | ≥ 2.40 | `brew install gh` |

---

## First-Time Setup

### 1. Configure OIDC Federation (Azure → GitHub Actions)

The CI pipeline uses OIDC — no secrets are stored in the repo. Run this once per environment:

```bash
# Set your values
SUBSCRIPTION_ID="<your-subscription-id>"
TENANT_ID="<your-tenant-id>"
GITHUB_ORG="jhern61"
GITHUB_REPO="azure-aks-platform"
APP_NAME="sp-aks-platform-cicd"

# Create an app registration
az ad app create --display-name "$APP_NAME"
APP_ID=$(az ad app list --display-name "$APP_NAME" --query '[0].appId' -o tsv)

# Create the service principal
az ad sp create --id "$APP_ID"
SP_OBJECT_ID=$(az ad sp show --id "$APP_ID" --query id -o tsv)

# Add a federated credential for the 'demo' GitHub Environment (used by plan/apply)
az ad app federated-credential create \
  --id "$APP_ID" \
  --parameters "{
    \"name\": \"github-aks-platform-demo\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:${GITHUB_ORG}/${GITHUB_REPO}:environment:demo\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }"

# Add a federated credential for PRs (used by the validate job)
az ad app federated-credential create \
  --id "$APP_ID" \
  --parameters "{
    \"name\": \"github-aks-platform-pr\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:${GITHUB_ORG}/${GITHUB_REPO}:pull_request\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }"

# Grant Contributor on the subscription
az role assignment create \
  --assignee "$SP_OBJECT_ID" \
  --role Contributor \
  --scope "/subscriptions/${SUBSCRIPTION_ID}"
```

Then add the following secrets to your GitHub repo (`Settings → Secrets → Actions`):

| Secret | Value |
|--------|-------|
| `AZURE_CLIENT_ID` | `$APP_ID` |
| `AZURE_TENANT_ID` | `$TENANT_ID` |
| `AZURE_SUBSCRIPTION_ID` | `$SUBSCRIPTION_ID` |

### 2. Bootstrap Terraform Remote State

```bash
# Creates the storage account and container for Terraform state
bash scripts/bootstrap-state.sh
```

This produces a `backend.hcl` file. Copy the example and fill in the values:

```bash
cp terraform/backend.hcl.example terraform/backend.hcl
# Edit backend.hcl with your storage account name, container, and key
```

### 3. Configure Terraform Variables

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform.tfvars with your environment-specific values
```

Key variables to set:

| Variable | Description | Default |
|----------|-------------|---------|
| `prefix` | Short prefix for resource names (3-8 lowercase chars) | `akssre` |
| `environment` | Environment label (e.g. `dev`, `staging`, `prod`) | `demo` |
| `location` | Azure region | `centralus` |
| `admin_group_object_ids` | Entra ID group IDs for cluster-admin RBAC | `[]` |
| `system_node_min` | Min nodes in the system pool (≥ 2 recommended) | `2` |
| `system_node_max` | Max nodes in the system pool | `3` |
| `user_node_min` | Min nodes in the user pool | `1` |
| `user_node_max` | Max nodes in the user pool | `4` |

---

## Local Development Workflow

### Terraform

```bash
cd terraform

# Initialise (with remote state)
terraform init -backend-config=backend.hcl

# Format check
terraform fmt -check -recursive

# Validate
terraform validate

# Run linter
tflint --init && tflint --recursive

# Plan
terraform plan -var-file=terraform.tfvars

# Apply
terraform apply -var-file=terraform.tfvars
```

### Kubernetes

```bash
# Validate manifests locally
kubeconform -strict -ignore-missing-schemas kubernetes/

# Apply to cluster (requires kubectl context)
kubectl apply -f kubernetes/workload/app.yaml
```

---

## Pull Request Checklist

Before opening a PR, confirm:

- [ ] `terraform fmt -check -recursive` passes
- [ ] `terraform validate` passes
- [ ] `tflint --recursive` passes
- [ ] `kubeconform -strict kubernetes/` passes (for k8s changes)
- [ ] No secrets or sensitive values committed
- [ ] `terraform.tfvars` and `backend.hcl` are **not** committed (they're in `.gitignore`)

The CI pipeline will automatically:
1. Run `fmt` / `validate` / `tflint` / `checkov` on every PR touching `terraform/`
2. Post a `terraform plan` comment on the PR
3. Run `kubeconform` + YAML lint on every PR touching `kubernetes/`
4. Run `terraform apply` automatically on merge to `main`

---

## Branch Protection

The `main` branch requires:
- At least one approval (enforced by CODEOWNERS)
- All status checks to pass (`validate`, `plan`, `k8s-lint`)
- No direct pushes

> **Note**: Branch protection rules must be configured manually in **Settings → Branches → Branch protection rules**.
