# security-baseline

This project applies a security-baseline to an AWS organization. The state-machine runs using an eventbridge rule so that configuration is checked on an interval and re-applied. Currently, the baseline supports the following services:

- Amazon GuardDuty

## Getting Started
You will need to setup the following before running this SAM application.

1. Configure an assumable role on your Org Master Payer account to allow the Security/Audit account to manage GuardDuty

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
2. Move config.example.json to config.json in `security-baseline/functions/guardduty_org` and `security-baseline/functions/guardduty_audit`
2. Add the role ARN to the `guardduty_org/config.json`
2. Add required regions to the `guardduty_org/config.json`
2. Add the GuardDuty Detector configuration, any accounts to ignore, and the publishing frequency to the `guardduty_audit/config.json`
2. Update the `template.yaml` in the `GuardDutyOrgFunction` section with the ARN with the assumable role

## Using SAM

This project contains source code and supporting files for a serverless application that you can deploy with the SAM CLI. It includes the following files and folders:

- functions - Code for the application's Lambda functions to check the value of, buy, or sell shares of a stock.
- statemachines - Definition for the state machine that orchestrates the stock trading workflow.
- template.yaml - A template that defines the application's AWS resources.

## Deploy the application

The Serverless Application Model Command Line Interface (SAM CLI) is an extension of the AWS CLI that adds functionality for building and testing Lambda applications. It uses Docker to run your functions in an Amazon Linux environment that matches Lambda.

To use the SAM CLI, you need the following tools:

* SAM CLI - [Install the SAM CLI](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-cli-install.html)
* [Python 3 installed](https://www.python.org/downloads/)
* Docker - [Install Docker community edition](https://hub.docker.com/search/?type=edition&offering=community)

To build and deploy your application for the first time, run the following in your shell:

```bash
sam build --use-container
sam deploy --guided
```

The first command will build the source of your application. The second command will package and deploy your application to AWS, with a series of prompts:

* **Stack Name**: The name of the stack to deploy to CloudFormation. This should be unique to your account and region, and a good starting point would be something matching your project name.
* **AWS Region**: The AWS region you want to deploy your app to.
* **Confirm changes before deploy**: If set to yes, any change sets will be shown to you before execution for manual review. If set to no, the AWS SAM CLI will automatically deploy application changes.
* **Allow SAM CLI IAM role creation**: Many AWS SAM templates, including this example, create AWS IAM roles required for the AWS Lambda function(s) included to access AWS services. By default, these are scoped down to minimum required permissions. To deploy an AWS CloudFormation stack which creates or modifies IAM roles, the `CAPABILITY_IAM` value for `capabilities` must be provided. If permission isn't provided through this prompt, to deploy this example you must explicitly pass `--capabilities CAPABILITY_IAM` to the `sam deploy` command.
* **Save arguments to samconfig.toml**: If set to yes, your choices will be saved to a configuration file inside the project, so that in the future you can just re-run `sam deploy` without parameters to deploy changes to your application.

## Use the SAM CLI to build locally

Build the Lambda functions in your application with the `sam build --use-container` command.

```bash
$ sam build --use-container
```

The SAM CLI installs dependencies defined in `functions/*/requirements.txt`, creates a deployment package, and saves it in the `.aws-sam/build` folder.

## Cleanup

To delete the sample application that you created, use the AWS CLI. Assuming you used your project name for the stack name, you can run the following:

```bash
aws cloudformation delete-stack --stack-name security-baseline
```
This only cleans up the cloudformation stack and does not deactivate all enabled services. Other cleanup may be required.

*Name shamefully stolen from a similar project authored by Rich Adams. :D*
