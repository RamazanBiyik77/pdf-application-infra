terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.aws_region
}

locals {
  availability_zones = ["${var.aws_region}a", "${var.aws_region}b"]
}

# VPC
resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.environment}-vpc"
    Environment = var.environment
  }
}

# Public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.vpc.id
  count                   = length(var.public_subnets_cidr)
  cidr_block              = element(var.public_subnets_cidr, count.index)
  availability_zone       = element(local.availability_zones, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.environment}-${element(local.availability_zones, count.index)}-public-subnet"
    Environment = "${var.environment}"
  }
}

# Private Subnet
resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.vpc.id
  count                   = length(var.private_subnets_cidr)
  cidr_block              = element(var.private_subnets_cidr, count.index)
  availability_zone       = element(local.availability_zones, count.index)
  map_public_ip_on_launch = false

  tags = {
    Name        = "${var.environment}-${element(local.availability_zones, count.index)}-private-subnet"
    Environment = "${var.environment}"
  }
}

#Internet gateway
resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    "Name"        = "${var.environment}-igw"
    "Environment" = var.environment
  }
}

# Elastic-IP (eip) for NAT
resource "aws_eip" "nat_eip" {
  vpc        = true
  depends_on = [aws_internet_gateway.ig]
}

# NAT Gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = element(aws_subnet.public_subnet.*.id, 0)
  tags = {
    Name        = "nat-gateway-${var.environment}"
    Environment = "${var.environment}"
  }
}

# Routing tables to route traffic for Private Subnet
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name        = "${var.environment}-private-route-table"
    Environment = "${var.environment}"
  }
}

# Routing tables to route traffic for Public Subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name        = "${var.environment}-public-route-table"
    Environment = "${var.environment}"
  }
}

# Route for Internet Gateway
resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ig.id
}

# Route for NAT Gateway
resource "aws_route" "private_internet_gateway" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_nat_gateway.nat.id
}

# Route table associations for both Public & Private Subnets
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnets_cidr)
  subnet_id      = element(aws_subnet.public_subnet.*.id, count.index)
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnets_cidr)
  subnet_id      = element(aws_subnet.private_subnet.*.id, count.index)
  route_table_id = aws_route_table.private.id
}
################################################

##############  S3 OPS  ########################

resource "aws_s3_bucket" "app_s3_bucket" {
  bucket = "apphost-s3-bucket"
}

resource "aws_s3_bucket_ownership_controls" "ownership" {
  bucket = aws_s3_bucket.app_s3_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# resource "aws_s3_bucket_public_access_block" "publicaccessblock" {
#   bucket = aws_s3_bucket.app_s3_bucket.id

#   block_public_acls       = false
#   block_public_policy     = false
#   ignore_public_acls      = false
#   restrict_public_buckets = false
# }

# resource "aws_s3_bucket_acl" "app_s3_acl" {
#   depends_on = [
# 	aws_s3_bucket_public_access_block.publicaccessblock,
# 	aws_s3_bucket_ownership_controls.ownership,
#   ]

#   bucket = aws_s3_bucket.app_s3_bucket.id
#   acl    = "public-read"
# }

resource "aws_s3_bucket_acl" "app_s3_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.ownership]

  bucket = aws_s3_bucket.app_s3_bucket.id
  acl    = "private"
}

################################################

#############    IAM ROLES #####################

resource "aws_iam_role" "app_assume_role" {
  name = "app_assume_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
      tag-key = "app-assume"
  }
}
resource "aws_iam_instance_profile" "s3_apphost_profile" {
  name = "s3_apphost_profile"
  role = "${aws_iam_role.app_assume_role.name}"
}

resource "aws_iam_role_policy" "s3_app_policy" {
  name = "s3_app_policy"
  role = "${aws_iam_role.app_assume_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Effect": "Allow",
        "Action": [
            "s3:GetObject",
            "s3:PutObject",
            "s3:GetObjectAcl",
            "s3:PutObjectAcl",
            "s3:ListBucket",
            "s3:GetBucketAcl",
            "s3:PutBucketAcl",
            "s3:GetBucketLocation"
        ],
        "Resource": "arn:aws:s3:::${aws_s3_bucket.app_s3_bucket.bucket}/*",
        "Condition": {
        }
    }
  ]
}
EOF
}


# touch test && aws s3 cp test s3://apphost-s3-bucket/test
################################################

############# SECGRP OPS #####################
resource "aws_security_group" "bastion_host" {
  name        = "bastion_host_sg"
  description = "Bastion Host Details"
  vpc_id = aws_vpc.vpc.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.office_ip]
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
  tags = {
    Name = "Bastion"
  }
}

resource "aws_security_group" "app_host" {
  name        = "app_host_sg"
  description = "app Host Details"
  vpc_id = aws_vpc.vpc.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.public_subnets_cidr[0]]
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
  tags = {
    Name = "Apphost"
  }
}

resource "aws_security_group" "psql_db_sg" {
  name        = "apphost_db_sg"
  description = "Security group for tutorial databases"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description     = "Allow postgresql traffic from only the host sg"
    from_port       = "5432"
    to_port         = "5432"
    protocol        = "tcp"
    security_groups = [aws_security_group.app_host.id]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "apphost_db_sg"
  }
}
################################################

############# SSHKEYS OPS ######################

resource "aws_key_pair" "generated_key" {
  key_name   = var.key_pair_name
  public_key = var.public_key
}

################################################

#############  EC2 ops #########################
resource "aws_instance" "bastionhost" {
  ami           = "ami-0648880541a3156f7"
  instance_type = "t2.micro"
  key_name = aws_key_pair.generated_key.key_name
  vpc_security_group_ids = [ aws_security_group.bastion_host.id ]
  subnet_id = aws_subnet.public_subnet[0].id
  associate_public_ip_address = true
  tags = {
    Name = "Bastion"
  }
}

resource "aws_instance" "apphost" {
  ami           = "ami-0648880541a3156f7"
  iam_instance_profile = "${aws_iam_instance_profile.s3_apphost_profile.name}"
  instance_type = "t2.micro"
  key_name = aws_key_pair.generated_key.key_name
  vpc_security_group_ids = [ aws_security_group.app_host.id ]
  subnet_id = aws_subnet.private_subnet[0].id
  associate_public_ip_address = false
  tags = {
    Name = "apphost"
  }
}

################################################

##################  SUBNETGRP OPS ##############

resource "aws_db_subnet_group" "apphost_db_subnet_group" {
  // The name and description of the db subnet group
  name        = "apphost_db_subnet_group"
  description = "DB subnet group for application"
  
  // Since the db subnet group requires 2 or more subnets, we are going to
  // loop through our private subnets in "tutorial_private_subnet" and
  // add them to this db subnet group
  subnet_ids  = [for subnet in aws_subnet.private_subnet : subnet.id]
}


################################################

##################  RDS OPS ####################

resource "aws_db_instance" "apphostdb" {
  allocated_storage    = 20
  storage_type         = "gp2"
  instance_class       = "db.t3.micro"
  identifier           = "apphostdb"
  engine               = "postgres"
  engine_version       = "15.3"
 
  db_name  = "appdb"
  username = var.db_username
  password = var.db_password
 
  db_subnet_group_name = aws_db_subnet_group.apphost_db_subnet_group.id

  vpc_security_group_ids = [aws_security_group.psql_db_sg.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
}


################################################