import boto3
import botocore
import json
import os
import urllib3

# Get Env Vars
ssm_path = os.getenv("SSM_PATH")
port = os.getenv("PARAMETERS_SECRETS_EXTENSION_HTTP_PORT")
aws_session_token = os.getenv("AWS_SESSION_TOKEN")

# http pool for AWS-Parameters-and-Secrets Extension
http = urllib3.PoolManager()

# Retrieves SSM values from the AWS-Parameters-and-Secrets Extension
def retrieve_extension_value(url): 
    url = ('http://localhost:' + port + url)
    headers = { "X-Aws-Parameters-Secrets-Token": aws_session_token }
    response = http.request("GET", url, headers=headers)
    response = json.loads(response.data)
    return response


def get_detector(client):
    print("Checking for Detector")
    try:
        response = client.list_detectors()
        if response["DetectorIds"] == []:
            exists = False
            detector_id = []
        elif response["DetectorIds"] != []:
            exists = True
            detector_id = response["DetectorIds"]
        return {"exists": exists, "DetectorIds": detector_id}
    except botocore.exceptions.ClientError as err:
        print(f"ERROR: {err}")
        raise


def set_member_account(client, detector_id, account_id, account_email):
    try:
        response = client.create_members(
            DetectorId=detector_id,
            AccountDetails=[
                {"AccountId": account_id, "Email": account_email},
            ],
        )
        return
    except botocore.exceptions.ClientError as err:
        print(f"ERROR: {err}")
        raise


def set_detector(client, data, publishing_frequency):
    print("Set the Initial Detector")
    response = client.create_detector(
        Enable=True,
        FindingPublishingFrequency=publishing_frequency,
        DataSources={
            "S3Logs": {"Enable": data["s3"]},
            "Kubernetes": {"AuditLogs": {"Enable": data["kubernetes"]}},
        },
    )
    return response


def set_update_detector(client, detector_id, data, publishing_frequency):
    response = client.update_detector(
        DetectorId=detector_id,
        Enable=True,
        FindingPublishingFrequency=publishing_frequency,
        DataSources={
            "S3Logs": {"Enable": data["s3"]},
            "Kubernetes": {"AuditLogs": {"Enable": data["kubernetes"]}},
        },
    )
    return response


def set_organization_config(client, detector_id, data):
    response = client.update_organization_configuration(
        DetectorId=detector_id,
        AutoEnable=True,
        DataSources={
            "S3Logs": {"AutoEnable": data["s3"]},
            "Kubernetes": {"AuditLogs": {"AutoEnable": data["kubernetes"]}},
        },
    )
    return response


def lambda_handler(event, context):
    ### Load Parameter Store values from extension
    print("Loading AWS Systems Manager Parameter Store values from " + ssm_path)
    parameter_url = ('/systemsmanager/parameters/get?name=' + ssm_path)

    config = json.loads(retrieve_extension_value(parameter_url)['Parameter']['Value'])

    # Set Regions and Accounts vars from event data
    regions = event["Data"]["Regions"]
    accounts = event["Data"]["Accounts"]
    ignore_accounts = config["configuration"]["ignore_accounts"]
    publishing_frequency = config["configuration"]["publishing_frequency"]

    detector = {
        "s3": config["configuration"]["detector"]["s3"],
        "kubernetes": config["configuration"]["detector"]["kubernetes"],
    }

    org_detector = {
        "s3": config["configuration"]["auto_enable"]["s3"],
        "kubernetes": config["configuration"]["auto_enable"]["kubernetes"],
    }

    # for each region in Audit Account
    for region in regions:
        # Create Boto3 Client
        guardduty = boto3.client("guardduty", region_name=region)

        # Check if a detector exists
        check_if_detector_exists = get_detector(guardduty)
        if check_if_detector_exists["exists"] != True:
            set_detector(guardduty, detector, publishing_frequency)
            detector_id = ""
        else:
            detector_id = check_if_detector_exists["DetectorIds"][0]
            print(f"Detector ({detector_id}) is alredy created")

        # Validate the detector has desired config
        print("Create/Update Detector config with current config")
        update_detector = set_update_detector(guardduty, detector_id, detector, publishing_frequency)

        print("Create/Update the organization detector with current config")
        organization_config = set_organization_config(guardduty, detector_id, org_detector)

        # Create members
        for account in accounts:
            if account["AccountId"] not in ignore_accounts:
                set_member_account(
                    guardduty, detector_id, account["AccountId"], account["Email"]
                )
                print(f'Added {account["Email"]} ({account["AccountId"]}) in {region}')
            else:
                print(f'Ignoring [{account["AccountId"]}] based on config')
    return {"msg": "GuardDuty Run Complete."}
