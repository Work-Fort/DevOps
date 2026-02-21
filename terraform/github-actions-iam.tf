# IAM user and policy for GitHub Actions CI/CD
# This user has minimal permissions needed for Terraform operations only

resource "aws_iam_user" "github_actions" {
  name = "github-actions-terraform"

  tags = {
    Project     = "WorkFort"
    Description = "CI/CD user for GitHub Actions Terraform deployments"
  }
}

resource "aws_iam_policy" "github_actions_terraform" {
  name        = "GitHubActionsTerraformPolicy"
  description = "Scoped permissions for GitHub Actions to manage WorkFort infrastructure via Terraform"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TerraformStateAccess"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::workfort-terraform-state",
          "arn:aws:s3:::workfort-terraform-state/*"
        ]
      },
      {
        Sid    = "TerraformStateLocking"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:DescribeTable"
        ]
        Resource = "arn:aws:dynamodb:us-east-1:${data.aws_caller_identity.current.account_id}:table/workfort-terraform-locks"
      },
      {
        Sid    = "Route53Management"
        Effect = "Allow"
        Action = [
          "route53:GetHostedZone",
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets",
          "route53:ChangeResourceRecordSets",
          "route53:GetChange",
          "route53:ListTagsForResource",
          "route53:ChangeTagsForResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "ACMManagement"
        Effect = "Allow"
        Action = [
          "acm:DescribeCertificate",
          "acm:ListCertificates",
          "acm:RequestCertificate",
          "acm:DeleteCertificate",
          "acm:AddTagsToCertificate",
          "acm:ListTagsForCertificate"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudFrontManagement"
        Effect = "Allow"
        Action = [
          "cloudfront:GetDistribution",
          "cloudfront:GetDistributionConfig",
          "cloudfront:ListDistributions",
          "cloudfront:CreateDistribution",
          "cloudfront:UpdateDistribution",
          "cloudfront:DeleteDistribution",
          "cloudfront:TagResource",
          "cloudfront:ListTagsForResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3BucketManagement"
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning",
          "s3:PutBucketVersioning",
          "s3:GetBucketWebsite",
          "s3:PutBucketWebsite",
          "s3:DeleteBucketWebsite",
          "s3:GetBucketPolicy",
          "s3:PutBucketPolicy",
          "s3:DeleteBucketPolicy",
          "s3:GetBucketPublicAccessBlock",
          "s3:PutBucketPublicAccessBlock",
          "s3:GetBucketTagging",
          "s3:PutBucketTagging",
          "s3:GetLifecycleConfiguration",
          "s3:PutLifecycleConfiguration",
          "s3:GetEncryptionConfiguration",
          "s3:PutEncryptionConfiguration"
        ]
        Resource = "arn:aws:s3:::workfort-*"
      },
      {
        Sid    = "SESManagement"
        Effect = "Allow"
        Action = [
          "ses:VerifyDomainIdentity",
          "ses:DeleteIdentity",
          "ses:GetIdentityVerificationAttributes",
          "ses:CreateReceiptRuleSet",
          "ses:DeleteReceiptRuleSet",
          "ses:DescribeReceiptRuleSet",
          "ses:SetActiveReceiptRuleSet",
          "ses:CreateReceiptRule",
          "ses:DeleteReceiptRule",
          "ses:DescribeReceiptRule",
          "ses:UpdateReceiptRule"
        ]
        Resource = "*"
      },
      {
        Sid    = "LambdaManagement"
        Effect = "Allow"
        Action = [
          "lambda:CreateFunction",
          "lambda:DeleteFunction",
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration",
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:ListVersionsByFunction",
          "lambda:PublishVersion",
          "lambda:AddPermission",
          "lambda:RemovePermission",
          "lambda:GetPolicy",
          "lambda:TagResource",
          "lambda:ListTags"
        ]
        Resource = "arn:aws:lambda:us-east-1:${data.aws_caller_identity.current.account_id}:function:workfort-*"
      },
      {
        Sid    = "IAMRoleManagement"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:PassRole",
          "iam:TagRole",
          "iam:ListRoleTags"
        ]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/workfort-*"
      },
      {
        Sid    = "DynamoDBManagement"
        Effect = "Allow"
        Action = [
          "dynamodb:CreateTable",
          "dynamodb:DeleteTable",
          "dynamodb:DescribeTable",
          "dynamodb:UpdateTable",
          "dynamodb:TagResource",
          "dynamodb:ListTagsOfResource"
        ]
        Resource = "arn:aws:dynamodb:us-east-1:${data.aws_caller_identity.current.account_id}:table/workfort-*"
      },
      {
        Sid    = "ReadOnlyDescribe"
        Effect = "Allow"
        Action = [
          "sts:GetCallerIdentity"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Project = "WorkFort"
  }
}

resource "aws_iam_user_policy_attachment" "github_actions_terraform" {
  user       = aws_iam_user.github_actions.name
  policy_arn = aws_iam_policy.github_actions_terraform.arn
}

# Output instructions for creating access keys
output "github_actions_user_instructions" {
  value = <<-EOT
    To create access keys for GitHub Actions:
    1. aws iam create-access-key --user-name ${aws_iam_user.github_actions.name}
    2. Store the credentials in GitHub Secrets:
       - AWS_ACCESS_KEY_ID
       - AWS_SECRET_ACCESS_KEY
    3. Delete the old overly-permissive credentials from GitHub
  EOT
  description = "Instructions for setting up GitHub Actions credentials"
}
