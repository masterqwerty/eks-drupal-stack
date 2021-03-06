# EKS Drupal Stack

This is a stack to get Drupal resources running on AWS EKS.

## Set Up

**You will need to make sure you have `awscli`, `aws-iam-authenticator`, `kubectl`, and `eksctl`, installed and working before deploying this.**

### AWS Resources Initial Set Up

#### `eksctl create cluster` method

The first part is quite easy. You first deploy the underlying structure for EKS with `eksctl`. The command is:
```bash
eksctl create cluster --name=<clusterName> --nodes=<desiredInstances> --nodes-min=<minInstances> --nodes-max=<maxInstances> --node-ami=auto --ssh-access --ssh-public-key=<EC2KeyPair>
```

This will create a new VPC, the EKSCluster, and the node group for Kubernetes along with the required IAM Roles and Security Groups. You will then need to deploy a few other things manually to get this to work with Drupal resources. Wait until the VPC has been created (you can check either the CloudFormation Template that `eksctl` creates, or just check the VPC console for a new VPC), and then you can move on to deploy the next resources.

You will need to deploy an RDS instance, an EFS filesystem, and an ECR repository. You will also need to make sure your IAM user you used for `eksctl` has permissions to get an authorization token from ECR, and also to pull and push images to and from ECR. **Make sure that you deploy your RDS instance and EFS filesystem in the correct VPC.** You will then need to wait for the node group to be done deploying to move on. This can take a while, since you are waiting for the EKS Cluster to finish deploying.

You will also need to make sure that the security group on your RDS Instance allow inbound traffic from the node group, otherwise you won't be able to access the database. You will also need to make sure the EFS mountpoints are either in the node group's security group, or that the security group they're in allow traffic from the node group's security group.

Once that is done, you can go ahead and configure autoscaling rules for your autoscaling group so that the instances will scale the way you want them to. The way the pods will scale is according to CPU Usage, so you may want to scale your EC2 instances according to CPU as well.

#### `aws eks create-cluster` method

You can also just use the AWS CLI to create the cluster. The steps to creating the cluster with an accompanying node group is on its documentation here: https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html going from steps one to three.

There are a few things to note. You won't need to find a way to mount EFS manually, since that's done with the yaml file we'll use to deploy our containers and such. You will also need to configure how you will want the EC2 instances to scale if they end up getting too many pods on them. It is recommended you use a rule that involves CPU utilization, since that's how the pods will scale.

### Local Resources Initial Set Up

You will notice that this repo has the `kubernetes-incubator/metrics-server` and `wodby/docker4drupal` repos as submodules. These will both be necessary as you start developing. First, pull all the files from those submodules by running 
```bash
git submodule update --init.
```
 
The first thing you need to do is go and change the volumes for docker4drupal in the file `docker-compose.override.yml`. Replace the following code:
```yaml
  php:
    image: wodby/drupal:$DRUPAL_TAG
    environment:
      PHP_FPM_CLEAR_ENV: "no"
    volumes:
      - codebase:/var/www/html

  nginx:
    volumes:
      - codebase:/var/www/html

volumes:
  codebase:
```
with
```yaml
  php:
    image: wodby/drupal:$DRUPAL_TAG
    environment:
      PHP_FPM_CLEAR_ENV: "no"
    volumes:
      - ../html:/var/www/html

  nginx:
    volumes:
      - ../html:/var/www/html
```
This will make it so the html files from your docker4drupal stack appear in the parent directory of this repo so you can use them to build your docker images.

The next thing you'll need to do is make sure your `kubectl` is connected to the EKS cluster you just created. Run the command 
```bash
aws eks update-kubeconfig --name=<clusterName>
``` 
to update kubernetes configuration to use the EKS cluster you created. You can make sure it's working by running 
```bash
kubectl get svc
```
and making sure that it shows a kubernetes service running. Then you will need to deploy the metrics-server stuff so your pod scaler works properly. Run 
```bash
kubectl apply -f metrics-server/deploy/1.8+/
``` 
to apply all the necessary resources.

Then setup your drupal site on your docker4drupal stack. Run 
```bash
docker-compose up -d
``` 
to get the containers deployed. Then access the stack via the traefik frontend (the default frontend is `drupal.docker.localhost:8000`), and install the site. By this point, the html directory should have popped into the parent directory of this repo. From there, copy the `default.settings.php` file found in `html/web/sites/default/` to the parent directory as `prod.settings.php`. This will be the settings file that will be used in your kubernetes deployment. You can adjust this file to work as the `settings.php` file for your kubernetes deployment. **Note: The database configuration, trusted host patterns, and config sync directory location are automatically put into the settings.php file when you deploy the kubernetes deployment. These values are adjusted in the yaml file.**

The last thing you will need to do is build the docker image, and push it to ECR. From the parent directory, run 
```bash
docker build -t <ecrUri> .
```
This will build the image and save it on your local machine. If you haven't already, you will need to run 
```bash
$(aws ecr get-login --no-include-email)
``` 
to access ECR. You won't need to do this everytime you build the image, since the token will last 12 hours. What this command will do is generate a docker login command with the token you need that you can use in your terminal to "login" to ECR. Then run 
```bash
docker push <ecrUri>
```
This will push your image up to ECR.

## YAML File

You will notice that there is a file called `default.drupal.yml`. Copy this file to a differently named .yml file. Open that file in your favorite editor, and we will adjust some things. There are comments pretty much everywhere where you need to put in your own values. We will still go over them here.

This yaml file deploys four resources: one deployment, one horizontal pod scaler, and two services. The deployment is where the container definitions are, and where we'll configure things like the database username and password. The horizontal pod scaler will check the CPU utilization on the pods that are deployed, and scale accordingly. The first service is a load balancer from which traffic will access your site. Then the second service exposes the php port so that the containers you deploy can access them. Here are the values you will need to update:

  * **Names** There are a whole bunch of places where you just need to name the resources. The will all be under the `metadata` section of the respective resource. Just name the four resources however you want to. I would recommend you name them according to the site your deploying. Then you will need to enter the application name of the deployment. This basically makes it so you can select specific resources under a certain application name to apply things like auto scalers and load balancers to. Just enter in an application name everywhere where there's the key `app`. Make sure that all of the names are the same.
  * **Host Volume Mount** This is under `spec` -> `template` -> `spec` -> `volumes`. The volume with the name `public-files` is the one you'll want to adjust. You will want to change the path under `hostPath` to point at the directory where you mounted EFS on your EC2 instance.
  * **ECR Repo URI** You will want to put in the URI of the ECR repository that you will be using for the docker image of your drupal container. This is under `spec` -> `template` -> `spec` -> `containers`, and then the `image` property on the drupal container.
  * **Database Configuration** You will notice that in the `drupal` container's configuration, there are a bunch of environment variables like `DB_HOST` and `DB_PASSWORD`. This is where you'll put the information drupal needs to access your RDS instance. `DB_HOST` will be your RDS Endpoint. Then for `DB_PASSWORD`, `DB_USER`, and `DB_NAME`, put the username, password, and database you specified when creating the RDS instance. `DB_DRIVER` will be the driver for your RDS instance. In most cases, it will be `mysql`.
  * **Trusted Host Patterns** Put the trusted host patterns config here in double quotations. You can put `"'.*'"` to tell drupal to allow all host patterns through. Make sure to put the list of trusted host patterns in double quotes, otherwise kubernetes won't be able to parse it correctly.
  * **Load Balancer Type** In the Load Balancer service section of the YAML file, you will notice that there are two lines commented out. If you uncomment these lines, the service will deploy an AWS Network Load Balancer instead of a Classic Load Balancer. The deployment of a Network Load Balancer is still an alpha feature of kubernetes, so use your own discretion here. Leaving the lines commented will deploy a Classic Load Balancer.

After this, you are good to go. Simply run 
```bash
kubectl create -f <yourFile>.yml
```
and `kubectl` will deploy those resource for you. You can watch the pods with 
```bash
kubectl get pods --watch
``` 
to see when they're done deploying. It will take about two to three minutes the first time you deploy this. Also check to make sure that your load balancer is ready to accept traffic before trying to access the site. You can access the site with the load balancer's DNS name. Also note that the horizontal pod scaler will take a minute or two before it actually starts recording metrics. After that, you are all set to go!

## Updating the docker image

Most of your updates should be done in the docker4drupal stack. When you add new modules or themes, you can update your docker image to include those by building and pushing the docker image as mentioned above. You will also need to run the update script included in this repo to make kubernetes force a reload of the containers. The command is 
```bash
./update.sh -c <containerBeingUpdated> -d <deploymentBeingUpdated>
``` 
This will update an environment variable in the configuration for the container called `LAST_UPDATED`, and kubernetes will go and fetch the new docker image. It should take about 30 to 45 seconds for each of the pods to finish deploying, depending of course on how long it takes to start the container. Luckily, there is no down time, since kubernetes won't terminate the old pods until the new pods are up and running and ready to receive traffic.
