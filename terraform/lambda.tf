# IAM role for Lambda email forwarder
resource "aws_iam_role" "email_forwarder" {
  name = "workfort-email-forwarder"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Project = "WorkFort"
  }
}

# IAM policy for Lambda to read from S3 and send via SES
resource "aws_iam_role_policy" "email_forwarder" {
  name = "workfort-email-forwarder-policy"
  role = aws_iam_role.email_forwarder.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.email_storage.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "ses:SendRawEmail"
        ]
        Resource = "*"
      }
    ]
  })
}

# Lambda function for email forwarding
resource "aws_lambda_function" "email_forwarder" {
  filename      = "email_forwarder.zip"
  function_name = "workfort-email-forwarder"
  role          = aws_iam_role.email_forwarder.arn
  handler       = "email_forwarder.handler"
  runtime       = "python3.12"
  timeout       = 30

  source_code_hash = filebase64sha256("email_forwarder.zip")

  environment {
    variables = {
      FORWARD_MAPPING = jsonencode(local.forward_to_emails)
      S3_BUCKET       = aws_s3_bucket.email_storage.id
      FROM_EMAIL      = "noreply@workfort.dev"
    }
  }

  tags = {
    Project = "WorkFort"
  }
}

# Allow SES to invoke Lambda
resource "aws_lambda_permission" "ses_invoke" {
  statement_id   = "AllowSESInvoke"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.email_forwarder.function_name
  principal      = "ses.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
}

# SES Receipt Rule Set
resource "aws_ses_receipt_rule_set" "main" {
  rule_set_name = "workfort-rule-set"
}

# Activate the rule set
resource "aws_ses_active_receipt_rule_set" "main" {
  rule_set_name = aws_ses_receipt_rule_set.main.rule_set_name
}

# SES Receipt Rule for storing and forwarding emails
resource "aws_ses_receipt_rule" "forward_emails" {
  name          = "forward-workfort-emails"
  rule_set_name = aws_ses_receipt_rule_set.main.rule_set_name
  recipients    = ["admin@workfort.dev", "social@workfort.dev"]
  enabled       = true
  scan_enabled  = true

  s3_action {
    bucket_name       = aws_s3_bucket.email_storage.id
    object_key_prefix = "incoming/"
    position          = 1
  }

  lambda_action {
    function_arn    = aws_lambda_function.email_forwarder.arn
    invocation_type = "Event"
    position        = 2
  }

  depends_on = [
    aws_lambda_permission.ses_invoke,
    aws_s3_bucket_policy.email_storage
  ]
}
