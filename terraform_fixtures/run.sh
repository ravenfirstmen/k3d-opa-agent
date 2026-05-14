#!/bin/bash

TERRAFORM="tofu"

$TERRAFORM -chdir=./failing init
$TERRAFORM -chdir=./failing plan -out=plan.tfplan

# Tests use mk_input which wraps as {"terraform": {"resource_changes": ...}} — that's the Spacelift envelope. Raw terraform show -json has resource_changes at the top level.
$TERRAFORM -chdir=./failing show -json plan.tfplan | jq '{terraform: .}' > plan_failing.json

# data.rego_spacelift is to match rego package name
opa eval \
    --data ../rego_spacelift/require-catalog-ref-tag.rego \
    --input plan_failing.json \
    --format pretty \
    'data.rego_spacelift.deny' 
echo "Exiting with: $?"

# passing
$TERRAFORM -chdir=./passing init
$TERRAFORM -chdir=./passing plan -out=plan.tfplan
$TERRAFORM -chdir=./passing show -json plan.tfplan > plan_passing.json

# data.rego_spacelift is to match rego package name
opa eval \
    --data ../rego_spacelift/require-catalog-ref-tag.rego \
    --input plan_passing.json \
    --format pretty \
    'data.rego_spacelift.deny' 
echo "Exiting with: $?"
