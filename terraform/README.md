# WorkFort Infrastructure

This directory contains OpenTofu (Terraform) configuration for WorkFort's AWS infrastructure.

## What's Managed

- **Route53**: DNS zone and records for workfort.dev
- **SES**: Email receiving and domain verification
- **S3**: Email storage bucket with 7-day retention
- **CNAME Records**: anvil.workfort.dev, codex.workfort.dev → work-fort.github.io

## Prerequisites

- OpenTofu installed (managed via mise in parent directory)
- AWS credentials configured in `/home/kazw/Work/WorkFort/devops/.env`

## Usage

### Initialize

```bash
cd /home/kazw/Work/WorkFort/devops/terraform
mise exec -- tofu init
```

### Plan Changes

```bash
mise exec -- tofu plan
```

### Apply Changes

```bash
mise exec -- tofu apply
```

### Show Current State

```bash
mise exec -- tofu show
```

### Outputs

```bash
mise exec -- tofu output
```

## Important Notes

- The Route53 hosted zone was imported from existing infrastructure
- State is stored locally (not in remote backend yet)
- Email forwarding Lambda function not yet implemented - requires additional configuration
- After applying, update your domain registrar with the nameservers shown in outputs

## Next Steps

1. Apply this configuration
2. Update domain registrar with Route53 nameservers
3. Add Lambda function for email forwarding (admin@, social@ → the.kaz.walker@gmail.com)
4. Configure SES receipt rules

