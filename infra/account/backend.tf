# Keyless (AAD) azurerm state backend. Container comes from bootstrap.sh; the
# state KEY is supplied per-stack via -backend-config, because backend blocks
# cannot interpolate variables. Initialise this stack with:
#
#   terraform init -backend-config=account.tfbackend
#
terraform {
  backend "azurerm" {
    use_azuread_auth = true
  }
}
