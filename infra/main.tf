data "azurerm_client_config" "current" {}

locals {
  cluster_name = "aks-${var.name_prefix}"
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${var.name_prefix}"
  location = var.location
  tags     = var.tags
}

# ---------------------------------------------------------------------------
# Network: one VNet, one subnet for nodes. With Azure CNI overlay, pods get
# IPs from pod_cidr instead of the subnet, so the subnet can stay small.
# ---------------------------------------------------------------------------

resource "azurerm_virtual_network" "this" {
  name                = "vnet-${var.name_prefix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.vnet_address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "aks" {
  name                 = "snet-aks-nodes"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.aks_subnet_prefix]
}

# ---------------------------------------------------------------------------
# Cluster identity. A user-assigned identity survives cluster rebuilds and can
# be granted rights before the cluster exists, which avoids the race where AKS
# starts before its role assignment on the subnet has propagated.
# ---------------------------------------------------------------------------

resource "azurerm_user_assigned_identity" "cluster" {
  name                = "id-${var.name_prefix}-cluster"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_role_assignment" "cluster_network" {
  scope                            = azurerm_subnet.aks.id
  role_definition_name             = "Network Contributor"
  principal_id                     = azurerm_user_assigned_identity.cluster.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}
