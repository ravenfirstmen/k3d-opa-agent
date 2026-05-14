terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region                      = "us-east-1"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  access_key                  = "mock"
  secret_key                  = "mock"
  # No default_tags here on purpose — each resource must declare its own.
}

# DENY: no tags at all.
resource "aws_s3_bucket" "missing_tag" {
  bucket = "example-missing-tag"
}

# DENY: required tag present but empty.
resource "aws_dynamodb_table" "empty_value" {
  name         = "example-empty"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    "my:test:policy-testing" = ""
  }
}

# WARN: disallowed kind + uppercase.
resource "aws_kms_key" "bad_kind" {
  description = "Bad-kind KMS key"

  tags = {
    "my:test:policy-testing" = "Widget:Test"
  }
}

# WARN: missing colon separator.
resource "aws_iam_role" "missing_colon" {
  name = "example-bad-shape"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = {
    "my:test:policy-testing" = "componenttest"
  }
}

# WARN: underscore in name part.
resource "aws_sns_topic" "underscore_name" {
  name = "example-bad-name"

  tags = {
    "my:test:policy-testing" = "component:user_store"
  }
}

# Should be ignored — sub-resource on non_taggable list, no tags expected.
resource "aws_s3_bucket_policy" "ignored_subresource" {
  bucket = aws_s3_bucket.missing_tag.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.missing_tag.arn}/*"
    }]
  })
}

# Good one mixed in to prove the policy isolates failures.
resource "aws_kms_key" "good" {
  description = "Good KMS key"

  tags = {
    "my:test:policy-testing" = "system:test"
  }
}
