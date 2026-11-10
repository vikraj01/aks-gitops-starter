# Remote state example, same pattern as the infra root but a separate key so
# the two roots can be planned and destroyed independently.
#
# terraform {
#   backend "azurerm" {
#     resource_group_name  = "rg-tfstate"
#     storage_account_name = "sttfstate<unique>"
#     container_name       = "tfstate"
#     key                  = "aks-gitops-starter/bootstrap.tfstate"
#     use_azuread_auth     = true
#   }
# }
