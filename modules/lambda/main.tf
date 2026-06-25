locals {
  # Discover all *.yml files in policies/resources/
  policy_files = fileset(var.policy_dir, "*.yml")

  # Render each policy file: substitute all tokens
  rendered_policies = {
    for f in local.policy_files : f => replace(
      replace(
        replace(
          replace(
            replace(
              replace(
                file("${var.policy_dir}/${f}"),
                "$${MARK_ROLE_ARN}",
                var.mark_role_arn
              ),
              "$${CLEANUP_ROLE_ARN}",
              var.cleanup_role_arn
            ),
            "$${SNS_TOPIC_ARN}",
            var.sns_topic_arn
          ),
          "$${ALERT_EMAIL}",
          var.alert_email
        ),
        "$${SQS_QUEUE_URL}",
        var.sqs_queue_url
      ),
      "$${MAILER_ROLE_ARN}",
      var.mailer_role_arn
    )
  }

  rendered_dir = "${path.module}/rendered_policies"

  # Extract policy names from rendered YAML content (lines matching "  - name: ")
  # Used by the GC step to know which Lambdas are EXPECTED after this deploy.
  expected_lambda_names = flatten([
    for content in values(local.rendered_policies) : [
      for line in split("\n", content) :
      "custodian-${trimspace(replace(line, "- name:", ""))}"
      if can(regex("^  - name:", line))
    ]
  ])

  rendered_mailer = replace(
    replace(
      replace(
        replace(
          file(var.mailer_template_path),
          "$${SQS_QUEUE_URL}",
          var.sqs_queue_url
        ),
        "$${MAILER_ROLE_ARN}",
        var.mailer_role_arn
      ),
      "$${AWS_REGION}",
      var.aws_region
    ),
    "$${SENDER_EMAIL}",
    var.sender_email
  )

  rendered_mailer_path = "${path.module}/rendered_mailer.yml"
}

# Write each rendered policy to rendered_policies/<filename>
resource "local_file" "rendered_policies" {
  for_each = local.rendered_policies

  content  = each.value
  filename = "${local.rendered_dir}/${each.key}"
}

resource "local_file" "rendered_mailer" {
  content  = local.rendered_mailer
  filename = local.rendered_mailer_path
}

# ── Garbage-collect stale custodian Lambdas + EventBridge rules ───────────────
# Runs before custodian_deploy on every apply.
# Deletes any custodian-* Lambda/rule NOT present in the current policy set.
resource "null_resource" "custodian_gc" {
  triggers = {
    # Re-runs whenever the expected set of Lambda names changes
    expected_names_sha = sha256(join(",", sort(local.expected_lambda_names)))
    region             = var.aws_region
  }

  depends_on = [local_file.rendered_policies]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      REGION="${var.aws_region}"
      EXPECTED="${join(",", sort(local.expected_lambda_names))}"

      echo "==> [GC] Scanning for stale custodian-* resources in $REGION..."

      # ── Delete stale EventBridge rules ──
      RULES=$(aws events list-rules \
        --region "$REGION" \
        --query 'Rules[?starts_with(Name, `custodian-`)].Name' \
        --output json | python3 -c "import json,sys; [print(x) for x in json.load(sys.stdin)]" 2>/dev/null || true)

      while IFS= read -r rule; do
        [[ -z "$rule" ]] && continue
        # Strip "custodian-" prefix to get policy name, check if expected
        if echo ",$EXPECTED," | grep -q ",$rule,"; then
          echo "  [GC] Keep rule: $rule"
        else
          echo "  [GC] Remove rule: $rule"
          TARGET_IDS=$(aws events list-targets-by-rule \
            --rule "$rule" --region "$REGION" \
            --output json | python3 -c "import json,sys; [print(x['Id']) for x in json.load(sys.stdin)['Targets']]" | tr '\n' ' ' || true)
          [[ -n "$TARGET_IDS" ]] && aws events remove-targets \
            --rule "$rule" --region "$REGION" --ids $TARGET_IDS
          aws events delete-rule --name "$rule" --region "$REGION"
        fi
      done <<< "$RULES"

      # ── Delete stale Lambda functions ──
      LAMBDAS=$(aws lambda list-functions \
        --region "$REGION" \
        --query 'Functions[?starts_with(FunctionName, `custodian-`)].FunctionName' \
        --output json | python3 -c "import json,sys; [print(x) for x in json.load(sys.stdin)]" 2>/dev/null || true)

      while IFS= read -r fn; do
        [[ -z "$fn" ]] && continue
        if echo ",$EXPECTED," | grep -q ",$fn,"; then
          echo "  [GC] Keep Lambda: $fn"
        else
          echo "  [GC] Delete Lambda: $fn"
          aws lambda delete-function --function-name "$fn" --region "$REGION"
        fi
      done <<< "$LAMBDAS"

      echo "==> [GC] Done."
    EOT
  }
}

# ── Deploy all rendered policies ──────────────────────────────────────────────
resource "null_resource" "custodian_deploy" {
  triggers = {
    policies_sha     = sha256(join("", [for f, c in local.rendered_policies : c]))
    mark_role_arn    = var.mark_role_arn
    cleanup_role_arn = var.cleanup_role_arn
    region           = var.aws_region
  }

  depends_on = [
    local_file.rendered_policies,
    null_resource.custodian_gc,
  ]

  provisioner "local-exec" {
    command = <<-EOT
      sleep 15
      for policy in ${local.rendered_dir}/*.yml; do
        ${var.custodian_bin} run \
          --output-dir /tmp/custodian-output \
          --region ${var.aws_region} \
          "$policy"
      done
    EOT
  }
}

# ── Deploy / update the c7n-mailer Lambda ─────────────────────────────────────
# Runs after all custodian policies are deployed.
resource "null_resource" "mailer_deploy" {
  triggers = {
    mailer_sha      = sha256(local.rendered_mailer)
    mailer_role_arn = var.mailer_role_arn
    region          = var.aws_region
  }

  depends_on = [
    local_file.rendered_mailer,
    null_resource.custodian_deploy,
  ]

  provisioner "local-exec" {
    command = <<-EOT
      c7n-mailer \
        --config ${local.rendered_mailer_path} \
        --update-lambda
    EOT
  }
}
