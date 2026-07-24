#!/usr/bin/env bash
# bootstrap.sh — run ONCE per subscription, before any Terraform.
#
# Creates the management resource group + storage account that hold Terraform
# state. This lives OUTSIDE every Terraform stack on purpose: the state backend
# cannot be managed by the same Terraform that consumes it (chicken-and-egg),
# and `terraform destroy` on a platform stack must never be able to eat the
# state. See ADR-0005 (state layout) and infra/README.md.
#
# Auth model: Entra ID only. No storage-account keys are ever created or used —
# humans and CI authenticate with AAD and the azurerm backend sets
# use_azuread_auth=true. Blob versioning + soft delete give a state time machine.
set -euo pipefail

LOCATION="${LOCATION:-westeurope}"
MGMT_RG="${MGMT_RG:-rg-lkh-mgmt}"
STATE_SA="${STATE_SA:?set STATE_SA to a globally-unique name, e.g. stlkhtfstate<suffix>}"
STATE_CONTAINER="${STATE_CONTAINER:-tfstate}"

echo "==> Resource group: ${MGMT_RG} (${LOCATION})"
az group create --name "${MGMT_RG}" --location "${LOCATION}" -o none

echo "==> Storage account: ${STATE_SA} (LRS, Entra-only, no shared keys)"
az storage account create \
  --name "${STATE_SA}" \
  --resource-group "${MGMT_RG}" \
  --location "${LOCATION}" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --allow-shared-key-access false \
  -o none

echo "==> Blob versioning + soft delete (state time machine)"
az storage account blob-service-properties update \
  --account-name "${STATE_SA}" \
  --resource-group "${MGMT_RG}" \
  --enable-versioning true \
  --enable-delete-retention true \
  --delete-retention-days 30 \
  -o none

echo "==> Container: ${STATE_CONTAINER} (AAD auth, no anonymous access)"
az storage container create \
  --name "${STATE_CONTAINER}" \
  --account-name "${STATE_SA}" \
  --auth-mode login \
  -o none

echo "==> Granting 'Storage Blob Data Contributor' on the state SA to the current user"
SA_ID=$(az storage account show -n "${STATE_SA}" -g "${MGMT_RG}" --query id -o tsv)
CALLER=$(az ad signed-in-user show --query id -o tsv)
az role assignment create \
  --assignee-object-id "${CALLER}" \
  --assignee-principal-type User \
  --role "Storage Blob Data Contributor" \
  --scope "${SA_ID}" \
  -o none

cat <<EOF

Done. Put these into each stack's *.tfbackend file:

  resource_group_name  = "${MGMT_RG}"
  storage_account_name = "${STATE_SA}"
  container_name       = "${STATE_CONTAINER}"
  # key differs per stack, e.g. account.tfstate, platform-alp-dev.tfstate
EOF
