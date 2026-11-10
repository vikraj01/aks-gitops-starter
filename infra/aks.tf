resource "azurerm_kubernetes_cluster" "this" {
  name                = local.cluster_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  node_resource_group = "rg-${var.name_prefix}-nodes"
  dns_prefix          = var.name_prefix
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier

  # Upgrades happen inside the maintenance windows below.
  automatic_upgrade_channel = var.automatic_upgrade_channel
  node_os_upgrade_channel   = var.node_os_upgrade_channel

  # Identity and access: Entra ID for authentication, Azure RBAC for
  # authorisation, no static admin kubeconfig.
  local_account_disabled            = true
  role_based_access_control_enabled = true

  azure_active_directory_role_based_access_control {
    tenant_id          = data.azurerm_client_config.current.tenant_id
    azure_rbac_enabled = true
  }

  # Workload identity: pods exchange a projected service account token for an
  # Entra ID token. No secrets in the cluster for Azure access.
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # Remove unused images from nodes on a schedule.
  image_cleaner_enabled        = true
  image_cleaner_interval_hours = 48

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.cluster.id]
  }

  api_server_access_profile {
    authorized_ip_ranges = var.api_server_authorized_ip_ranges
  }

  default_node_pool {
    name                         = "system"
    vm_size                      = var.system_node_pool.vm_size
    vnet_subnet_id               = azurerm_subnet.aks.id
    zones                        = var.availability_zones
    auto_scaling_enabled         = true
    min_count                    = var.system_node_pool.min_count
    max_count                    = var.system_node_pool.max_count
    max_pods                     = var.system_node_pool.max_pods
    os_disk_type                 = var.system_node_pool.os_disk_type
    os_disk_size_gb              = var.system_node_pool.os_disk_size_gb
    temporary_name_for_rotation  = "systemtmp"
    only_critical_addons_enabled = false # platform add-ons (Argo CD, Kyverno) run here too
    node_labels = {
      "pool" = "system"
    }
    tags = var.tags

    upgrade_settings {
      max_surge                     = "33%"
      drain_timeout_in_minutes      = 30
      node_soak_duration_in_minutes = 0
    }
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    pod_cidr            = var.pod_cidr
    service_cidr        = var.service_cidr
    dns_service_ip      = var.dns_service_ip
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"
  }

  # Container Insights through managed identity. The data collection rule
  # and its association live in monitoring.tf.
  oms_agent {
    log_analytics_workspace_id      = azurerm_log_analytics_workspace.this.id
    msi_auth_for_monitoring_enabled = true
  }

  maintenance_window_auto_upgrade {
    frequency   = "Weekly"
    interval    = 1
    day_of_week = var.maintenance_window.day_of_week
    start_time  = var.maintenance_window.start_time
    duration    = var.maintenance_window.duration_hours
    utc_offset  = var.maintenance_window.utc_offset
  }

  maintenance_window_node_os {
    frequency   = "Weekly"
    interval    = 1
    day_of_week = var.maintenance_window.day_of_week
    start_time  = var.maintenance_window.start_time
    duration    = var.maintenance_window.duration_hours
    utc_offset  = var.maintenance_window.utc_offset
  }

  tags = var.tags

  lifecycle {
    # The cluster autoscaler owns the node count.
    ignore_changes = [default_node_pool[0].node_count]
  }

  depends_on = [azurerm_role_assignment.cluster_network]
}

# Dedicated pool for application workloads. The taint keeps everything off it
# unless a pod tolerates the taint; the label lets pods ask for it. Kyverno
# adds both to pods in namespaces labelled workload-tier=apps.
resource "azurerm_kubernetes_cluster_node_pool" "apps" {
  name                  = "apps"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  mode                  = "User"
  vm_size               = var.apps_node_pool.vm_size
  vnet_subnet_id        = azurerm_subnet.aks.id
  zones                 = var.availability_zones
  auto_scaling_enabled  = true
  min_count             = var.apps_node_pool.min_count
  max_count             = var.apps_node_pool.max_count
  max_pods              = var.apps_node_pool.max_pods
  os_disk_type          = var.apps_node_pool.os_disk_type
  os_disk_size_gb       = var.apps_node_pool.os_disk_size_gb

  node_labels = {
    (var.apps_pool_taint.key) = var.apps_pool_taint.value
  }
  node_taints = ["${var.apps_pool_taint.key}=${var.apps_pool_taint.value}:NoSchedule"]

  upgrade_settings {
    max_surge                     = "33%"
    drain_timeout_in_minutes      = 30
    node_soak_duration_in_minutes = 0
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [node_count]
  }
}

# ---------------------------------------------------------------------------
# Cluster access through Azure RBAC
# ---------------------------------------------------------------------------

locals {
  cluster_admin_principals = toset(concat(
    var.cluster_admin_principal_ids,
    var.grant_deployer_cluster_admin ? [data.azurerm_client_config.current.object_id] : [],
  ))
}

# Data plane: full rights inside Kubernetes.
resource "azurerm_role_assignment" "cluster_admin" {
  for_each = local.cluster_admin_principals

  scope                = azurerm_kubernetes_cluster.this.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = each.value
}

# Control plane: allowed to download the (Entra ID based) kubeconfig with
# `az aks get-credentials`. Holds no Kubernetes rights by itself.
resource "azurerm_role_assignment" "cluster_user" {
  for_each = local.cluster_admin_principals

  scope                = azurerm_kubernetes_cluster.this.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = each.value
}
