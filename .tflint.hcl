# Shared by both Terraform roots. Run from a root with:
#   tflint --init --config "$(git rev-parse --show-toplevel)/.tflint.hcl"
#   tflint --config "$(git rev-parse --show-toplevel)/.tflint.hcl"

config {
  call_module_type = "local"
}

plugin "terraform" {
  enabled = true
  preset  = "all"
}

plugin "azurerm" {
  enabled = true
  version = "0.33.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}
