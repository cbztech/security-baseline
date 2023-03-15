# security-baseline

This project applies a security-baseline to an AWS organization. The state-machine runs using an eventbridge rule so that configuration is checked on an interval and re-applied. Currently, the baseline supports the following services:

- Amazon GuardDuty

## Getting Started
You will need to setup the following before running this SAM application.

1. Configure an assumable role on your Org Master Payer account to allow the Security/Audit account to manage GuardDuty via cross account access

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::123456789:root"
            },
            "Action": "sts:AssumeRole",
            "Condition": {}
        }
    ]
} 
```
2. Attach the following policies to the new role
  - `AmazonGuardDutyFullAccess`
  - `AWSOrganizationsFullAccess`
2. Ensure you have cross-account deployment access for Terraform, as multiple AWS providers are supported for security-baseline
2. Update the `security-baseline/infra/providers.tf` following the example in `security-baseline/infra/providers.tf.example` with deployment roles
2. Update `security-baseline/infra/terraform.tf` with relevent bucket name and key
2. Update any changes to `security-baseline/config/config.json` for the used regions, GuardDuty detectors configuration, and desired accounts to ignore.

## Deployment
Project is easily managed from local command line deployment, but may need to be tweaked to fit a pipeline with Github Actions, Jenkins, CircleCi, etc.

Deploy from local cli with regular terraform commands:
```bash
terraform apply
```

## Clean Up
If deployed via command line, easy to clean up with regular terraform commands
```bash
terraform destroy
```

Clean up the following:
1. Any roles created required to run cross-account terraform
2. Terraform state and bucket in S3

## Future
Other services that could be added for continual checking/management:
- Security Hub
- AWS Account & Contacts Management
- SCP organization

#### Attribution
*Name shamefully stolen from a similar project authored by Rich Adams with Ruby. :D*
