# Region
data "aws_region" "current" {}
# Policy for statemachine to invoke functions
data "aws_iam_policy_document" "lambda_invoke_functions" {
  provider = aws.audit
  statement {
    sid     = "StateMachineInvokeLambdaFunctionsPolicy"
    actions = ["lambda:InvokeFunction"]
    resources = [
      module.guardduty_org_function.lambda_function_arn,
      module.guardduty_audit_function.lambda_function_arn
    ]
  }
}
# Policy for Org function to assume the guardduty org role
data "aws_iam_policy_document" "function_assume_role" {
  provider = aws.audit
  statement {
    sid     = "AssumeRoleAccessForFunction"
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    resources = [
      aws_iam_role.security_baseline_org_role.arn,
    ]
  }
}
# Policy for EventBus to Execute the StateMachine
data "aws_iam_policy_document" "events_executor_statemachine" {
  provider = aws.audit
  statement {
    sid       = "EventsExecuteStateMachine"
    actions   = ["states:StartExecution"]
    effect    = "Allow"
    resources = [aws_sfn_state_machine.baseline_sm.arn]
  }
}
# Get the Configuration Parameter
data "aws_iam_policy_document" "security_baseline_parameters" {
  provider = aws.audit
  statement {
    sid = "GetSsmParametersForSecurityBaseline"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParametersByPath"
    ]
    effect    = "Allow"
    resources = [aws_ssm_parameter.security_baseline_config.arn]
  }
}
