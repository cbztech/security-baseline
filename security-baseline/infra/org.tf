resource "aws_iam_role" "security_baseline_org_role" {
  provider = aws.org
  name     = "security-baseline-org-role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "${module.guardduty_org_function.lambda_role_arn}"
        },
        "Action" : "sts:AssumeRole",
        "Condition" : {}
      }
    ]
  })
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "security_baseline_org_guardduty" {
  provider   = aws.org
  role       = aws_iam_role.security_baseline_org_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonGuardDutyFullAccess"
}

resource "aws_iam_role_policy_attachment" "security_baseline_org_managed_policies_organization" {
  provider   = aws.org
  role       = aws_iam_role.security_baseline_org_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSOrganizationsFullAccess"
}
