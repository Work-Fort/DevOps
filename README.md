# WorkFort DevOps Infrastructure

Infrastructure as Code for the WorkFort project using OpenTofu (Terraform) and AWS.

## Architecture

- **AWS Account**: WorkFort member account (725245223250) via AWS Organizations
- **DNS**: Route53 hosted zone for workfort.dev
- **Email**: SES email receiving + Lambda forwarding to personal email
- **CDN**: CloudFront for apex redirect (workfort.dev → www.workfort.dev)
- **SSL**: ACM certificates for HTTPS
- **State**: S3 remote backend with DynamoDB locking
- **Secrets**: SOPS encryption with age keys (encrypted secrets committed to git)
- **CI/CD**: GitHub Actions auto-deploy on push to master

## Prerequisites

- [mise](https://mise.jdx.dev/) - version manager for all tools
- AWS account with Organizations enabled
- GitHub account with gh CLI configured
- Domain registered and ready for DNS migration

## Bootstrap Process

### 1. Clone Repository

```bash
git clone https://github.com/Work-Fort/DevOps.git
cd DevOps
```

### 2. Install Tools

```bash
# mise automatically installs all tools from .mise.toml
mise install
```

This installs:
- AWS CLI
- OpenTofu (Terraform fork)
- SOPS (secrets encryption)
- age (encryption backend)

### 3. Configure AWS Credentials

**IMPORTANT**: Use scoped credentials for day-to-day operations.

Create `.env` file (git-ignored):

```bash
# WorkFort member account credentials (scoped permissions)
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...
AWS_DEFAULT_REGION=us-east-1
```

**For initial bootstrap ONLY**, you may need elevated credentials to create:
- S3 state bucket
- DynamoDB locks table
- IAM users/policies

Store elevated credentials in `.aws/credentials` temporarily, remove after bootstrap.

### 4. Decrypt Secrets

Secrets are encrypted with SOPS and committed to the repository. To decrypt:

```bash
# Set the SOPS_AGE_KEY environment variable (private key)
export SOPS_AGE_KEY='AGE-SECRET-KEY-1...'

# Verify decryption works
cd terraform
mise exec -- sops --decrypt secrets.yaml
```

**Getting the age key**:
- For first-time setup: Generate new key (see "Rotating Encryption Keys" below)
- For existing setup: Get `SOPS_AGE_KEY` from team lead or secure storage

### 5. Initialize Terraform

```bash
cd terraform
mise exec -- tofu init
```

This downloads providers:
- AWS provider
- SOPS provider (carlpett/sops)

### 6. Review and Apply

```bash
# Review planned changes
mise exec -- tofu plan

# Apply infrastructure
mise exec -- tofu apply
```

### 7. Update DNS

After Route53 hosted zone is created, update your domain registrar with the nameservers:

```bash
mise exec -- tofu output nameservers
```

Set these NS records at your domain registrar (e.g., Namecheap, GoDaddy).

## Secrets Management

### How It Works

1. **Secrets file**: `terraform/secrets.yaml` contains sensitive data (emails, account IDs, tokens)
2. **Encryption**: File is encrypted with SOPS using age encryption
3. **Version control**: **Encrypted file is committed** to git (safe - encrypted)
4. **Decryption**: SOPS automatically decrypts at runtime when `SOPS_AGE_KEY` is set
5. **Terraform integration**: `terraform-provider-sops` reads decrypted values

### Adding New Secrets

```bash
# 1. Set your age key
export SOPS_AGE_KEY=$(cat age-key.txt | grep -v "public key")

# 2. Edit secrets file (SOPS auto-decrypts for editing)
cd terraform
mise exec -- sops secrets.yaml

# 3. Make your changes in your editor
# 4. Save and exit - SOPS auto-encrypts on save

# 5. Commit the encrypted file
git add secrets.yaml
git commit -m "feat(secrets): add new email forwarding address"
git push
```

### Rotating Encryption Keys

**When to rotate**: Security incident, team member departure, annual rotation

```bash
# 1. Generate new age key
mise exec -- age-keygen -o age-key-new.txt

# 2. Extract the new public key
grep "public key:" age-key-new.txt

# 3. Update .sops.yaml with new public key
# Edit .sops.yaml and replace the age: field

# 4. Re-encrypt secrets with new key
cd terraform
export SOPS_AGE_KEY=$(cat ../age-key.txt | grep -v "public key")
mise exec -- sops rotate --in-place secrets.yaml

# 5. Update GitHub Secrets with new SOPS_AGE_KEY
gh secret set SOPS_AGE_KEY < age-key-new.txt

# 6. Replace old key
mv age-key-new.txt age-key.txt

# 7. Commit updated secrets and config
git add .sops.yaml terraform/secrets.yaml
git commit -m "security: rotate age encryption key"
git push
```

## GitHub Actions Setup

### Required Secrets

Set these in GitHub repository settings → Secrets and variables → Actions:

1. **AWS_ACCESS_KEY_ID**: GitHub Actions IAM user access key
2. **AWS_SECRET_ACCESS_KEY**: GitHub Actions IAM user secret key
3. **SOPS_AGE_KEY**: age private key for decrypting secrets.yaml

```bash
# Set AWS credentials
gh secret set AWS_ACCESS_KEY_ID -b "AKIA..."
gh secret set AWS_SECRET_ACCESS_KEY -b "..."

# Set SOPS age key (entire contents of age-key.txt)
gh secret set SOPS_AGE_KEY < age-key.txt
```

### IAM User Permissions

The `github-actions-terraform` IAM user has scoped permissions for:
- Route53 (DNS management)
- ACM (SSL certificates)
- CloudFront (CDN)
- SES (email service)
- Lambda (email forwarding function)
- S3 (state backend + email storage)
- DynamoDB (state locking)

**This user cannot**:
- Create/delete IAM users or policies
- Modify AWS Organizations
- Access resources outside the WorkFort member account

### Workflow

Push to `master` branch triggers GitHub Actions:

1. Checkout code
2. Set up OpenTofu
3. Configure AWS credentials
4. Set `SOPS_AGE_KEY` for secret decryption
5. Run `tofu init`
6. Run `tofu plan`
7. Run `tofu apply` (auto-approved)

## Email Forwarding

Emails sent to `@workfort.dev` are forwarded to personal emails defined in `secrets.yaml`:

```yaml
forward_to_emails:
  admin: your-email@gmail.com
  social: your-email@gmail.com
```

Supported addresses:
- admin@workfort.dev → forwards to `forward_to_emails.admin`
- social@workfort.dev → forwards to `forward_to_emails.social`

To add new addresses:

1. Edit `terraform/secrets.yaml` (see "Adding New Secrets" above)
2. Add the new mapping (e.g., `support: your-email@gmail.com`)
3. Update `terraform/lambda.tf` recipients list (line 105)
4. Commit and push

## Project Structure

```
.
├── .github/
│   └── workflows/
│       └── terraform.yml          # GitHub Actions CI/CD
├── terraform/
│   ├── main.tf                    # Core infrastructure (Route53, SES, S3)
│   ├── backend.tf                 # S3 remote state configuration
│   ├── variables.tf               # Input variables and locals
│   ├── secrets.tf                 # SOPS data source for secrets
│   ├── secrets.yaml               # SOPS-encrypted secrets (COMMITTED)
│   ├── cloudfront.tf              # Apex redirect via CloudFront
│   ├── lambda.tf                  # Email forwarding Lambda function
│   ├── github-actions-iam.tf      # Scoped IAM user for CI/CD
│   └── email_forwarder.py         # Lambda function source code
├── .mise.toml                     # Tool version pinning
├── .sops.yaml                     # SOPS encryption configuration
├── .gitignore                     # Prevents committing sensitive files
├── .env                           # AWS credentials (GIT-IGNORED)
├── age-key.txt                    # age private key (GIT-IGNORED)
└── README.md                      # This file
```

## Security Checklist

Before committing to git, verify:

- [ ] No unencrypted secrets in tracked files
- [ ] `secrets.yaml` is encrypted (run `sops --decrypt secrets.yaml` to verify)
- [ ] `.env` file is git-ignored
- [ ] `age-key.txt` is git-ignored
- [ ] No email addresses in plaintext (check: `grep -r "gmail.com" .`)
- [ ] No AWS account IDs in plaintext (check: `grep -r "725245223250" .`)
- [ ] No AWS access keys in plaintext (check: `grep -r "AKIA" .`)

## Common Operations

### Verify Current Infrastructure

```bash
cd terraform
export SOPS_AGE_KEY=$(cat ../age-key.txt | grep -v "public key")
mise exec -- tofu plan
```

### Destroy Infrastructure

**WARNING**: This deletes all resources. Use with caution.

```bash
cd terraform
export SOPS_AGE_KEY=$(cat ../age-key.txt | grep -v "public key")
mise exec -- tofu destroy
```

### Test Lambda Function Locally

```bash
cd terraform
python3 email_forwarder.py
```

### View Encrypted Secrets

```bash
cd terraform
export SOPS_AGE_KEY=$(cat ../age-key.txt | grep -v "public key")
mise exec -- sops --decrypt secrets.yaml
```

## Troubleshooting

### "Error decrypting key: no keys match"

**Cause**: `SOPS_AGE_KEY` not set or incorrect

**Fix**:
```bash
export SOPS_AGE_KEY=$(cat age-key.txt | grep -v "public key")
```

### "Failed to load state: AccessDenied"

**Cause**: AWS credentials don't have S3 access

**Fix**: Verify `.env` has correct credentials with S3 permissions

### "Resource already exists"

**Cause**: Running `tofu apply` on infrastructure that's already deployed

**Fix**: Use `tofu import` to import existing resources or destroy and recreate

### GitHub Actions Failing

**Cause**: Missing or incorrect GitHub Secrets

**Fix**: Verify all required secrets are set:
```bash
gh secret list
```

## Contributing

1. Create feature branch
2. Make infrastructure changes
3. Test locally with `tofu plan`
4. Update this README if adding new components
5. Commit and push
6. Create pull request

## License

GPL-2.0-only - See [LICENSE.md](LICENSE.md) for details

## Support

For questions or issues, contact the TPM or team lead.
