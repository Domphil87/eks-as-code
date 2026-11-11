# TFLint configuration shared by every Terraform folder in this repo.
# Run from the repo root:  tflint --init  then  tflint --recursive

config {
  # Also lint the calls our root configurations make into ./modules
  call_module_type = "local"
}

# Built-in Terraform rules: unused declarations, missing version
# constraints, naming conventions, documented variables/outputs, etc.
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# AWS-specific rules: invalid instance types, invalid regions, and so on.
plugin "aws" {
  enabled = true
  version = "0.50.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

rule "terraform_naming_convention" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}
