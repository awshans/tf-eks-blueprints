locals {

  name            = basename(path.cwd)
  region          = data.aws_region.current.name
  cluster_version = "1.21"
  service_name    = "app1"
  owner           = "team1"
  backup          = "true"

  vpc_cidr      = "10.0.0.0/16"
  azs           = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Application = local.service_name
    Backup = local.backup
    owner   = local.owner
  }
  
}
