# ACM Certificate for CloudFront (must be in us-east-1)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

resource "aws_acm_certificate" "workfort" {
  provider          = aws.us_east_1
  domain_name       = "workfort.dev"
  validation_method = "DNS"

  subject_alternative_names = [
    "*.workfort.dev"
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Project = "WorkFort"
  }
}

# DNS validation records for ACM certificate
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.workfort.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.workfort.zone_id
}

# Wait for ACM certificate validation
resource "aws_acm_certificate_validation" "workfort" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.workfort.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# S3 bucket for apex redirect
resource "aws_s3_bucket" "apex_redirect" {
  bucket = "workfort-apex-redirect"

  tags = {
    Project = "WorkFort"
  }
}

# S3 bucket website configuration for redirect
resource "aws_s3_bucket_website_configuration" "apex_redirect" {
  bucket = aws_s3_bucket.apex_redirect.id

  redirect_all_requests_to {
    host_name = "www.workfort.dev"
    protocol  = "https"
  }
}

# CloudFront distribution for apex redirect
resource "aws_cloudfront_distribution" "apex_redirect" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "WorkFort apex to www redirect"
  aliases             = ["workfort.dev"]
  price_class         = "PriceClass_100" # US, Canada, Europe
  default_root_object = ""

  origin {
    domain_name = aws_s3_bucket_website_configuration.apex_redirect.website_endpoint
    origin_id   = "S3-apex-redirect"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-apex-redirect"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 86400
    max_ttl     = 31536000
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.workfort.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Project = "WorkFort"
  }

  depends_on = [aws_acm_certificate_validation.workfort]
}

# Route53 A record for apex domain pointing to CloudFront
resource "aws_route53_record" "apex" {
  zone_id = aws_route53_zone.workfort.zone_id
  name    = "workfort.dev"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.apex_redirect.domain_name
    zone_id                = aws_cloudfront_distribution.apex_redirect.hosted_zone_id
    evaluate_target_health = false
  }
}

# Route53 AAAA record for apex domain (IPv6)
resource "aws_route53_record" "apex_ipv6" {
  zone_id = aws_route53_zone.workfort.zone_id
  name    = "workfort.dev"
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.apex_redirect.domain_name
    zone_id                = aws_cloudfront_distribution.apex_redirect.hosted_zone_id
    evaluate_target_health = false
  }
}
