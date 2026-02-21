# SOPS-encrypted secrets management
# Secrets are stored in secrets.yaml (encrypted with age key)
# SOPS_AGE_KEY environment variable must be set for decryption

data "sops_file" "secrets" {
  source_file = "secrets.yaml"
}
