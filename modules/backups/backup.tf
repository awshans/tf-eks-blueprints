provider "aws" {
  region = "us-west-2"
  alias  = "replica"
}


resource "aws_kms_key" "default" {
  description = "Encryption key for automated backups"
  provider = "aws.replica"
}

resource "aws_backup_vault" "example" {
  name        = "example_backup_vault"
  kms_key_arn = aws_kms_key.default.arn
}

resource "aws_iam_role" "example" {
  name               = "example"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": ["sts:AssumeRole"],
      "Effect": "allow",
      "Principal": {
        "Service": ["backup.amazonaws.com"]
      }
    }
  ]
}
POLICY
}



resource "aws_iam_role_policy_attachment" "example" {
  #policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  policy_arn = aws_iam_policy.policy.arn
  role       = aws_iam_role.example.name
}

resource "aws_backup_plan" "example" {
  name = "tf_example_backup_plan"

  rule {
    rule_name         = "tf_example_backup_rule"
    target_vault_name = "${aws_backup_vault.example.name}"
    schedule          = "cron(0 * ? * * *)"
  }
  
}

resource "aws_backup_selection" "example" {
  iam_role_arn = aws_iam_role.example.arn
  name         = "tf_example_backup_selection"
  plan_id      = aws_backup_plan.example.id
  resources    = ["*"]

  condition {
    string_like {
      key   = "aws:ResourceTag/Application"
      value = "app*"
    }
    string_not_equals {
      key   = "aws:ResourceTag/Backup"
      value = "false"
    }
    string_not_like {
      key   = "aws:ResourceTag/Environment"
      value = "test*"
    }
  }


}

resource "aws_iam_policy" "policy" {
  name        = "test-policy"
  description = "A test policy"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "rds:AddTagsToResource",
                "rds:ListTagsForResource",
                "rds:DescribeDBSnapshots",
                "rds:CreateDBSnapshot",
                "rds:CopyDBSnapshot",
                "rds:DescribeDBInstances",
                "rds:CreateDBClusterSnapshot",
                "rds:DescribeDBClusters",
                "rds:DescribeDBClusterSnapshots",
                "rds:CopyDBClusterSnapshot",
                "rds:CreateDBClusterSnapshot"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "rds:ModifyDBInstance"
            ],
            "Resource": [
                "arn:aws:rds:*:*:db:*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "rds:DeleteDBSnapshot",
                "rds:ModifyDBSnapshotAttribute"
            ],
            "Resource": [
                "arn:aws:rds:*:*:snapshot:awsbackup:*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "rds:DeleteDBClusterSnapshot",
                "rds:ModifyDBClusterSnapshotAttribute"
            ],
            "Resource": [
                "arn:aws:rds:*:*:cluster-snapshot:awsbackup:*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "storagegateway:CreateSnapshot",
                "storagegateway:ListTagsForResource"
            ],
            "Resource": "arn:aws:storagegateway:*:*:gateway/*/volume/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CopySnapshot"
            ],
            "Resource": "arn:aws:ec2:*::snapshot/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CopyImage"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateTags",
                "ec2:DeleteSnapshot"
            ],
            "Resource": "arn:aws:ec2:*::snapshot/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateImage",
                "ec2:DeregisterImage"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateTags"
            ],
            "Resource": "arn:aws:ec2:*:*:image/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeSnapshots",
                "ec2:DescribeTags",
                "ec2:DescribeImages",
                "ec2:DescribeInstances",
                "ec2:DescribeInstanceAttribute",
                "ec2:DescribeInstanceCreditSpecifications",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DescribeElasticGpus",
                "ec2:DescribeSpotInstanceRequests"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:ModifySnapshotAttribute",
                "ec2:ModifyImageAttribute"
            ],
            "Resource": "*",
            "Condition": {
                "Null": {
                    "aws:ResourceTag/aws:backup:source-resource": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "backup:DescribeBackupVault",
                "backup:CopyIntoBackupVault"
            ],
            "Resource": "arn:aws:backup:*:*:backup-vault:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "backup:CopyFromBackupVault"
            ],
            "Resource": "*"
        },
        {
            "Action": [
                "elasticfilesystem:Backup",
                "elasticfilesystem:DescribeTags"
            ],
            "Resource": "arn:aws:elasticfilesystem:*:*:file-system/*",
            "Effect": "Allow"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateSnapshot",
                "ec2:DeleteSnapshot",
                "ec2:DescribeVolumes",
                "ec2:DescribeSnapshots"
            ],
            "Resource": [
                "arn:aws:ec2:*::snapshot/*",
                "arn:aws:ec2:*:*:volume/*"
            ]
        },
        {
            "Action": [
                "kms:Decrypt",
                "kms:GenerateDataKey"
            ],
            "Effect": "Allow",
            "Resource": "*",
            "Condition": {
                "StringLike": {
                    "kms:ViaService": [
                        "dynamodb.*.amazonaws.com"
                    ]
                }
            }
        },
        {
            "Action": "kms:DescribeKey",
            "Effect": "Allow",
            "Resource": "*"
        },
        {
            "Action": "kms:CreateGrant",
            "Effect": "Allow",
            "Resource": "*",
            "Condition": {
                "Bool": {
                    "kms:GrantIsForAWSResource": "true"
                }
            }
        },
        {
            "Action": [
                "kms:GenerateDataKeyWithoutPlaintext"
            ],
            "Effect": "Allow",
            "Resource": "arn:aws:kms:*:*:key/*",
            "Condition": {
                "StringLike": {
                    "kms:ViaService": [
                        "ec2.*.amazonaws.com"
                    ]
                }
            }
        },
        {
            "Action": [
                "tag:GetResources"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ssm:CancelCommand",
                "ssm:GetCommandInvocation"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "ssm:SendCommand",
            "Resource": [
                "arn:aws:ssm:*:*:document/AWSEC2-CreateVssSnapshot",
                "arn:aws:ec2:*:*:instance/*"
            ]
        }

    ]
}
EOF
}