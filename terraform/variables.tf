variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

# forward_to_emails now loaded from SOPS-encrypted secrets.yaml
# See secrets.tf for SOPS data source
locals {
  forward_to_emails = yamldecode(data.sops_file.secrets.raw)["forward_to_emails"]
}
