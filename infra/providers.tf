# The subscription is read from ARM_SUBSCRIPTION_ID so that nothing
# environment specific is committed. See the README quick start.
provider "azurerm" {
  features {
    resource_group {
      # Refuse to delete a resource group that still holds resources this
      # configuration does not know about (for example AKS-created extras).
      prevent_deletion_if_contains_resources = true
    }
  }
}
