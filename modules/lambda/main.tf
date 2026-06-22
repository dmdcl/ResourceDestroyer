locals {
  # Rendered policy file with the actual role ARN and role name substituted
  rendered_policy = replace(
    replace(
      file(var.policy_file_path),
      "$${CUSTODIAN_ROLE_ARN}",
      var.custodian_role_arn
    ),
    "$${CUSTODIAN_ROLE_NAME}",
    var.custodian_role_name
  )

  rendered_policy_path = "${path.module}/rendered_policy.yml"
}

resource "local_file" "rendered_policy" {
  content  = local.rendered_policy
  filename = local.rendered_policy_path
}

# Deploy all Cloud Custodian policies as Lambda functions.
# Requires `custodian` CLI installed in the execution environment.
resource "null_resource" "custodian_deploy" {
  triggers = {
    policy_sha = sha256(local.rendered_policy)
    role_arn   = var.custodian_role_arn
    region     = var.aws_region
  }

  depends_on = [local_file.rendered_policy]

  provisioner "local-exec" {
    command = <<-EOT
      ${var.custodian_bin} run \
        --output-dir /tmp/custodian-output \
        --region ${var.aws_region} \
        ${local.rendered_policy_path}
    EOT
  }
}
