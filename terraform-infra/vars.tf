variable "aws_region" {
  default = "eu-west-1"
}

variable "environment" {
  default = "rmzntst"
}

variable "vpc_cidr" {
  default     = "10.0.0.0/16"
  description = "CIDR block of the vpc"
}


variable "office_ip" {
  default     = "<Office IP>"
  description = "Office IP"
}

variable "public_subnets_cidr" {
  type        = list(any)
  default     = ["10.0.0.0/20", "10.0.128.0/20"]
  description = "CIDR block for Public Subnet"
}

variable "private_subnets_cidr" {
  type        = list(any)
  default     = ["10.0.16.0/20", "10.0.144.0/20"]
  description = "CIDR block for Private Subnet"
}


variable "bucket_name" {
  default     = "app_s3_files"
  description = "Bucket Name"
}


variable "app_bucket_acl_value" {
  default     = "private"
  description = "SSH Key/Pair name"
}


variable "db_username" {
  description = "The master username for the database."
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "The master password for the database."
  type        = string
  sensitive   = true
}

variable "public_key" {
  type = string
  default  = "<SSH Pub Key>"
}

variable "key_pair_name" {
  type = string
  default  = "myKeyPair"
}