locals {
  name          = "${var.ecs_cluster_name}-${var.ecs_service_name}"
  function_name = local.name
  rule_name     = "dns-update-for-ecs-${local.name}"
}

resource "aws_cloudwatch_log_group" "default" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = 14
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "lambda_function_payload.zip"
}

resource "aws_lambda_function" "default" {
  filename         = "lambda_function_payload.zip"
  function_name    = local.function_name
  role             = aws_iam_role.default.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  runtime          = "python3.11"
  description      = "To be called by Eventbridge in order to update the DNS name ${var.dns_name} in hosted zone ${var.hosted_zone_id} to reflect the public IP of the ECS service ${var.ecs_service_name} in the cluster ${var.ecs_cluster_name}"
  timeout          = 20
  environment {
    variables = {
      "HOSTED_ZONE_ID" = var.hosted_zone_id,
      "DNS_NAME"       = var.dns_name,
      "DNS_TTL"        = var.dns_ttl
    }
  }
}

data "aws_ecs_cluster" "default" {
  cluster_name = var.ecs_cluster_name
}

resource "aws_cloudwatch_event_rule" "default" {
  name        = local.rule_name
  description = "Call Lambda ${local.function_name} for state changes to ECS service ${var.ecs_service_name} on cluster ${var.ecs_cluster_name}"
  event_pattern = jsonencode({
    "source" : ["aws.ecs"],
    "detail-type" : ["ECS Task State Change"],
    "detail" : {
      "clusterArn" : [data.aws_ecs_cluster.default.arn],
      "group" : ["service:${var.ecs_service_name}"],
      "desiredStatus" : ["RUNNING"],
      "lastStatus" : ["RUNNING"]
    }
  })
}

resource "aws_cloudwatch_event_target" "default" {
  rule     = aws_cloudwatch_event_rule.default.name
  arn      = aws_lambda_function.default.arn
  role_arn = aws_iam_role.eventbridge.arn
}
