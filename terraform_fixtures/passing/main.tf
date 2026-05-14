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

  default_tags {
    tags = {
      "my:test:policy-testing" = "system:tagging-standards"
    }
  }
}

# Tag inherited from provider default_tags -> appears in tags_all -> passes.
resource "aws_s3_bucket" "from_default_tags" {
  bucket = "example-bucket-default-tags"
}

# Explicit tag overrides default -> passes.
resource "aws_dynamodb_table" "explicit_tag" {
  name         = "example-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    "my:test:policy-testing" = "component:user-store"
  }
}

# Namespaced form (kind:namespace/name) -> passes.
resource "aws_kms_key" "namespaced" {
  description = "Example KMS key"

  tags = {
    "my:test:policy-testing" = "component:platform/auth-service"
  }
}

# Sub-resource without tags. Matches non_taggable set -> skipped, no violation.
resource "aws_s3_bucket_versioning" "sub_resource" {
  bucket = aws_s3_bucket.from_default_tags.id

  versioning_configuration {
    status = "Enabled"
  }
}
