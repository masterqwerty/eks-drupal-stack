#!/bin/bash

instanceID=$(curl --silent http://169.254.169.254/latest/meta-data/instance-id)
region=$(hostname | cut -f 2 -d '.')
groupName=$(aws ec2 describe-instances --region $region --instance-id $instanceID | grep -B1 "aws:autoscaling:groupName" | sed -n '1p' | awk {'print $2'} | sed 's/"//g; s/,//g')
CPURequestUsage=$(kubectl describe node $(hostname) | grep cpu | sed '$!d' | awk {'print $3'} | sed 's/(//; s/%)//')
CPULimitUsage=$(kubectl describe node $(hostname) | grep cpu | sed '$!d' | awk {'print $5'} | sed 's/(//; s/%)//')
MemoryRequestUsage=$(kubectl describe node $(hostname) | grep memory | sed '$!d' | awk {'print $3'} | sed 's/(//; s/%)//')
MemoryLimitUsage=$(kubectl describe node $(hostname) | grep memory | sed '$!d' | awk {'print $5'} | sed 's/(//; s/%)//')

aws cloudwatch put-metric-data --namespace EKS --metric-name K8sCPUReservedRequests --value $CPURequestUsage --dimensions AutoScalingGroup=$groupName --region $region --unit Percent
aws cloudwatch put-metric-data --namespace EKS --metric-name K8sCPUReservedLimit --value $CPULimitUsage --dimensions AutoScalingGroup=$groupName --region $region --unit Percent
aws cloudwatch put-metric-data --namespace EKS --metric-name K8sMemoryReservedRequests --value $MemoryRequestUsage --dimensions AutoScalingGroup=$groupName --region $region --unit Percent
aws cloudwatch put-metric-data --namespace EKS --metric-name K8sMemoryReservedLimit --value $MemoryLimitUsage --dimensions AutoScalingGroup=$groupName --region $region --unit Percent
aws cloudwatch put-metric-data --namespace EKS --metric-name K8sCPUReservedRequests --value $CPURequestUsage --dimensions InstanceId=$instanceID --region $region --unit Percent
aws cloudwatch put-metric-data --namespace EKS --metric-name K8sCPUReservedLimit --value $CPULimitUsage --dimensions InstanceId=$instanceID --region $region --unit Percent
aws cloudwatch put-metric-data --namespace EKS --metric-name K8sMemoryReservedRequests --value $MemoryRequestUsage --dimensions InstanceId=$instanceID --region $region --unit Percent
aws cloudwatch put-metric-data --namespace EKS --metric-name K8sMemoryReservedLimit --value $MemoryLimitUsage --dimensions InstanceId=$instanceID --region $region --unit Percent
