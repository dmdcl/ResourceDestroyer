# Notification Infrastructure
resource "aws_sns_topic" "custodian_alerts" {
  name = "${var.project}-${var.environment}-custodian-alerts"
}

resource "aws_sqs_queue" "custodian_mailer" {
  name = "${var.project}-${var.environment}-custodian-mailer"
}

# Link SNS to SQS
resource "aws_sns_topic_subscription" "custodian_sqs_target" {
  topic_arn = aws_sns_topic.custodian_alerts.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.custodian_mailer.arn
}

# Allow SNS to write to the SQS queue
resource "aws_sqs_queue_policy" "custodian_mailer_policy" {
  queue_url = aws_sqs_queue.custodian_mailer.id
  policy    = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.custodian_mailer.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.custodian_alerts.arn
          }
        }
      }
    ]
  })
}