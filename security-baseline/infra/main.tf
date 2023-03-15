locals {
  tags = {
    sometag = "SomeTag"
  }
}

resource "aws_sfn_state_machine" "baseline_sm" {
  provider   = aws.audit
  name       = var.statemachine_name
  role_arn   = aws_iam_role.security_baseline_sm_role.arn
  definition = templatefile("../statemachine/security_baseline.asl.json", { GuardDutyOrgFunctionArn = module.guardduty_org_function.lambda_function_arn, GuardDutyAuditFunctionArn = module.guardduty_audit_function.lambda_function_arn })
  tags       = local.tags
}

resource "aws_iam_role" "security_baseline_sm_role" {
  provider = aws.audit
  name     = var.statemachine_role_name
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "states.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
  tags = local.tags
}

resource "aws_iam_policy" "statemachine_policy" {
  provider    = aws.audit
  name        = var.statemachine_policy_name
  path        = var.statemachine_policy_path
  description = "State Machine policy so that the statemachine can invoke lambda functions"
  policy      = data.aws_iam_policy_document.lambda_invoke_functions.json
  tags        = local.tags
}

resource "aws_iam_role_policy_attachment" "statemachine_role_attachment" {
  provider   = aws.audit
  role       = aws_iam_role.security_baseline_sm_role.name
  policy_arn = aws_iam_policy.statemachine_policy.arn
}

resource "aws_iam_role" "events_exec_state_machine_role" {
  provider = aws.audit
  name     = var.events_executor_role_name
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "events.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
  tags = local.tags
}

resource "aws_ssm_parameter" "security_baseline_config" {
  provider    = aws.audit
  name        = var.ssm_config_name
  description = "Config data for ${var.service_name} service"
  type        = "String"
  value       = templatefile("../config/config.json", {})
  tags        = local.tags
}

resource "aws_iam_policy" "guardduty_ssm_config_policy" {
  provider    = aws.audit
  name        = var.ssm_config_policy_name
  path        = var.ssm_config_policy_path
  description = "Allows the lambda functions to access SSM parameters for config"
  policy      = data.aws_iam_policy_document.security_baseline_parameters.json
  tags        = local.tags
}

module "guardduty_org_function" {
  providers = {
    aws = aws.audit
  }
  source  = "terraform-aws-modules/lambda/aws"
  version = "4.7.2"

  function_name = var.guardduty_org_function_name
  description   = "Sets up and configures GuardDuty for Org use"
  handler       = "app.lambda_handler"
  runtime       = "python3.9"
  timeout       = 60

  role_name = var.guardduty_org_function_role_name
  role_path = var.guardduty_org_function_role_path

  source_path = "../functions/guardduty_org"

  # layer is hosted with AWS, so its their account id
  layers = [
    "arn:aws:lambda:${data.aws_region.current.name}:345057560386:layer:AWS-Parameters-and-Secrets-Lambda-Extension:4"
  ]

  environment_variables = {
    ORG_ROLE                               = aws_iam_role.security_baseline_org_role.arn
    SSM_PATH                               = aws_ssm_parameter.security_baseline_config.name
    PARAMETERS_SECRETS_EXTENSION_HTTP_PORT = 2773
    SSM_PARAMETER_STORE_TTL                = 240
    PARAMETERS_SECRETS_EXTENSION_LOG_LEVEL = "DEBUG"
  }
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "guardduty_org_policy_attachment" {
  provider   = aws.audit
  role       = module.guardduty_org_function.lambda_role_name
  policy_arn = "arn:aws:iam::aws:policy/AmazonGuardDutyFullAccess"
}

resource "aws_iam_policy" "guardduty_org_policy" {
  provider    = aws.audit
  name        = var.guardduty_org_role_policy_name
  path        = "/"
  description = "Allows the guardduty org function to assume role into the org account"
  policy      = data.aws_iam_policy_document.function_assume_role.json
  tags        = local.tags
}

resource "aws_iam_role_policy_attachment" "guardduty_org_assume_role" {
  provider   = aws.audit
  role       = module.guardduty_org_function.lambda_role_name
  policy_arn = aws_iam_policy.guardduty_org_policy.arn
}

resource "aws_iam_role_policy_attachment" "guardduty_org_ssm" {
  provider   = aws.audit
  role       = module.guardduty_org_function.lambda_role_name
  policy_arn = aws_iam_policy.guardduty_ssm_config_policy.arn
}

module "guardduty_audit_function" {
  providers = {
    aws = aws.audit
  }
  source  = "terraform-aws-modules/lambda/aws"
  version = "4.7.2"

  function_name = var.guardduty_audit_function_name
  description   = "Configures GuardDuty across all accounts."
  handler       = "app.lambda_handler"
  runtime       = "python3.9"
  timeout       = 60

  role_name = var.guardduty_audit_function_role_name
  role_path = var.guardduty_audit_function_role_path

  source_path = "../functions/guardduty_audit"

  layers = [
    "arn:aws:lambda:${data.aws_region.current.name}:345057560386:layer:AWS-Parameters-and-Secrets-Lambda-Extension:4"
  ]

  environment_variables = {
    SSM_PATH                               = aws_ssm_parameter.security_baseline_config.name
    PARAMETERS_SECRETS_EXTENSION_HTTP_PORT = 2773
    SSM_PARAMETER_STORE_TTL                = 240
    PARAMETERS_SECRETS_EXTENSION_LOG_LEVEL = "DEBUG"
  }

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "guardduty_audit_policy_attachment" {
  provider   = aws.audit
  role       = module.guardduty_audit_function.lambda_role_name
  policy_arn = "arn:aws:iam::aws:policy/AmazonGuardDutyFullAccess"
}

resource "aws_iam_role_policy_attachment" "guardduty_audit_ssm" {
  provider   = aws.audit
  role       = module.guardduty_audit_function.lambda_role_name
  policy_arn = aws_iam_policy.guardduty_ssm_config_policy.arn
}

resource "aws_cloudwatch_event_rule" "step_function_event_rule" {
  provider            = aws.audit
  name                = var.event_rule_name
  schedule_expression = "rate(60 minutes)"
  description         = "Triggers the security-baseline checks every 30 minutes"
  is_enabled          = var.event_enabled
  tags                = local.tags
}

resource "aws_iam_policy" "events_executor_policy" {
  provider    = aws.audit
  name        = var.event_executor_policy_name
  path        = var.event_executor_policy_path
  description = "Allows AWS events to execute the security-baseline state machine"
  policy      = data.aws_iam_policy_document.events_executor_statemachine.json
  tags        = local.tags
}

resource "aws_iam_role_policy_attachment" "events_role_policy_attachment" {
  provider   = aws.audit
  role       = aws_iam_role.events_exec_state_machine_role.name
  policy_arn = aws_iam_policy.events_executor_policy.arn
}

resource "aws_cloudwatch_event_target" "step_function_event_target" {
  provider = aws.audit
  rule     = aws_cloudwatch_event_rule.step_function_event_rule.name
  arn      = aws_sfn_state_machine.baseline_sm.arn
  role_arn = aws_iam_role.events_exec_state_machine_role.arn
}
