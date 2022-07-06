variable "vpc_id" {
  description = "The CIDR block for the VPC. Default value is a valid CIDR, but not acceptable by AWS and should be overridden"
  type        = string
}

variable "private_subnet_ids" {
  description = "private subnets"
  default     = {}
}

variable "cluster_version" {
  description = "The CIDR block for the VPC. Default value is a valid CIDR, but not acceptable by AWS and should be overridden"
  type        = string
}

variable "name" {
  description = "The CIDR block for the VPC. Default value is a valid CIDR, but not acceptable by AWS and should be overridden"
  type        = string
}

variable "tags" {
  description = "tags"
  #type        = list
  default     = {}
}


variable "users" {
  description = "users"
  #type        = list
}
 
