# S3 bucket for website hosting
resource "aws_s3_bucket" "website" {
  bucket = "workfort-website"

  tags = {
    Project = "WorkFort"
    Purpose = "Docusaurus website hosting"
  }
}

# S3 bucket versioning for rollback capability
resource "aws_s3_bucket_versioning" "website" {
  bucket = aws_s3_bucket.website.id

  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket public access block (private bucket)
resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CloudFront Origin Access Control for secure S3 access
resource "aws_cloudfront_origin_access_control" "website" {
  name                              = "workfort-website-oac"
  description                       = "OAC for workfort-website S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Function for URL rewriting (Docusaurus folder/index.html structure)
resource "aws_cloudfront_function" "url_rewrite" {
  name    = "workfort-website-url-rewrite"
  runtime = "cloudfront-js-2.0"
  comment = "Rewrite URLs for Docusaurus folder structure"
  publish = true
  code    = <<-EOT
    function handler(event) {
        var request = event.request;
        var uri = request.uri;

        // If URI ends with /, append index.html
        if (uri.endsWith('/')) {
            request.uri += 'index.html';
        }
        // If URI has no file extension, append /index.html
        else if (!uri.includes('.') && !uri.includes('?')) {
            request.uri += '/index.html';
        }

        return request;
    }
  EOT
}

# CloudFront distribution for website
resource "aws_cloudfront_distribution" "website" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "WorkFort website (www.workfort.dev)"
  aliases             = ["www.workfort.dev"]
  price_class         = "PriceClass_100" # US, Canada, Europe
  default_root_object = "index.html"

  origin {
    domain_name              = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id                = "S3-workfort-website"
    origin_access_control_id = aws_cloudfront_origin_access_control.website.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-workfort-website"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    # Associate URL rewrite function
    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.url_rewrite.arn
    }

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 86400    # 1 day
    max_ttl     = 31536000 # 1 year
  }

  # Custom error responses for Docusaurus 404 page
  custom_error_response {
    error_code         = 404
    response_code      = 404
    response_page_path = "/404.html"
  }

  custom_error_response {
    error_code         = 403
    response_code      = 404
    response_page_path = "/404.html"
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

# S3 bucket policy to allow CloudFront OAC access
resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontOAC"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.website.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.website.arn
          }
        }
      }
    ]
  })
}

# Route53 A record for www.workfort.dev
resource "aws_route53_record" "website" {
  zone_id = aws_route53_zone.workfort.zone_id
  name    = "www.workfort.dev"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
    evaluate_target_health = false
  }
}

# Route53 AAAA record for www.workfort.dev (IPv6)
resource "aws_route53_record" "website_ipv6" {
  zone_id = aws_route53_zone.workfort.zone_id
  name    = "www.workfort.dev"
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
    evaluate_target_health = false
  }
}

# IAM user for website deployment
resource "aws_iam_user" "website_deploy" {
  name = "website-deploy"

  tags = {
    Project = "WorkFort"
    Purpose = "Website deployment to S3 with CloudFront invalidation"
  }
}

# IAM policy for website deployment (least privilege)
resource "aws_iam_user_policy" "website_deploy" {
  name = "website-deploy-policy"
  user = aws_iam_user.website_deploy.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3BucketAccess"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.website.arn,
          "${aws_s3_bucket.website.arn}/*"
        ]
      },
      {
        Sid    = "CloudFrontInvalidation"
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation",
          "cloudfront:GetInvalidation"
        ]
        Resource = aws_cloudfront_distribution.website.arn
      }
    ]
  })
}

# IAM access key for website deployment
resource "aws_iam_access_key" "website_deploy" {
  user = aws_iam_user.website_deploy.name
}
