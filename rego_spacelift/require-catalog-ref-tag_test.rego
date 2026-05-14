package rego_spacelift_test

import data.rego_spacelift
import rego.v1

# --- helpers ------------------------------------------------------------------
mk_change(type, tags, actions) := {
	"address": sprintf("%s.x", [type]),
	"type": type,
	"change": {
		"actions": actions,
		"after": {"tags": tags, "tags_all": tags},
	},
}

mk_input(changes) := {"terraform": {"resource_changes": changes}}

# --- deny: missing / empty ----------------------------------------------------
test_deny_when_tag_missing if {
	rc := mk_change("aws_s3_bucket", {}, ["create"])
	count(rego_spacelift.deny) == 1 with input as mk_input([rc])
}

test_deny_when_tag_empty if {
	rc := mk_change("aws_s3_bucket", {"my:test:policy-testing": ""}, ["create"])
	count(rego_spacelift.deny) == 1 with input as mk_input([rc])
}

# --- pass: valid values -------------------------------------------------------
test_pass_component_simple if {
	rc := mk_change("aws_s3_bucket", {"my:test:policy-testing": "component:test"}, ["create"])
	count(rego_spacelift.deny) == 0 with input as mk_input([rc])
	count(rego_spacelift.warn) == 0 with input as mk_input([rc])
}

test_pass_system_simple if {
	rc := mk_change("aws_dynamodb_table", {"my:test:policy-testing": "system:test"}, ["update"])
	count(rego_spacelift.deny) == 0 with input as mk_input([rc])
	count(rego_spacelift.warn) == 0 with input as mk_input([rc])
}

test_pass_with_namespace if {
	rc := mk_change("aws_kms_key", {"my:test:policy-testing": "component:platform/auth-service"}, ["create"])
	count(rego_spacelift.deny) == 0 with input as mk_input([rc])
	count(rego_spacelift.warn) == 0 with input as mk_input([rc])
}

# --- warn: malformed values ---------------------------------------------------
test_warn_uppercase if {
	rc := mk_change("aws_s3_bucket", {"my:test:policy-testing": "Component:Test"}, ["create"])
	count(rego_spacelift.warn) == 1 with input as mk_input([rc])
	count(rego_spacelift.deny) == 0 with input as mk_input([rc])
}

test_warn_underscore_in_name if {
	rc := mk_change("aws_s3_bucket", {"my:test:policy-testing": "component:test_svc"}, ["create"])
	count(rego_spacelift.warn) == 1 with input as mk_input([rc])
}

test_warn_disallowed_kind if {
	rc := mk_change("aws_s3_bucket", {"my:test:policy-testing": "widget:test"}, ["create"])
	count(rego_spacelift.warn) == 1 with input as mk_input([rc])
}

test_warn_empty_name_part if {
	rc := mk_change("aws_s3_bucket", {"my:test:policy-testing": "component:"}, ["create"])
	count(rego_spacelift.warn) == 1 with input as mk_input([rc])
}

test_warn_too_many_slashes if {
	rc := mk_change("aws_s3_bucket", {"my:test:policy-testing": "component:a/b/c"}, ["create"])
	count(rego_spacelift.warn) == 1 with input as mk_input([rc])
}

test_warn_missing_colon if {
	rc := mk_change("aws_s3_bucket", {"my:test:policy-testing": "componenttest"}, ["create"])
	count(rego_spacelift.warn) == 1 with input as mk_input([rc])
}

# --- skip: deletions, no-ops, non-taggable, non-aws ---------------------------
test_skip_destroy if {
	rc := mk_change("aws_s3_bucket", {}, ["delete"])
	count(rego_spacelift.deny) == 0 with input as mk_input([rc])
}

test_skip_noop if {
	rc := mk_change("aws_s3_bucket", {}, ["no-op"])
	count(rego_spacelift.deny) == 0 with input as mk_input([rc])
}

test_skip_non_taggable_type if {
	rc := mk_change("aws_iam_role_policy_attachment", {}, ["create"])
	count(rego_spacelift.deny) == 0 with input as mk_input([rc])
}

test_skip_non_aws_resource if {
	rc := mk_change("random_pet", {}, ["create"])
	count(rego_spacelift.deny) == 0 with input as mk_input([rc])
}

# --- tags_all fallback (provider default_tags) --------------------------------
test_pass_via_tags_all_only if {
	rc := {
		"address": "aws_s3_bucket.x",
		"type": "aws_s3_bucket",
		"change": {
			"actions": ["create"],
			"after": {
				"tags": {},
				"tags_all": {"my:test:policy-testing": "component:test"},
			},
		},
	}
	count(rego_spacelift.deny) == 0 with input as mk_input([rc])
	count(rego_spacelift.warn) == 0 with input as mk_input([rc])
}

# --- multiple resources -------------------------------------------------------
test_mixed_batch if {
	ok := mk_change("aws_s3_bucket", {"my:test:policy-testing": "component:test"}, ["create"])
	bad := mk_change("aws_dynamodb_table", {}, ["create"])
	ugly := mk_change("aws_kms_key", {"my:test:policy-testing": "BAD"}, ["create"])
	inp := mk_input([ok, bad, ugly])
	count(rego_spacelift.deny) == 1 with input as inp
	count(rego_spacelift.warn) == 1 with input as inp
}
