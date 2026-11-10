provider "azurerm" {
  features {}
}

# The cluster has local accounts disabled, so there is no client certificate.
# kubelogin turns the current Azure CLI login into an Entra ID token.
# 6dae42f8-4368-4678-94ff-3960e28e3630 is the fixed, public application ID of
# the AKS Entra ID server, the same for every tenant.
provider "helm" {
  kubernetes = {
    host                   = data.azurerm_kubernetes_cluster.this.kube_config[0].host
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "kubelogin"
      args = [
        "get-token",
        "--login", "azurecli",
        "--server-id", "6dae42f8-4368-4678-94ff-3960e28e3630",
      ]
    }
  }
}
