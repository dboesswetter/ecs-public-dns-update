locals {
  rule_names = [for x in var.service_name_mappings : "dns-update-for-ecs-${x.ecs_cluster_name}-${x.ecs_service_name}"]
}

resource "aws_cloudwatch_log_group" "default" {
  name              = "/aws/lambda/${var.lambda_name}"
  retention_in_days = 14
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "lambda_function_payload.zip"
}

resource "aws_lambda_function" "default" {
  filename         = "lambda_function_payload.zip"
  function_name    = var.lambda_name
  role             = aws_iam_role.lambda.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  runtime          = "python3.11"
  description      = "To be called by Eventbridge in order to update Route53 to reflect the public IP of an ECS task"
  timeout          = 20
}

data "aws_ecs_cluster" "default" {
  count        = length(var.service_name_mappings)
  cluster_name = var.service_name_mappings[count.index].ecs_cluster_name
}

resource "aws_cloudwatch_event_rule" "default" {
  count       = length(var.service_name_mappings)
  name        = local.rule_names[count.index]
  description = "Call Lambda ${var.lambda_name} for state changes to ECS service ${var.service_name_mappings[count.index].ecs_service_name} on cluster ${var.service_name_mappings[count.index].ecs_cluster_name}"
  event_pattern = jsonencode({
    "source" : ["aws.ecs"],
    "detail-type" : ["ECS Task State Change"],
    "detail" : {
      "clusterArn" : [data.aws_ecs_cluster.default[count.index].arn],
      "group" : ["service:${var.service_name_mappings[count.index].ecs_service_name}"],
      "desiredStatus" : ["RUNNING"],
      "lastStatus" : ["RUNNING"]
    }
  })
}

resource "aws_cloudwatch_event_target" "default" {
  count    = length(var.service_name_mappings)
  rule     = aws_cloudwatch_event_rule.default[count.index].name
  arn      = aws_lambda_function.default.arn
  role_arn = aws_iam_role.eventbridge.arn
  input_transformer {
    input_paths = {
      attachments = "$.detail.attachments"
      ## This obviously fails due to the filter expression, so we need to do in in Python:
      #eni_id = "$.detail.attachments[?(@.type=='eni')].details[?(@.name=='networkInterfaceId')].value"
    }
    input_template = <<EOF
{
    "attachments": <attachments>,
    "hosted_zone_id": "${var.service_name_mappings[count.index].hosted_zone_id}",
    "dns_name": "${var.service_name_mappings[count.index].dns_name}",
    "dns_ttl": "${var.service_name_mappings[count.index].dns_ttl}"
}
    EOF
  }
}
