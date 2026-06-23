locals {
  rendered_policy = replace(
    replace(
      replace(
        replace(
          replace(
            file(var.policy_file_path),
            "$${CUSTODIAN_ROLE_ARN}",
            var.custodian_role_arn
          ),
          "$${CUSTODIAN_ROLE_NAME}",
          var.custodian_role_name
        ),
        "$${SNS_TOPIC_ARN}",
        var.sns_topic_arn
      ),
      "$${ALERT_EMAIL}",
      var.alert_email
    ),
    "$${SQS_QUEUE_URL}",
    var.sqs_queue_url
  )

  rendered_policy_path = "${path.module}/rendered_policy.yml"
# Rendered mailer file with SQS URL, Role ARN, Region, and Sender Email substituted
  rendered_mailer = replace(
    replace(
      replace(
        replace(
          file(var.mailer_template_path),
          "$${SQS_QUEUE_URL}",
          var.sqs_queue_url
        ),
        "$${CUSTODIAN_ROLE_ARN}",
        var.custodian_role_arn
      ),
      "$${AWS_REGION}",
      var.aws_region
    ),
    "$${SENDER_EMAIL}",
    var.sender_email
  )

  rendered_mailer_path = "${path.module}/rendered_mailer.yml"
}

resource "local_file" "rendered_policy" {
  content  = local.rendered_policy
  filename = local.rendered_policy_path
}

resource "local_file" "rendered_mailer" {
  content  = local.rendered_mailer
  filename = local.rendered_mailer_path
}

# (Keep your existing null_resource "custodian_deploy" block here)

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
    sleep 15
      ${var.custodian_bin} run \
        --output-dir /tmp/custodian-output \
        --region ${var.aws_region} \
        ${local.rendered_policy_path}
    EOT
  }
}
