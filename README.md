# EKS Stack

## Drupal Set up

**You will need to make sure to have `awscli` and `aws-iam-authenticator` installed before starting to deploy this.**

You will need to deploy the following resources to deploy drupal to EKS properly. This guide will explain what specifications each of these resources need to be created with:

- IAM User
- ECR Repository
- RDS Instance
- S3 Bucket
- EKS Cluster
- EC2 Worker Nodes
- CloudFront Distribution
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

### ECR Repository

This will hold the image for your site. Just create one in the ECR console, and note down the ECR repository's URI.

This drupal stack works with the wodby/docker4drupal stack that uses docker-compose to deploy a fully functional drupal stack into Docker. You will need to deploy this stack as your dev environment on your machine. You can get this stack by cloning the github repo at https://github.com/wodby/docker4drupal.

After you are done cloning the repo, deploy the stack using `docker-compose up -d` when in the docker4drupal directory. You will need to install the s3\_sync module so you can use the S3 bucket for your public files. Look at the README in the s3\_sync module directory to see further configuration that needs to be done.

When that's all done, copy the whole html directory to the same directory where the Dockerfile of this repo is. Also copy the settings file to prod.settings.php to the directory with the Dockerfile, and change that file to contain the settings for your prod environment. Then run:
```
docker build -t <ECR-repository-URI> .
$(aws ecr get-login --region <region> --no-include-email)
docker push <ECR-repository-URI>
```

This is also how you will update your site. Simply make sure the changes are present in the copied html directory, and run the same commands from above. Then follow the instructions given by the `update.sh` script.

### RDS Instance and S3 Bucket

These resources don't really need any special configuration. Configure the RDS Instance the way you want it for use with drupal, and then create a S3 bucket to store drupal's public files in. You will not need to make the S3 bukcet public in order to make it work with CloudFront.

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

Once the EKS cluster is done deploying, you will need to update your kubeconfig on your machine, so you can interact with the cluster. This is simply done with the following command:

```bash
aws eks --region <region> update-kubeconfig --name <cluster-name>
```

### EC2 Worker Nodes

Now you will need to go to the CloudFormation console. Click **Create Stack**, and then select **Specify an Amazon S3 template URL**. Enter the following URL:
```
https://amazon-eks.s3-us-west-2.amazonaws.com/cloudformation/2019-02-11/amazon-eks-nodegroup.yaml
```

Then click **Next**. CloudFormation will now ask you to specify some parameters. More details on these parameters are found here: https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html#eks-launch-workers

Make sure you get the correct AMI for the worker nodes, otherwise this won't work. Then configure the next parts of the CloudFormation template as desired, and deploy the template.

Then, to allow the worker nodes to joing your cluster, you will need to add a config map to the EKS Cluster. Run the following command:
```bash
curl -O https://amazon-eks.s3-us-west-2.amazonaws.com/cloudformation/2019-02-11/aws-auth-cm.yaml
```

Then open the file to change the IAM role ARN to the IAM role of the worker nodes that was created with the CloudFormation template. Then run the following command:

```bash
kubectl apply -f aws-auth-cm.yaml
```

### Deploy drupal.yml

Run `cp default.drupal.yml drupal.yml`, and then open `drupal.yml` for editing. You will need to specify the following:
- RDS Endpoint 
- RDS Username 
- RDS Password
- RDS Database Name 
- Trusted Host Patterns
- Autoscaling Rules
- Names of deployment, services, and autoscaler if wanted

Then run:

```bash
kubectl create -f drupal.yml
```

### CloudFront Distribution

Once that's all done deploying, you can finish the last part of this stack. Go to the CloudFront console, and click **Create Distribution**. Then click **Get Started** under **Web**. Then specify your S3 Bucket as your origin, and configure everything else as desired. Then click **Create Distribution**.

Now, you will also need to specify the load balancer created by `kubectl` as an origin as well. You can do this before the distribution is done deploying. Go to the **Origins and Origin Groups** tab under your CloudFront distribution, and click **Create Origin**. Then choose the load balancer that was created by `kubectl` as your origin. You can get the name of this load balancer by running `kubectl get svc`, and the http service should have the load balancer's DNS name next to it.

Then you will need to specify behaviors so CloudFront knwos when to use the load balancer as an origin. Go to the **Behaviors** tab, and click **Create Behavior**. In **Path Pattern**, write `core/*`, and then specify the load balancer as the origin. Configure everything else as needed. You will also need to create a behavior for the path patterns `modules/*`, `themes/*`, `profiles/*`, `sites/*`, and `vendor/*`.

Once CloudFront is deployed, you are all set to go! 
