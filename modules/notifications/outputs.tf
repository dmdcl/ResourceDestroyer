output "sns_topic_arn" {
  value = aws_sns_topic.custodian_alerts.arn
}

output "sqs_queue_url" {
  description = "URL of the SQS queue used by the custodian mailer."
  value       = aws_sqs_queue.custodian_mailer.url
}