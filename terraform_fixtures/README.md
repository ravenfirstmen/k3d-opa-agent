# Terraform Fixtures

Terraform plans used to exercise the Spacelift `require-catalog-ref-tag` Rego policy in [`../rego_spacelift/`](../rego_spacelift/).

Reference: https://spacelift.io/blog/what-is-open-policy-agent-and-how-it-works

## Overview

Two minimal Terraform configurations produce plan JSON that the policy evaluates:

- `passing/` — resources are tagged correctly; policy returns no denies.
- `failing/` — resources are missing or mis-formatting the required `my:test:policy-testing` tag; policy returns denies/warns.

Pre-generated plan output is checked in (`plan_passing.json`, `plan_failing.json`) so the policy can be evaluated without re-running Terraform.

## Layout

```
terraform_fixtures/
├── passing/main.tf       # clean fixture
├── failing/main.tf       # violating fixture
├── plan_passing.json     # pre-generated plan (Spacelift-wrapped)
├── plan_failing.json     # pre-generated plan (Spacelift-wrapped)
└── run.sh                # regenerates plans and evaluates the policy
```

The plan JSON is wrapped in `{"terraform": ...}` to match the Spacelift input envelope expected by the policy (`input.terraform.resource_changes`).

## Prerequisites

- `tofu` (or `terraform`) — set `TERRAFORM` in `run.sh` if you use `terraform`
- `opa`
- `jq`

No AWS credentials are required; the fixtures use mock provider settings.

## Usage

### Re-generate plans and evaluate

```bash
./run.sh
```

This runs `tofu init`/`plan`/`show -json` against both fixtures, wraps the failing plan in the Spacelift envelope, and evaluates `data.rego_spacelift.deny` for each.

### Evaluate against existing plan JSON

```bash
opa eval \
  --data ../rego_spacelift/require-catalog-ref-tag.rego \
  --input plan_failing.json \
  --format pretty \
  'data.rego_spacelift'
```

### Lighter-weight alternative — conftest

```bash
tofu -chdir=failing show -json plan.tfplan \
  | jq '{terraform: .}' \
  | conftest test --policy ../rego_spacelift/ --namespace rego_spacelift -
```

## Expected policy verdict

### `passing/main.tf`

- `deny`: 0
- `warn`: 0
- Notes: `tags_all` from `default_tags` covers the bucket; sub-resource (`aws_s3_bucket_versioning`) is skipped.

### `failing/main.tf`

- `deny`: 2 — `aws_s3_bucket.missing_tag`, `aws_dynamodb_table.empty_value`
- `warn`: 3 — `aws_kms_key.bad_kind`, `aws_kms_key.missing_colon`, `aws_kms_key.underscore_name`
- Skipped: `aws_s3_bucket_policy.ignored_subresource`
- Clean: `aws_kms_key.good`

Expected output shape:

```json
{
  "deny": [
    "aws_s3_bucket.missing_tag is missing required tag 'my:test:policy-testing'",
    "..."
  ],
  "warn": [
    "aws_kms_key.bad_kind tag 'my:test:policy-testing' value \"Widget:Test\" does not match ..."
  ]
}
```
