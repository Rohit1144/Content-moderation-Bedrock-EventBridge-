# data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# random sufffix for resource names
resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  # naming convention
  name_prefix   = "${var.project_name}-${var.environment}"
  random_suffix = random_id.suffix.hex

  # S3 bucket names
  content_bucket_name  = "${local.name_prefix}-content-${local.random_suffix}"
  approved_bucket_name = "${local.name_prefix}-approved-${local.random_suffix}"
  rejected_bucket_name = "${local.name_prefix}-rejected-${local.random_suffix}"

  # event bridge bus name
  custom_bus_name = "${local.name_prefix}-moderation-bus"

  # SNS topic name
  sns_topic_name = "${local.name_prefix}-notifications"
}

# ============================================================================
# S3 BUCKETS FOR CONTENT STORAGE
# ============================================================================

# s3 bucket for content uploading
resource "aws_s3_bucket" "content_bucket" {
  bucket = local.content_bucket_name
  tags = {
    Name        = local.content_bucket_name
    Purpose     = "ContentUpload"
    Description = "Bucket for storing incoming uplaods"
  }
}

# s3 bucket for approved content
resource "aws_s3_bucket" "approved_bucket" {
  bucket = local.approved_bucket_name
  tags = {
    Name        = local.approved_bucket_name
    Purpose     = "ApprovedContent"
    Description = "Bucket for storing approved content"
  }
}

# s3 bucket for rejected content
resource "aws_s3_bucket" "rejected_bucket" {
  bucket = local.rejected_bucket_name
  tags = {
    Name        = local.rejected_bucket_name
    Purpose     = "RejectedContent"
    Description = "Bucket for storing rejected content"
  }
}

# s3 bucket versioning configuration
resource "aws_s3_bucket_versioning" "content_bucket_versioning" {
  bucket = aws_s3_bucket.content_bucket.id
  versioning_configuration {
    status = var.s3_versioning_enabled ? "Enabled" : "Disabled"
  }
}

resource "aws_s3_bucket_versioning" "approved_bucket_versioning" {
  bucket = aws_s3_bucket.approved_bucket.id
  versioning_configuration {
    status = var.s3_versioning_enabled ? "Enabled" : "Disabled"
  }
}

resource "aws_s3_bucket_versioning" "rejected_bucket_versioning" {
  bucket = aws_s3_bucket.rejected_bucket.id
  versioning_configuration {
    status = var.s3_versioning_enabled ? "Enabled" : "Disabled"
  }
}

# s3 bucket encryption configuration
resource "aws_s3_bucket_server_side_encryption_configuration" "content_bucket_encryption" {
  bucket = aws_s3_bucket.content_bucket.id
  count  = var.s3_encryption_enabled ? 1 : 0

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "approved_bucket_encryption" {
  bucket = aws_s3_bucket.approved_bucket.id
  count  = var.s3_encryption_enabled ? 1 : 0

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "rejected_bucket_encryption" {
  bucket = aws_s3_bucket.rejected_bucket.id
  count  = var.s3_encryption_enabled ? 1 : 0

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# s3 bucket public access blocking
resource "aws_s3_bucket_public_access_block" "content_bucket_pab" {
  bucket = aws_s3_bucket.content_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "approved_bucket_pab" {
  bucket = aws_s3_bucket.approved_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "rejected_bucket_pab" {
  bucket = aws_s3_bucket.rejected_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ============================================================================
# SNS TOPIC FOR NOTIFICATIONS
# ============================================================================

# SNS topic for moderation notifications
resource "aws_sns_topic" "moderation_notifications" {
  name = local.sns_topic_name

  tags = {
    Name        = local.sns_topic_name
    Purpose     = "ModerationNotifications"
    Description = "SNS topic for content moderation decision notifications"
  }
}

resource "aws_sns_topic_subscription" "email_notification" {
  topic_arn = aws_sns_topic.moderation_notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# ============================================================================
# EVENTBRIDGE CUSTOM BUS AND RULES
# ============================================================================

# custom EventBridge bus for content moderation events
resource "aws_cloudwatch_event_bus" "moderation_bus" {
  name = local.custom_bus_name

  tags = {
    Name        = local.custom_bus_name
    Purpose     = "ModerationEvents"
    Description = "Custom event bus for content moderation workflows"
  }
}

# EventBridge rules for routing moderation decisions
resource "aws_cloudwatch_event_rule" "approved_content_rule" {
  name           = "${local.name_prefix}-approved-content-rule"
  description    = "Route approved content events to processing lambda"
  event_bus_name = aws_cloudwatch_event_bus.moderation_bus.name

  event_pattern = jsonencode({
    source      = ["content.moderation"]
    detail-type = ["Content Approved"]
  })

  tags = {
    Name        = "${local.name_prefix}-approved-content-rule"
    Purpose     = "ApprovedContentRouting"
    Description = "EventBridge rule for approved content workflow"
  }
}

resource "aws_cloudwatch_event_rule" "rejected_content_rule" {
  name           = "${local.name_prefix}-rejected-content-rule"
  description    = "Route rejected content events to processing lambda"
  event_bus_name = aws_cloudwatch_event_bus.moderation_bus.name

  event_pattern = jsonencode({
    source      = ["content.moderation"]
    detail-type = ["Content Rejected"]
  })

  tags = {
    Name        = "${local.name_prefix}-rejected-content-rule"
    Purpose     = "RejectedContentRouting"
    Description = "EventBrideg rule for rejected content workflow"
  }
}

resource "aws_cloudwatch_event_rule" "review_content_rule" {
  name           = "${local.name_prefix}-review-content-rule"
  description    = "Route review content events to processign lambda"
  event_bus_name = aws_cloudwatch_event_bus.moderation_bus.name

  event_pattern = jsonencode({
    source      = ["content.moderation"]
    detail-type = ["Content Review"]
  })

  tags = {
    Name        = "${local.name_prefix}-review-content-rule"
    Purpose     = "ReviewContentRouting"
    Description = "EventBridge rule for content requiring human review"
  }
}

# ============================================================================
# IAM ROLES AND POLICIES FOR LAMBDA FUNCTIONS
# ============================================================================

# IAM role for content analysis lambda function
resource "aws_iam_role" "content_analysis_lambda_role" {
  name = "${local.name_prefix}-content-analysis-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${local.name_prefix}-content-analysis-role"
    Purpose     = "LambdaExecution"
    Description = "IAM role for content analysis lambda function"
  }
}

# IAM policy for content analysis lambda function
resource "aws_iam_role_policy" "content_analysis_lambda_policy" {
  name = "${local.name_prefix}-content-analysis-policy"
  role = aws_iam_role.content_analysis_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/anthropic.*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "${aws_s3_bucket.content_bucket.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "events:PutEvents"
        ]
        Resource = "${aws_cloudwatch_event_bus.moderation_bus.arn}"
      }
    ]
  })
}

# Attach basic execution role to content analysis lambda
resource "aws_iam_role_policy_attachment" "content_analysis_basic_execution" {
  role       = aws_iam_role.content_analysis_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM role for workflow lambda functions
resource "aws_iam_role" "workflow_lambda_role" {
  name = "${local.name_prefix}-workflow-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sts:AssumeRole"
        ]
        Principal = {
          Service = "lambda.awsamazon.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${local.name_prefix}-workflow-role"
    Purpose     = "LambdaExecution"
    Description = "IAM role for workflow lambda functions"
  }
}

# IAM policy for workflow lambda functions
resource "aws_iam_role_policy" "workflow_lambda_policy" {
  name = "${local.name_prefix}-workflow-policy"
  role = aws_iam_role.workflow_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:CopyObject"
        ]
        Resource = [
          "${aws_s3_bucket.content_bucket.arn}/*",
          "${aws_s3_bucket.approved_bucket.arn}/*",
          "${aws_s3_bucket.rejected_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = "${aws_sns_topic.moderation_notifications.arn}"
      }
    ]
  })
}

# Attach basic execution role to workflow lambdas
resource "aws_iam_role_policy_attachment" "workflow_basic_execution" {
  role       = aws_iam_role.workflow_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
