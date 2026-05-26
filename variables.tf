variable "aws_region" {
  description = "Region used to deploy services in"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "AWS region must be in the format xx_xxxx_x (example: us-east-1)"
  }
}

variable "environment" {
  description = "App environment (Prod, Dev, Staging)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment name must be dev, staging or prod"
  }
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "contentmoderation"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must only have lowercase letters, numbers and hyphens"
  }
}

variable "s3_versioning_enabled" {
  description = "Enable versioning on S3 buckets"
  type        = bool
  default     = true
}

variable "s3_encryption_enabled" {
  description = "Enable server-side encryption on S3 buckets"
  type        = bool
  default     = true

}

variable "notification_email" {
  description = "Email address for SNS notifications about content moderation decisions"
  type        = string
  default     = "rohitchowdary1144@gmail.com"

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.notification_email))
    error_message = "Please provide a valid email address"
  }
}
