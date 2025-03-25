# ECS public DNS updater

This repo contains a Terraform module that allows updating a Route53 A
record when an ECS task changes its public IP.

## The Problem

When running services in AWS Elastic Container Service (ECS) you usually
deploy an application load balancer (ALB) in front of it. When the service
creates or deletes tasks (containers) either due to a deployment or due
to scaling, it will update the load balancer's target group to reflect
all the tasks' internal IPs.

However, there are cases where you are certain that you will only
need a single task and the additional cost of a load balancer (~ $20)
is too high compared to the few cents that you pay for the execution of
your workload. The good news is, that ECS tasks can have public IPs and
hence can be accessed from the Internet without a load balancer. However,
the public IP will change with every deployment. Elastic IPs can not be
assigned to ECS tasks and service discovery through CloudMap does not
help, because it will only track the private IP of the task.

## The Solution

This module solves the above problem by deploying a Lambda function
which will update a Route53 A-record with the current public IP of an
ECS services task when an Eventbridge rule triggers it due to an ECS
deployment.

## Usage

```
module "dns_updater" {
  source = "github.com/dboesswetter/ecs-public-dns-update"
  service_name_mappings = [
    {
      hosted_zone_id   = "X12345" # example.com
      dns_name         = "service.example.com"
      dns_ttl          = 60 # keep it short because deployments will change the IP
      ecs_service_name = aws_ecs_service.registrar.name
      ecs_cluster_name = module.ecs_cluster.name
    }
  ]
}
```

## Caveats

This module has only been tested in one project so far. It uses Fargate
with public IPs enabled. Any other setup will probably not work. Also,
scaling the service to more than one task will probably yield only one
of the IPs.  One could imagine that load is distributed to all the tasks
through the DNS, but this is currently not the case.

## Author

Daniel Boesswetter <daniel@daniel-boesswetter.de>
