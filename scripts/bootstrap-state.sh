#!/usr/bin/env bash
# Creates the Azure resources that hold Terraform remote state:
# a resource group, a storage account, and a blob container.
# Writes terraform/backend.hcl for `terraform init -backend-config=backend.hcl`.
#
# Idempotent: safe to re-run. Requires an authenticated `az` CLI.
set -euo pipefail

LOCATION="${LOCATION:-centralus}"
PREFIX="${PREFIX:-akssre}"
RG="rg-${PREFIX}-tfstate"
CONTAINER="tfstate"
# Storage account names are global and must be <=24 chars, lowercase alnum.
SA="st${PREFIX}tfstate$(echo "$RANDOM" | md5sum | cut -c1-6)"

echo ">> Resource group: ${RG}"
az group create --name "$RG" --location "$LOCATION" --output none

echo ">> Storage account: ${SA}"
az storage account create \
  --name "$SA" \
  --resource-group "$RG" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --encryption-services blob \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --output none

echo ">> Blob container: ${CONTAINER}"
az storage container create \
  --name "$CONTAINER" \
  --account-name "$SA" \
  --auth-mode login \
  --output none

cat > terraform/backend.hcl <<EOF
resource_group_name  = "${RG}"
storage_account_name = "${SA}"
container_name       = "${CONTAINER}"
key                  = "${PREFIX}.demo.tfstate"
use_azuread_auth     = true
EOF

echo ">> Wrote terraform/backend.hcl"
echo ">> Next: make init && make plan"
