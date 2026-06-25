# ---------------------------------------------------------------------------
# Role 1: Mark — read + tag only, no destructive actions
# ---------------------------------------------------------------------------
resource "aws_iam_role" "custodian_mark" {
  name        = "${var.project}-${var.environment}-custodian-mark-role"
  description = "Cloud Custodian mark-phase role: read and tag resources only."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "mark_basic" {
  role       = aws_iam_role.custodian_mark.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "custodian_mark" {
  name = "${var.project}-${var.environment}-custodian-mark-policy"
  role = aws_iam_role.custodian_mark.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2ReadTag"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "ec2:CreateTags",
          "ec2:DescribeVolumes",
          "ec2:DescribeSnapshots",
          "ec2:DescribeImages",
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeRouteTables",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeNatGateways",
          "ec2:DescribeAddresses"
        ]
        Resource = "*"
      },
      {
        Sid    = "RDSReadTag"
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:DescribeDBSnapshots",
          "rds:DescribeDBSubnetGroups",
          "rds:ListTagsForResource",
          "rds:AddTagsToResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3ReadTag"
        Effect = "Allow"
        Action = [
          "s3:ListAllMyBuckets",
          "s3:GetBucketTagging",
          "s3:PutBucketTagging",
          "s3:GetBucketLocation",
          "s3:ListBucket"
        ]
        Resource = "*"
      },
      {
        Sid    = "IAMReadTag"
        Effect = "Allow"
        Action = [
          "iam:ListRoles",
          "iam:GetRole",
          "iam:ListRoleTags",
          "iam:TagRole",
          "iam:ListAccountAliases"
        ]
        Resource = "*"
      },
      {
        Sid    = "ELBReadTag"
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTags",
          "elasticloadbalancing:AddTags"
        ]
        Resource = "*"
      },
      {
        Sid    = "ASGReadTag"
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeTags",
          "autoscaling:CreateOrUpdateTags"
        ]
        Resource = "*"
      },
      {
        Sid    = "EKSReadTag"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:ListTagsForResource",
          "eks:TagResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogsReadTag"
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:ListTagsLogGroup",
          "logs:TagLogGroup"
        ]
        Resource = "*"
      },
      {
        Sid    = "NotifyViaSQS"
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = var.sqs_queue_arn
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# Role 2: Cleanup — destructive actions only, explicit deny on state bucket
# ---------------------------------------------------------------------------
resource "aws_iam_role" "custodian_cleanup" {
  name        = "${var.project}-${var.environment}-custodian-cleanup-role"
  description = "Cloud Custodian cleanup-phase role: delete/terminate resources only."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cleanup_basic" {
  role       = aws_iam_role.custodian_cleanup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "custodian_cleanup" {
  name = "${var.project}-${var.environment}-custodian-cleanup-policy"
  role = aws_iam_role.custodian_cleanup.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2Describe"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "ec2:DescribeVolumes",
          "ec2:DescribeSnapshots",
          "ec2:DescribeImages",
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeRouteTables",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeNatGateways",
          "ec2:DescribeAddresses"
        ]
        Resource = "*"
      },
      {
        Sid    = "EC2Delete"
        Effect = "Allow"
        Action = [
          "ec2:TerminateInstances",
          "ec2:DeleteVolume",
          "ec2:DeleteSnapshot",
          "ec2:DeregisterImage",
          "ec2:DeleteVpc",
          "ec2:DeleteSubnet",
          "ec2:DetachInternetGateway",
          "ec2:DeleteInternetGateway",
          "ec2:DeleteRouteTable",
          "ec2:DeleteSecurityGroup",
          "ec2:DeleteNetworkInterface",
          "ec2:ReleaseAddress",
          "ec2:DeleteNatGateway"
        ]
        Resource = "*"
      },
      {
        Sid    = "RDSDescribe"
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:DescribeDBSnapshots",
          "rds:DescribeDBSubnetGroups",
          "rds:ListTagsForResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "RDSDelete"
        Effect = "Allow"
        Action = [
          "rds:DeleteDBInstance",
          "rds:DeleteDBSnapshot",
          "rds:DeleteDBSubnetGroup"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3Delete"
        Effect = "Allow"
        Action = [
          "s3:ListAllMyBuckets",
          "s3:GetBucketTagging",
          "s3:GetBucketLocation",
          "s3:ListBucket",
          "s3:ListBucketVersions",
          "s3:DeleteObject",
          "s3:DeleteObjectVersion",
          "s3:DeleteBucket"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3DenyStateBucket"
        Effect = "Deny"
        Action = ["s3:*"]
        Resource = [
          "arn:aws:s3:::${var.terraform_state_bucket}",
          "arn:aws:s3:::${var.terraform_state_bucket}/*"
        ]
      },
      {
        Sid    = "ELBDelete"
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTags",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:DeleteTargetGroup"
        ]
        Resource = "*"
      },
      {
        Sid    = "ASGDelete"
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeTags",
          "autoscaling:DeleteAutoScalingGroup"
        ]
        Resource = "*"
      },
      {
        Sid    = "EKSDelete"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:ListTagsForResource",
          "eks:DeleteCluster"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogsDelete"
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:ListTagsLogGroup",
          "logs:DeleteLogGroup"
        ]
        Resource = "*"
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# Role 3: Mailer — SQS consume + SES send only
# ---------------------------------------------------------------------------
resource "aws_iam_role" "custodian_mailer" {
  name        = "${var.project}-${var.environment}-custodian-mailer-role"
  description = "Cloud Custodian mailer role: consume SQS and send SES email only."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "mailer_basic" {
  role       = aws_iam_role.custodian_mailer.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "custodian_mailer" {
  name = "${var.project}-${var.environment}-custodian-mailer-policy"
  role = aws_iam_role.custodian_mailer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SQSConsume"
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = var.sqs_queue_arn
      },
      {
        Sid    = "SESSend"
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = "*"
      }
    ]
  })
}
