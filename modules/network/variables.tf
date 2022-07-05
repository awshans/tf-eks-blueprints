variable "name" {
  type        = string
  description = "The name of the resources"
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC. Default value is a valid CIDR, but not acceptable by AWS and should be overridden"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "AZs"
  type        = list
}

variable "tags" {
  description = "tags"
  #type        = list
  default     = {}
}

variable "region" {
  type        = string
  description = "The name of the region you wish to deploy into"
  default     = "us-west-2"
}