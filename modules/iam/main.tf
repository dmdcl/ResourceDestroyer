resource "aws_iam_role" "custodian_execution" {
  name        = "${var.project}-${var.environment}-custodian-lambda-role"
  description = "Execution role for Cloud Custodian Lambda functions managing inventory lifecycle."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.custodian_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "custodian_inventory" {
  name = "${var.project}-${var.environment}-custodian-inventory-policy"
  role = aws_iam_role.custodian_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2ReadTagTerminate"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "ec2:CreateTags",
          "ec2:TerminateInstances"
        ]
        Resource = "*"
      },
      {
        Sid    = "RDSReadTagDelete"
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:ListTagsForResource",
          "rds:AddTagsToResource",
          "rds:DeleteDBInstance"
        ]
        Resource = "*"
      },
      {
        Sid    = "VPCReadTag"
        Effect = "Allow"
        Action = [
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeRouteTables",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeNetworkInterfaces",
          "ec2:CreateTags",
          "ec2:DeleteVpc",
          "ec2:DeleteSubnet",
          "ec2:DetachInternetGateway",
          "ec2:DeleteInternetGateway",
          "ec2:DeleteRouteTable",
          "ec2:DeleteSecurityGroup"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3ReadTagDelete"
        Effect = "Allow"
        Action = [
          "s3:ListAllMyBuckets",
          "s3:GetBucketTagging",
          "s3:PutBucketTagging",
          "s3:GetBucketLocation",
          "s3:ListBucket",
          "s3:DeleteObject",
          "s3:DeleteObjectVersion",
          "s3:DeleteBucket"
        ]
        Resource = "*"
      },
      {
        Sid    = "IAMReadTagDelete"
        Effect = "Allow"
        Action = [
          "iam:ListRoles",
          "iam:GetRole",
          "iam:ListRoleTags",
          "iam:TagRole",
          "iam:ListAttachedRolePolicies",
          "iam:ListRolePolicies",
          "iam:DetachRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:DeleteRole",
          "iam:ListAccountAliases"
        ]
        # Explicitly deny self-deletion: custodian cannot delete its own role
        NotResource = "arn:aws:iam::*:role/${var.project}-${var.environment}-custodian-lambda-role"
      },
      {
        Sid    = "CloudWatchEvents"
        Effect = "Allow"
        Action = [
          "events:PutRule",
          "events:PutTargets",
          "events:DescribeRule",
          "lambda:AddPermission"
        ]
        Resource = "*"
      },
      {
        Sid    = "MessagingAndMailer"
        Effect = "Allow"
        Action = [
          "sns:Publish",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "ses:SendEmail",
          "ses:SendRawEmail",
          "sqs:sendmessage"
        ]
        Resource = "*"
      }
    ]
  })
}