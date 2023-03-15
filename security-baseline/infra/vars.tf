variable "service_name" {
  type        = string
  description = "Service name name for each resource. Consider prefix-service format."
  default     = "security-baseline"
}

variable "statemachine_name" {
  type        = string
  description = "Name of the statemachine"
  default     = "security-baseline-sm"
}

variable "statemachine_role_name" {
  type        = string
  description = "Name of the role used by the statemachine"
  default     = "security-baseline-sm-role"
}

variable "statemachine_policy_name" {
  type        = string
  description = "Name of the policy for the statemachine"
  default     = "security-baseline-sm-policy"
}

variable "statemachine_policy_path" {
  type        = string
  description = "Path of the policy for the statemachine"
  default     = "/"
}

variable "events_executor_role_name" {
  type        = string
  description = "Name of the role used by events to invoke the statemachine"
  default     = "security-baseline-events-executor-role"
}

variable "ssm_config_name" {
  type        = string
  description = "Name of the SSM Paramater Store Key"
  default     = "/security_baseline/config"
}

variable "ssm_config_policy_name" {
  type        = string
  description = "Name of the ssm parameter store policy"
  default     = "security-baseline-ssm-param-policy"
}

variable "ssm_config_policy_path" {
  type        = string
  description = "Path of the policy for the SSM Parameters"
  default     = "/"
}

variable "guardduty_org_function_name" {
  type        = string
  description = "Name of the function that preps the Org for GuardDuty"
  default     = "security-baseline-guardduty-org-function"
}

variable "guardduty_org_function_role_name" {
  type        = string
  description = "Name of the role for the GuardDuty Org Function"
  default     = "security-baseline-guardduty-org-function-role"
}

variable "guardduty_org_function_role_path" {
  type        = string
  description = "Path for the role for the GuardDuty Org Function"
  default     = "/"
}

variable "guardduty_org_role_policy_name" {
  type        = string
  description = "Name of the custom policy that allows the function to assume the Org account."
  default     = "security-baseline-guardduty-org-function-policy"
}

variable "guardduty_audit_function_name" {
  type        = string
  description = "Name of the function that applies GuardDuty config"
  default     = "security-baseline-guardduty-audit-function"
}

variable "guardduty_audit_function_role_name" {
  type        = string
  description = "Name of the role for the Guardduty Audit Function"
  default     = "security-baseline-guardduty-audit-function-role"
}

variable "guardduty_audit_function_role_path" {
  type        = string
  description = "Path for the role for the GuardDuty Audit Function"
  default     = "/"
}

variable "event_rule_name" {
  type        = string
  description = "Name of the eventbridge rule that runs the event scheduler"
  default     = "security-baseline-events-rule"
}

variable "event_enabled" {
  type        = bool
  description = "Determines whether an envent is enabled or not"
  default     = true
}

variable "event_executor_policy_name" {
  type        = string
  description = "Name of the event policy that allows it to start the statemachine"
  default     = "security-baseline-events-executor-policy"
}

variable "event_executor_policy_path" {
  type        = string
  description = "Path of the events policy"
  default     = "/"
}

variable "org_management_role" {
  type        = string
  description = "Name of the role used on the org management account for services management"
  default     = "security-baseline-org-role"
}
