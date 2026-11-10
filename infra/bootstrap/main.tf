data "azurerm_kubernetes_cluster" "this" {
  name                = var.cluster_name
  resource_group_name = var.resource_group_name
}

locals {
  argo_helm_repo = "https://argoproj.github.io/argo-helm"
}

# Argo CD itself. Values live in a file so they read like any other Helm
# values and can be diffed on chart upgrades.
resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = var.argocd_namespace
  create_namespace = true
  repository       = local.argo_helm_repo
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  values           = [file("${path.module}/values/argo-cd.yaml")]

  atomic          = true
  cleanup_on_fail = true
  timeout         = 600
}

# The root of the app-of-apps tree. Everything else (Kyverno, the policies,
# the demo app) is declared in git under gitops/apps and synced by Argo CD.
# Terraform only owns this one object, so day-two changes go through git.
resource "helm_release" "root_app" {
  name       = "root-app"
  namespace  = var.argocd_namespace
  repository = local.argo_helm_repo
  chart      = "argocd-apps"
  version    = var.argocd_apps_chart_version

  values = [yamlencode({
    applications = {
      root = {
        namespace = var.argocd_namespace
        project   = "default"
        finalizers = [
          "resources-finalizer.argocd.argoproj.io",
        ]
        source = {
          repoURL        = var.gitops_repo_url
          targetRevision = var.gitops_target_revision
          path           = "gitops/apps"
          helm = {
            valuesObject = {
              repoURL        = var.gitops_repo_url
              targetRevision = var.gitops_target_revision
            }
          }
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = var.argocd_namespace
        }
        syncPolicy = {
          automated = {
            prune    = true
            selfHeal = true
          }
        }
      }
    }
  })]

  depends_on = [helm_release.argocd]
}
