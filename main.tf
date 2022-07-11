
module "m_network" {
    source            = "./modules/network"
    name              = local.name
    region            = local.region
    vpc_cidr          = local.vpc_cidr
    azs               = local.azs
    tags              = local.tags
}


module "m_eks" {
    source            = "./modules/eks"
    name              = local.name
    cluster_version   = local.cluster_version
    vpc_id            = module.m_network.vpc_id
    private_subnet_ids   = module.m_network.private_subnets
    tags              = local.tags
    users             = data.aws_caller_identity.current.arn
}

module "m_backups" {
    source           = "./modules/backups"
    database_cluster_arn = module.m_database.database_cluster_arn
}

module "m_database" {
    source               = "./modules/database"
    name                 = local.name
    tags                 = local.tags   
    private_subnet_ids   = module.m_network.private_subnets
    vpc_id               = module.m_network.vpc_id
    azs                  = local.azs
    database_security_group_id = module.m_network.database_security_group_id
}

