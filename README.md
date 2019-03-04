# EKS Stack

## Drupal Set up

**You will need to make sure to have `awscli` and `aws-iam-authenticator` installed before starting to deploy this.**

You will need the following resources to deploy drupal to EKS properly. This guide will explain what specifications each of these resources need to be created with:

- IAM User
- EKS Cluster
- EC2 Worker Nodes
- ECR Repository
- S3 Bucket
- CloudFront Distribution
- RDS Instance
- Accompanying IAM Roles and Security Groups

### IAM User

You will use this user to manage the site you are deploying to EKS. You will need the following permissions:
- EKS
  - CreateCluster
  - DescribeCluster
- ECR
  - BatchCheckLayerAvailability
  - BatchGetImage
  - GetAuthorizationToken
  - GetDownloadUrlForLayer
  - CompleteLayerUpload
  - InitiateLayerUpload
  - PutImage
  - UploadLayerPart

### EKS Cluster

First things first, the EKS Cluster needs to be created. Before you create it though, you will need to make sure you have an IAM role and SecurityGroup for it. For your IAM role, you will need to have a role with these two AWS managed policies in it:
- AmazonEKSClusterPolicy
- AmazonEKSServicePolicy

Then you will need to create a security group with the following inbound rules:

| Type  | Protocol | Port Range | Source |
|-------|----------|------------|--------|
| HTTPS | TCP      | 443        | YourIP |

The rest of the rules will be created when you create the worker nodes. This is so you can access the cluster via `kubectl`.

Now you'll create the EKS Cluster. You will need to use the aws cli for this with the IAM user you created earlier. The command you need to enter looks like this:
```bash
aws eks --region <region> create-cluster --name <cluster-name> --role-arn <IAM-role-arn> --resources-vpc-config subnetIds=<comma-separated-subnet-ids>,securityGroupIds=<comma-separated-security-group-ids>
```

