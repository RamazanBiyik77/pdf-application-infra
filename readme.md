This is a study infra for accounting department. There will an app. this app will create PDF and push it to a repository to store. Security should be the main concern.

Terragrunt didnt apply so use terraform-infra please.


# PASTE DRAW IO HERE

## TODO

1- Make s3 public. Set iam policy to restrict by office and VPC ip. So that from office users can read. From apphost application can write.

2- Seperate ssh keys of bastion and app host.

3 - Generate ssh keys with terraform.


## Assumptions
 1 - Apphost and bastionhost can be configurable from a static ip (office ip).

 2 - This app will read RDS but we didnt decide who will write to DB. In this study that concern didnt watch.

## Which Services and Why
- VPC - Networking
- Region eu-west-1
- Azs eu-west-1a eu-west-1b
- 1 IGW Bastion Host should be accessible from outside
- 1 Nat GW App host should communicate with outside (inside to outside)
- 2 route table

   - 1 public route table
   
        | ROUTE       |       |
        |-------------|-------|
        | 0.0.0.0/0   | IGW   |
        | 10.0.0.0/16 | local |
   - 1 private route table
        | ROUTE       |       |
        |-------------|-------|
        | 0.0.0.0/0   | NATGW |
        | 10.0.0.0/16 | local |

- EC2 - Bastionhost is the only jump point to apphost. Can be accesible only from office ip.

   - Security Group (Inbound)
        | PORT       |       |
        |-------------|-------|
        | 22   | Office ip |


- EC2 - Apphost application will run on this. We can set extra security SELunix.
accessible from a static ip (Assumption1)
   - Security Group (Inbound)
        | PORT       |       |
        |-------------|-------|
        | 22   |  Bastion Host SG |

- S3 to keep PDFs. Infra was on aws so s3 picked. Private bucket. (TODO 1)
- IAM role. Apphost should able to write to s3. So we need iam role and attach that to apphost.

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

- RDS postgresql. Community is bigger then others. On any issue easy to solve.

- RDS secgroup. Only apphost can access. (Assumption 2)

    | PORT       |       |
    |-------------|-------|
    | 22   |  App Host SG |

## How to run

#### Export AWS AK and SK
    export AWS_ACCESS_KEY_ID=<Access Key>
    export AWS_SECRET_ACCESS_KEY=<Secret Key> 
#### Create local ssh key
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/test
#### Copy ssh public key
    cat ~/.ssh/test.pub | pbcopy
#### Set env variables
  - Read vars.tf

    - Paste your public key to public_key variable default section
    - Learn your public ip (https://whatismyipaddress.com/) and fill office_ip default section
    - Set environment variable as you like. It can be stay default.
    - Set bucket_name variable as you like. It can be stay default.
    - Set key_pair_name variable as you like. It can be stay default.

#### Run Terraform Command
    terraform init
    terraform plan
    terraform apply # This will ask psql username and password


## How To Test

After terraform apply command it will print bastion, host and db addresses.

While setting env variables you have already created ssh keys. This is the entry point to servers.

Ssh into bastion:

    chmod 400 ~/.ssh/test && ssh -i ~/.ssh/test ec2-user@bastionhost_ip

Copy ~/.ssh/test into bastion server then ssh to apphost.

    chmod 400 ~/.ssh/test && ssh -i ~/.ssh/test ec2-user@apphost_ip

The application inside this host will read rds and write to s3. To check the accesses

    sudo yum install telnet
    telnet db_Address 5432
    touch test.txt && aws s3 cp test.txt s3://apphost-s3-bucket/test.txt  # (change according to vars.tf)