variable "resource_group_name" {
  description = "Resource group of the cluster (output resource_group_name of the infra root)."
  type        = string
}

variable "cluster_name" {
  description = "AKS cluster name (output cluster_name of the infra root)."
  type        = string
}

variable "gitops_repo_url" {
  description = "Git URL of this repository (or your fork). Argo CD reads gitops/ and policies/ from it."
  type        = string

  validation {
    condition     = can(regex("^(https://|ssh://|git@)", var.gitops_repo_url))
    error_message = "gitops_repo_url must start with https://, ssh:// or git@."
  }
}

variable "gitops_target_revision" {
  description = "Branch, tag or commit Argo CD tracks. Pin a tag for anything beyond a demo."
  type        = string
  default     = "main"
}

variable "argocd_namespace" {
  description = "Namespace for Argo CD."
  type        = string
  default     = "argocd"

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.argocd_namespace)) && length(var.argocd_namespace) <= 63
    error_message = "argocd_namespace must be a valid Kubernetes namespace name."
  }
}

variable "argocd_chart_version" {
  description = "Version of the argo-cd Helm chart (argoproj/argo-helm). Pinned so upgrades are deliberate."
  type        = string
  default     = "10.17.1"
}

variable "argocd_apps_chart_version" {
  description = "Version of the argocd-apps Helm chart used to create the root Application."
  type        = string
  default     = "2.0.8"
}
