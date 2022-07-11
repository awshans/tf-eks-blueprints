provider "aws" {
  alias  = "primary"
  region = var.region
}

resource "aws_db_subnet_group" "private_p" {
  name       = "main"
  subnet_ids = var.private_subnet_ids

  tags = merge(
    var.tags,
  )
}

data "aws_rds_engine_version" "family" {
  engine   = var.engine
  version  = var.engine == "aurora-postgresql" ? var.engine_version_pg : var.engine_version_mysql
  provider = aws.primary
}

data "aws_iam_policy_document" "monitoring_rds_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

data "aws_partition" "current" {}

###########
# KMS
###########

resource "aws_kms_key" "kms_p" {
  provider    = aws.primary
  count       = var.storage_encrypted ? 1 : 0
  description = "KMS key for Aurora Storage Encryption"
  tags        = var.tags
  # following causes terraform destroy to fail. But this is needed so that Aurora encrypted snapshots can be restored for your production workload.
  lifecycle {
    prevent_destroy = true
  }
}


#########################
# Create Unique password
#########################

resource "random_password" "master_password" {
  length  = 10
  special = false
}

####################################
# Generate Final snapshot identifier
####################################

resource "random_id" "snapshot_id" {
  
  keepers = {
    id = var.name
  }

  byte_length = 4
}

###########
# IAM
###########

resource "aws_iam_role" "rds_enhanced_monitoring" {
  description         = "IAM Role for RDS Enhanced monitoring"
  path                = "/"
  assume_role_policy  = data.aws_iam_policy_document.monitoring_rds_assume_role.json
  managed_policy_arns = ["arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"]
  tags                = var.tags
}

#############################
# RDS Aurora Parameter Groups
##############################

resource "aws_rds_cluster_parameter_group" "aurora_cluster_parameter_group_p" {
  provider    = aws.primary
  name_prefix = "${var.name}-cluster-"
  family      = data.aws_rds_engine_version.family.parameter_group_family
  description = "aurora-cluster-parameter-group"

  dynamic "parameter" {
    for_each = var.engine == "aurora-postgresql" ? local.apg_cluster_pgroup_params : local.mysql_cluster_pgroup_params
    iterator = pblock

    content {
      name  	   = pblock.value.name
      value 	   = pblock.value.value
      apply_method = pblock.value.apply_method
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_parameter_group" "aurora_db_parameter_group_p" {
  provider    = aws.primary
  name_prefix = "${var.name}-db-"
  family      = data.aws_rds_engine_version.family.parameter_group_family
  description = "aurora-db-parameter-group"

  dynamic "parameter" {
    for_each = var.engine == "aurora-postgresql" ? local.apg_db_pgroup_params : local.mysql_db_pgroup_params
    iterator = pblock

    content {
      name         = pblock.value.name
      value        = pblock.value.value
      apply_method = pblock.value.apply_method
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}


# Aurora Global DB 
resource "aws_rds_global_cluster" "globaldb" {
  count                     = var.setup_globaldb ? 1 : 0
  provider                  = aws.primary
  global_cluster_identifier = "${var.name}-globaldb"
  engine                    = var.engine
  engine_version            = var.engine == "aurora-postgresql" ? var.engine_version_pg : var.engine_version_mysql
  storage_encrypted         = var.storage_encrypted
}


resource "aws_rds_cluster" "primary" {
  provider                         = aws.primary
  global_cluster_identifier        = var.setup_globaldb ? aws_rds_global_cluster.globaldb[0].id : null
  cluster_identifier               = "${var.name}-${var.region}"
  engine                           = var.engine
  engine_version                   = var.engine == "aurora-postgresql" ? var.engine_version_pg : var.engine_version_mysql
  allow_major_version_upgrade      = var.allow_major_version_upgrade
  availability_zones               = var.azs
  db_subnet_group_name             = aws_db_subnet_group.private_p.name
  port                             = var.port == "" ? var.engine == "aurora-postgresql" ? "5432" : "3306" : var.port
  database_name                    = var.setup_as_secondary || (var.snapshot_identifier != "") ? null : var.database_name
  master_username                  = var.setup_as_secondary || (var.snapshot_identifier != "") ? null : var.username
  master_password                  = var.setup_as_secondary || (var.snapshot_identifier != "") ? null : (var.password == "" ? random_password.master_password.result : var.password)
  db_cluster_parameter_group_name  = aws_rds_cluster_parameter_group.aurora_cluster_parameter_group_p.id
  db_instance_parameter_group_name = var.allow_major_version_upgrade ? aws_db_parameter_group.aurora_db_parameter_group_p.id : null
  backup_retention_period          = var.backup_retention_period
  preferred_backup_window          = var.preferred_backup_window
  storage_encrypted                = var.storage_encrypted
  kms_key_id                       = var.storage_encrypted ? aws_kms_key.kms_p[0].arn : null
  apply_immediately                = true
  skip_final_snapshot              = var.skip_final_snapshot
  final_snapshot_identifier        = var.skip_final_snapshot ? null : "${var.final_snapshot_identifier_prefix}-${var.name}-${var.region}-${random_id.snapshot_id.hex}"
  snapshot_identifier              = var.snapshot_identifier != "" ? var.snapshot_identifier : null
  enabled_cloudwatch_logs_exports  = local.logs_set
  vpc_security_group_ids           = [var.database_security_group_id]
  tags                             = merge(
    var.tags,
  )
  depends_on                       = [
    # When this Aurora cluster is setup as a secondary, setting up the dependency makes sure to delete this cluster 1st before deleting current primary Cluster during terraform destroy
    # Comment out the following line if this cluster has changed role to be the primary Aurora cluster because of a failover for terraform destroy to work
    #aws_rds_cluster_instance.secondary,
  ]
  lifecycle {
    ignore_changes = [
      replication_source_identifier,
    ]
  }
}

resource "aws_rds_cluster_instance" "primary" {
  count                        = var.primary_instance_count
  provider                     = aws.primary
  identifier                   = "${var.name}-${var.region}-${count.index + 1}"
  cluster_identifier           = aws_rds_cluster.primary.id
  engine                       = aws_rds_cluster.primary.engine
  engine_version               = var.engine == "aurora-postgresql" ? var.engine_version_pg : var.engine_version_mysql
  auto_minor_version_upgrade   = var.setup_globaldb ? false : var.auto_minor_version_upgrade
  instance_class               = var.instance_class
  db_subnet_group_name         = aws_db_subnet_group.private_p.name
  db_parameter_group_name      = aws_db_parameter_group.aurora_db_parameter_group_p.id
  performance_insights_enabled = true
  monitoring_interval          = var.monitoring_interval
  monitoring_role_arn          = aws_iam_role.rds_enhanced_monitoring.arn
  apply_immediately            = true
  tags                         = merge(
    var.tags,
  )
}

resource "aws_ssm_parameter" "database_cluster_endpoint" {
  name  = "database_cluster_endpoint"
  type  = "String"
  value = aws_rds_cluster.primary.endpoint
}

resource "aws_ssm_parameter" "database_cluster_reader_endpoint" {
  name  = "database_cluster_reader_endpoint"
  type  = "String"
  value = aws_rds_cluster.primary.reader_endpoint
}
