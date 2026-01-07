terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  project_name        = var.project_name
  lambda_source_dir   = "${path.module}/lambda"
  validate_zip        = "${local.lambda_source_dir}/validate.zip"
  log_metrics_zip     = "${local.lambda_source_dir}/log_metrics.zip"
}

resource "aws_iam_role" "lambda_exec" {
  name               = "${local.project_name}-lambda-exec"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role" "step_function_role" {
  name               = "${local.project_name}-sfn-role"
  assume_role_policy = data.aws_iam_policy_document.sfn_assume.json
}

resource "aws_iam_role_policy" "sfn_invoke_lambda" {
  name   = "${local.project_name}-sfn-invoke-lambda"
  role   = aws_iam_role.step_function_role.id
  policy = data.aws_iam_policy_document.sfn_policy.json
}

resource "aws_lambda_function" "validate" {
  function_name = "${local.project_name}-validate"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "validate.lambda_handler"
  runtime       = "python3.11"
  filename      = local.validate_zip
  source_code_hash = filebase64sha256(local.validate_zip)
}

resource "aws_lambda_function" "log_metrics" {
  function_name = "${local.project_name}-log-metrics"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "log_metrics.lambda_handler"
  runtime       = "python3.11"
  filename      = local.log_metrics_zip
  source_code_hash = filebase64sha256(local.log_metrics_zip)
}

locals {
  sfn_definition = jsonencode({
    Comment = "Training pipeline"
    StartAt = "ValidateData"
    States = {
      ValidateData = {
        Type       = "Task"
        Resource   = aws_lambda_function.validate.arn
        ResultPath = "$.validate"
        Next       = "LogMetrics"
      }
      LogMetrics = {
        Type       = "Task"
        Resource   = aws_lambda_function.log_metrics.arn
        ResultPath = "$.log"
        End        = true
      }
    }
  })
}

resource "aws_sfn_state_machine" "training_pipeline" {
  name     = "${local.project_name}-pipeline"
  role_arn = aws_iam_role.step_function_role.arn
  definition = local.sfn_definition
  type     = "STANDARD"
}

output "state_machine_arn" {
  description = "ARN of the training pipeline Step Function"
  value       = aws_sfn_state_machine.training_pipeline.arn
}

resource "aws_iam_role_policy" "lambda_inline" {
  name   = "${local.project_name}-lambda-inline"
  role   = aws_iam_role.lambda_exec.id
  policy = data.aws_iam_policy_document.lambda_inline.json
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_inline" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "sfn_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "sfn_policy" {
  statement {
    actions = [
      "lambda:InvokeFunction",
      "lambda:InvokeAsync"
    ]
    resources = [
      aws_lambda_function.validate.arn,
      aws_lambda_function.log_metrics.arn
    ]
  }
}
