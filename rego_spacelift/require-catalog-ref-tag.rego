package rego_spacelift

import rego.v1

required_tag := "my:test:policy-testing"

# Allowed kinds for the catalog ref (Backstage-style). Extend as needed.
allowed_kinds := {"component", "system", "api", "resource", "domain"}

# Backstage entity name: lowercase letters, digits, hyphens; 1-63 chars.
# Accepts both `kind:name` and `kind:namespace/name`.
name_pattern := `^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$`

# --- DENY: missing or empty ---------------------------------------------------
# METADATA
# entrypoint: true
deny contains msg if {
	some rc in taggable_change
	not tag_value(rc)
	msg := sprintf("%s is missing required tag '%s'", [rc.address, required_tag])
}

deny contains msg if {
	some rc in taggable_change
	tag_value(rc) == ""
	msg := sprintf("%s has empty value for required tag '%s'", [rc.address, required_tag])
}

# --- WARN: malformed value ----------------------------------------------------
# METADATA
# entrypoint: true
warn contains msg if {
	some rc in taggable_change
	v := tag_value(rc)
	v != ""
	not valid_catalog_ref(v)
	msg := sprintf(
		"%s tag '%s' value %q does not match '<kind>:<name>' or '<kind>:<namespace>/<name>' (kinds: %v)",
		[rc.address, required_tag, v, allowed_kinds],
	)
}

# --- Helpers ------------------------------------------------------------------
valid_catalog_ref(v) if {
	parts := split(v, ":")
	count(parts) == 2
	allowed_kinds[parts[0]]
	valid_name_part(parts[1])
}

# name part is either `name` or `namespace/name`; both halves match name_pattern.
valid_name_part(s) if {
	not contains(s, "/")
	regex.match(name_pattern, s)
}

valid_name_part(s) if {
	contains(s, "/")
	segs := split(s, "/")
	count(segs) == 2
	regex.match(name_pattern, segs[0])
	regex.match(name_pattern, segs[1])
}

taggable_change contains rc if {
	some rc in input.terraform.resource_changes
	is_taggable(rc)
	not is_noop_or_destroy(rc)
}

# Prefer tags_all so provider default_tags counts.
tag_value(rc) := v if {
	v := rc.change.after.tags_all[required_tag]
} else := v if {
	v := rc.change.after.tags[required_tag]
}

is_taggable(rc) if {
	startswith(rc.type, "aws_")
	not non_taggable[rc.type]
}

is_noop_or_destroy(rc) if {
	rc.change.actions == ["delete"]
}

is_noop_or_destroy(rc) if {
	rc.change.actions == ["no-op"]
}

non_taggable := {
	"aws_iam_role_policy",
	"aws_iam_role_policy_attachment",
	"aws_iam_user_policy",
	"aws_iam_user_policy_attachment",
	"aws_iam_group_policy",
	"aws_iam_group_policy_attachment",
	"aws_iam_policy_attachment",
	"aws_s3_bucket_policy",
	"aws_s3_bucket_acl",
	"aws_s3_bucket_versioning",
	"aws_s3_bucket_public_access_block",
	"aws_s3_bucket_ownership_controls",
	"aws_route",
	"aws_route_table_association",
	"aws_main_route_table_association",
	"aws_security_group_rule",
	"aws_vpc_security_group_ingress_rule",
	"aws_vpc_security_group_egress_rule",
	"aws_lambda_permission",
	"aws_lambda_layer_version_permission",
	"aws_lb_listener_rule",
}
