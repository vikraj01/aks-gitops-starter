# ---------------------------------------------------------------------------
# General
# ---------------------------------------------------------------------------

variable "name_prefix" {
  description = "Short name used to build every resource name (for example aks-<prefix>). Lowercase letters, digits and hyphens."
  type        = string
  default     = "gitops-starter"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,18}[a-z0-9]$", var.name_prefix))
    error_message = "name_prefix must be 3 to 20 characters, start with a letter, end with a letter or digit, and use only lowercase letters, digits and hyphens."
  }
}

variable "location" {
  description = "Azure region for all resources. Pick one with availability zones if you keep the default zones."
  type        = string
  default     = "westeurope"
}

variable "tags" {
  description = "Tags applied to every resource that supports them."
  type        = map(string)
  default = {
    managed-by = "terraform"
    project    = "aks-gitops-starter"
  }
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------

variable "vnet_address_space" {
  description = "Address space of the virtual network."
  type        = string
  default     = "10.10.0.0/16"

  validation {
    condition     = can(cidrhost(var.vnet_address_space, 0))
    error_message = "vnet_address_space must be a valid IPv4 CIDR block."
  }
}

variable "aks_subnet_prefix" {
  description = "Subnet for AKS nodes. With Azure CNI overlay only nodes take VNet IPs, so a /22 covers about 1,000 nodes."
  type        = string
  default     = "10.10.0.0/22"

  validation {
    condition     = can(cidrhost(var.aks_subnet_prefix, 0))
    error_message = "aks_subnet_prefix must be a valid IPv4 CIDR block."
  }
}

variable "pod_cidr" {
  description = "Overlay CIDR for pod IPs. Not routable outside the cluster, must not overlap the VNet or service CIDR."
  type        = string
  default     = "10.244.0.0/16"

  validation {
    condition     = can(cidrhost(var.pod_cidr, 0))
    error_message = "pod_cidr must be a valid IPv4 CIDR block."
  }
}

variable "service_cidr" {
  description = "CIDR for Kubernetes services. Must not overlap the VNet or pod CIDR."
  type        = string
  default     = "172.16.0.0/16"

  validation {
    condition     = can(cidrhost(var.service_cidr, 0))
    error_message = "service_cidr must be a valid IPv4 CIDR block."
  }
}

variable "dns_service_ip" {
  description = "Cluster DNS service IP. Must sit inside service_cidr."
  type        = string
  default     = "172.16.0.10"

  validation {
    condition     = can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", var.dns_service_ip))
    error_message = "dns_service_ip must be an IPv4 address."
  }
}

variable "api_server_authorized_ip_ranges" {
  description = "CIDR ranges allowed to reach the public API server, for example your office or VPN egress as x.x.x.x/32. Required on purpose: an open API server should be a conscious choice, not a default."
  type        = list(string)

  validation {
    condition     = length(var.api_server_authorized_ip_ranges) > 0 && alltrue([for r in var.api_server_authorized_ip_ranges : can(cidrhost(r, 0))])
    error_message = "Provide at least one valid IPv4 CIDR range, for example [\"203.0.113.10/32\"]."
  }
}

# ---------------------------------------------------------------------------
# Cluster
# ---------------------------------------------------------------------------

variable "kubernetes_version" {
  description = "Kubernetes minor version (for example \"1.33\"). Null lets AKS pick its current default. Patch versions are handled by the automatic upgrade channel."
  type        = string
  default     = null

  validation {
    condition     = var.kubernetes_version == null || can(regex("^\\d+\\.\\d+$", var.kubernetes_version))
    error_message = "kubernetes_version must be a minor version such as \"1.33\", or null."
  }
}

variable "sku_tier" {
  description = "AKS control plane tier. Free has no uptime SLA. Use Standard for anything production."
  type        = string
  default     = "Free"

  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.sku_tier)
    error_message = "sku_tier must be Free, Standard or Premium."
  }
}

variable "availability_zones" {
  description = "Zones used by both node pools. Set to [] in regions without availability zones."
  type        = list(string)
  default     = ["1", "2", "3"]

  validation {
    condition     = alltrue([for z in var.availability_zones : contains(["1", "2", "3"], z)])
    error_message = "availability_zones may only contain \"1\", \"2\" and \"3\"."
  }
}

variable "automatic_upgrade_channel" {
  description = "AKS automatic upgrade channel for the Kubernetes version."
  type        = string
  default     = "patch"

  validation {
    condition     = contains(["none", "patch", "stable", "rapid", "node-image"], var.automatic_upgrade_channel)
    error_message = "automatic_upgrade_channel must be one of none, patch, stable, rapid, node-image."
  }
}

variable "node_os_upgrade_channel" {
  description = "How node OS images are kept current."
  type        = string
  default     = "NodeImage"

  validation {
    condition     = contains(["None", "Unmanaged", "SecurityPatch", "NodeImage"], var.node_os_upgrade_channel)
    error_message = "node_os_upgrade_channel must be one of None, Unmanaged, SecurityPatch, NodeImage."
  }
}

variable "maintenance_window" {
  description = "Weekly window (UTC offset as given) in which AKS may apply automatic cluster and node OS upgrades."
  type = object({
    day_of_week    = string
    start_time     = string
    duration_hours = number
    utc_offset     = string
  })
  default = {
    day_of_week    = "Sunday"
    start_time     = "02:00"
    duration_hours = 4
    utc_offset     = "+00:00"
  }

  validation {
    condition     = contains(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], var.maintenance_window.day_of_week)
    error_message = "maintenance_window.day_of_week must be a full English day name, for example Sunday."
  }

  validation {
    condition     = can(regex("^([01]\\d|2[0-3]):[0-5]\\d$", var.maintenance_window.start_time))
    error_message = "maintenance_window.start_time must be HH:MM in 24 hour format."
  }

  validation {
    condition     = var.maintenance_window.duration_hours >= 4 && var.maintenance_window.duration_hours <= 24
    error_message = "maintenance_window.duration_hours must be between 4 and 24 (AKS minimum is 4)."
  }

  validation {
    condition     = can(regex("^[+-](0\\d|1[0-4]):[0-5]\\d$", var.maintenance_window.utc_offset))
    error_message = "maintenance_window.utc_offset must look like +00:00 or -05:00."
  }
}

variable "system_node_pool" {
  description = "System node pool. Runs kube-system plus the platform add-ons (Argo CD, Kyverno). Ephemeral OS disks need a VM size whose cache or temp disk is at least os_disk_size_gb."
  type = object({
    vm_size         = string
    min_count       = number
    max_count       = number
    os_disk_type    = string
    os_disk_size_gb = number
    max_pods        = number
  })
  default = {
    vm_size         = "Standard_D2ads_v5"
    min_count       = 2
    max_count       = 3
    os_disk_type    = "Ephemeral"
    os_disk_size_gb = 64
    max_pods        = 110
  }

  validation {
    condition     = var.system_node_pool.min_count >= 1 && var.system_node_pool.min_count <= var.system_node_pool.max_count
    error_message = "system_node_pool.min_count must be at least 1 and not greater than max_count."
  }

  validation {
    condition     = contains(["Managed", "Ephemeral"], var.system_node_pool.os_disk_type)
    error_message = "system_node_pool.os_disk_type must be Managed or Ephemeral."
  }
}

variable "apps_node_pool" {
  description = "Dedicated user node pool for application workloads. It carries the taint workload=apps:NoSchedule, so only pods that tolerate it land here."
  type = object({
    vm_size         = string
    min_count       = number
    max_count       = number
    os_disk_type    = string
    os_disk_size_gb = number
    max_pods        = number
  })
  default = {
    vm_size         = "Standard_D2ads_v5"
    min_count       = 1
    max_count       = 5
    os_disk_type    = "Ephemeral"
    os_disk_size_gb = 64
    max_pods        = 110
  }

  validation {
    condition     = var.apps_node_pool.min_count >= 0 && var.apps_node_pool.min_count <= var.apps_node_pool.max_count
    error_message = "apps_node_pool.min_count must be 0 or more and not greater than max_count."
  }

  validation {
    condition     = contains(["Managed", "Ephemeral"], var.apps_node_pool.os_disk_type)
    error_message = "apps_node_pool.os_disk_type must be Managed or Ephemeral."
  }
}

variable "apps_pool_taint" {
  description = "Key and value of the taint and label that mark the dedicated apps pool. Keep in sync with the Kyverno mutation policy in policies/."
  type = object({
    key   = string
    value = string
  })
  default = {
    key   = "workload"
    value = "apps"
  }
}

# ---------------------------------------------------------------------------
# Access
# ---------------------------------------------------------------------------

variable "grant_deployer_cluster_admin" {
  description = "Give the identity running Terraform the Azure Kubernetes Service RBAC Cluster Admin role, so the bootstrap root can install Argo CD. Turn off once access is managed through groups."
  type        = bool
  default     = true
}

variable "cluster_admin_principal_ids" {
  description = "Object IDs of Entra ID groups or users that get the Azure Kubernetes Service RBAC Cluster Admin role. Prefer groups."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for id in var.cluster_admin_principal_ids : can(regex("^[0-9a-fA-F-]{36}$", id))])
    error_message = "cluster_admin_principal_ids must be object IDs (GUIDs)."
  }
}

# ---------------------------------------------------------------------------
# Monitoring
# ---------------------------------------------------------------------------

variable "log_retention_days" {
  description = "Retention for the Log Analytics workspace. 30 days is included in the ingestion price."
  type        = number
  default     = 30

  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 730
    error_message = "log_retention_days must be between 30 and 730."
  }
}

variable "log_daily_quota_gb" {
  description = "Daily ingestion cap for the workspace in GB, a guard against surprise bills. -1 means no cap."
  type        = number
  default     = 2

  validation {
    condition     = var.log_daily_quota_gb == -1 || var.log_daily_quota_gb > 0
    error_message = "log_daily_quota_gb must be -1 (no cap) or a positive number."
  }
}

variable "control_plane_log_categories" {
  description = "AKS control plane log categories sent to Log Analytics. kube-audit-admin skips read-only calls and is far cheaper than kube-audit."
  type        = list(string)
  default     = ["kube-audit-admin", "guard"]

  validation {
    condition = alltrue([for c in var.control_plane_log_categories : contains([
      "kube-apiserver", "kube-audit", "kube-audit-admin", "kube-controller-manager",
      "kube-scheduler", "cluster-autoscaler", "cloud-controller-manager", "guard",
      "csi-azuredisk-controller", "csi-azurefile-controller", "csi-snapshot-controller",
    ], c)])
    error_message = "control_plane_log_categories contains an unknown AKS diagnostic category."
  }
}
