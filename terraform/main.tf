# WorkFort Infrastructure Configuration
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    sops = {
      source  = "carlpett/sops"
      version = "~> 1.1"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Route53 Hosted Zone
resource "aws_route53_zone" "workfort" {
  name = "workfort.dev"

  tags = {
    Project = "WorkFort"
  }
}

# CNAME Records for GitHub Pages
resource "aws_route53_record" "anvil" {
  zone_id = aws_route53_zone.workfort.zone_id
  name    = "anvil.workfort.dev"
  type    = "CNAME"
  ttl     = 300
  records = ["work-fort.github.io"]
}

resource "aws_route53_record" "codex" {
  zone_id = aws_route53_zone.workfort.zone_id
  name    = "codex.workfort.dev"
  type    = "CNAME"
  ttl     = 300
  records = ["work-fort.github.io"]
}

# SES Domain Identity
resource "aws_ses_domain_identity" "workfort" {
  domain = "workfort.dev"
}

# SES Domain Verification TXT Record
resource "aws_route53_record" "ses_verification" {
  zone_id = aws_route53_zone.workfort.zone_id
  name    = "_amazonses.workfort.dev"
  type    = "TXT"
  ttl     = 300
  records = [aws_ses_domain_identity.workfort.verification_token]
}

# SES MX Record for receiving email
resource "aws_route53_record" "ses_mx" {
  zone_id = aws_route53_zone.workfort.zone_id
  name    = "workfort.dev"
  type    = "MX"
  ttl     = 300
  records = ["10 inbound-smtp.${var.aws_region}.amazonaws.com"]
}

# S3 Bucket for storing incoming emails
resource "aws_s3_bucket" "email_storage" {
  bucket = "workfort-email-storage"

  tags = {
    Project = "WorkFort"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "email_storage" {
  bucket = aws_s3_bucket.email_storage.id

  rule {
    id     = "delete-old-emails"
    status = "Enabled"

    filter {}

    expiration {
      days = 7
    }
  }
}

# S3 Bucket Policy for SES
resource "aws_s3_bucket_policy" "email_storage" {
  bucket = aws_s3_bucket.email_storage.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSESPuts"
        Effect = "Allow"
        Principal = {
          Service = "ses.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.email_storage.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

data "aws_caller_identity" "current" {}
