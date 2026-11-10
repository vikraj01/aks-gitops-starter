# Remote state example. Left commented so that `terraform init -backend=false`
# and local experiments work out of the box. For anything shared, create a
# storage account with versioning and soft delete, then uncomment and run
# `terraform init -migrate-state`.
#
# terraform {
#   backend "azurerm" {
#     resource_group_name  = "rg-tfstate"
#     storage_account_name = "sttfstate<unique>"
#     container_name       = "tfstate"
#     key                  = "aks-gitops-starter/infra.tfstate"
#     use_azuread_auth     = true
#   }
# }
