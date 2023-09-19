locals {
  aws_region        = "eu-west-1"
  bucket            = ""
  account_id        = "${get_env("ACCOUNT_ID")}"
  cidr              = "10..0.0/16"
  azs               = ["eu-west-1a", "eu-west-1b"]
  private_subnets   = ["10.0.0.0/20", "10.128.0.0/20"]
  public_subnets    = ["10.0.16.0/20", "10.0.144.0/20"]
}

inputs = {
  name = local.env_vars.locals.cluster_name
  cidr = local.env_vars.locals.cidr

  azs             = local.env_vars.locals.azs
  private_subnets = local.env_vars.locals.private_subnets
  public_subnets  = local.env_vars.locals.public_subnets

  enable_nat_gateway = true

  tags = {
    Terraform   = "true"
    Environment = "pdf"
  }
}