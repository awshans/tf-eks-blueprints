provider "kubernetes" {
  host                   = module.eks_blueprints.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks_blueprints.eks_cluster_id]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks_blueprints.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", module.eks_blueprints.eks_cluster_id]
    }
  }
}

provider "kubectl" {
  apply_retry_count      = 10
  host                   = module.eks_blueprints.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks_blueprints.eks_cluster_id]
  }
}

module "eks_blueprints" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints?ref=v4.0.7"

  cluster_name    = var.name

  # EKS Cluster VPC and Subnet mandatory config
  vpc_id             = var.vpc_id
  private_subnet_ids = var.private_subnet_ids

  # EKS CONTROL PLANE VARIABLES
  cluster_version = var.cluster_version

  # EKS MANAGED NODE GROUPS
  managed_node_groups = {
    mg_5 = {
      node_group_name = "managed-ondemand"
      instance_types  = ["m5.xlarge"]
      
      subnet_ids      = var.private_subnet_ids
    }
  }
  
  #platform_teams = {
  #  admin = {
  #    users = [
        #data.aws_caller_identity.current.arn
  #      var.users
  #    ]
  #  }
  #}

  tags = merge(
    var.tags,
  )
}

module "aws_controllers" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints?ref=v4.0.7/modules/kubernetes-addons"

  eks_cluster_id = module.eks_blueprints.eks_cluster_id

  #---------------------------------------------------------------
  # Use AWS controllers separately
  # So that it can delete ressources it created from other addons or workloads
  #---------------------------------------------------------------

  enable_aws_load_balancer_controller = true
  enable_karpenter                    = true
  enable_aws_for_fluentbit            = false

  depends_on = [module.eks_blueprints.managed_node_groups]
}


# Add the following to the bottom of main.tf

module "kubernetes-addons" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints?ref=v4.0.7/modules/kubernetes-addons"

  eks_cluster_id = module.eks_blueprints.eks_cluster_id

  #---------------------------------------------------------------
  # ARGO CD ADD-ON
  #---------------------------------------------------------------


  enable_argocd         = true
  argocd_manage_add_ons = true # Indicates that ArgoCD is responsible for managing/deploying Add-ons.
  
  argocd_applications = {
    workloads = {
      path                = "env/dev"
      repo_url            = "https://github.com/awshans/app1.git"
      ssh_key_secret_name = "github-ssh-key"  # Needed for private repos
      add_on_application  = true              # Indicates the root add-on application.
      values              = {}
    }
    addons = {
      path                = "chart"
      repo_url            = "https://github.com/aws-samples/eks-blueprints-add-ons.git"
      add_on_application  = true              # Indicates the root add-on application.
      values              = {}
    }
  }

  argocd_helm_config = {
    values = [templatefile("${path.module}/argocd-values.yaml", {})]
  }
  #---------------------------------------------------------------
  # ADD-ONS - You can add additional addons here
  # https://aws-ia.github.io/terraform-aws-eks-blueprints/add-ons/
  #---------------------------------------------------------------

  enable_aws_for_fluentbit            = false
  enable_cert_manager                 = false
  enable_cluster_autoscaler           = false
  enable_ingress_nginx                = false
  enable_keda                         = false
  enable_metrics_server               = false
  enable_prometheus                   = false
  enable_traefik                      = false
  enable_vpa                          = false
  enable_yunikorn                     = false
  enable_argo_rollouts                = false

  depends_on = [module.eks_blueprints.managed_node_groups,module.aws_controllers]
}