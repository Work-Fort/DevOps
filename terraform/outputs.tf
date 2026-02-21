output "nameservers" {
  description = "Route53 nameservers to configure at domain registrar"
  value       = aws_route53_zone.workfort.name_servers
}

output "hosted_zone_id" {
  description = "Route53 hosted zone ID"
  value       = aws_route53_zone.workfort.zone_id
}

output "ses_verification_token" {
  description = "SES domain verification token"
  value       = aws_ses_domain_identity.workfort.verification_token
}

output "s3_bucket_name" {
  description = "S3 bucket for email storage"
  value       = aws_s3_bucket.email_storage.id
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID for apex redirect"
  value       = aws_cloudfront_distribution.apex_redirect.id
}

output "cloudfront_domain_name" {
  description = "CloudFront domain name for apex redirect"
  value       = aws_cloudfront_distribution.apex_redirect.domain_name
}

output "acm_certificate_arn" {
  description = "ACM certificate ARN"
  value       = aws_acm_certificate.workfort.arn
}

# Website deployment outputs
output "website_s3_bucket" {
  description = "S3 bucket name for website hosting"
  value       = aws_s3_bucket.website.id
}

output "website_cloudfront_id" {
  description = "CloudFront distribution ID for www.workfort.dev"
  value       = aws_cloudfront_distribution.website.id
}

output "website_cloudfront_domain" {
  description = "CloudFront domain name for www.workfort.dev"
  value       = aws_cloudfront_distribution.website.domain_name
}

output "website_deploy_access_key_id" {
  description = "IAM access key ID for website deployment"
  value       = aws_iam_access_key.website_deploy.id
}

output "website_deploy_secret_key" {
  description = "IAM secret access key for website deployment"
  value       = aws_iam_access_key.website_deploy.secret
  sensitive   = true
}
