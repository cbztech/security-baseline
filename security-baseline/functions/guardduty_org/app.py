import boto3
import botocore
import json
import os
import urllib3

# get from env, since terraform builds this
org_role = os.getenv("ORG_ROLE")
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

# Get the current account ID as this is the delegated administrator
sts = boto3.client("sts")
response = sts.get_caller_identity()
delegated_administrator_id = response["Account"]
print(f"The Delegated Admin Account : {delegated_administrator_id}")


def get_guardduty_enabed(client):
    print("Checking for Detector")
    response = client.list_detectors()
    if response["DetectorIds"] == []:
        exists = False
        detector_id = []
    elif response["DetectorIds"] != []:
        exists = True
        detector_id = response["DetectorIds"]
    return {"exists": exists, "DetectorIds": detector_id}


def get_guardduty_service(client):
    service_principals = []
    check_enabled_service = client.list_aws_service_access_for_organization()
    for service in check_enabled_service["EnabledServicePrincipals"]:
        service_principals.append(service["ServicePrincipal"])

    if "guardduty.amazonaws.com" not in service_principals:
        print("Service not enabled.")
        set_guardduty_service(client)
        print("Service Successfully Enabled.")
        return "enabled"
    else:
        print("The guardduty service prinicpal is already enabled.")
        pass
    return "exists"


def get_active_accounts(client):
    print("Getting Active Accounts")
    try:
        response = client.list_accounts()
        accounts = {"Accounts": []}
        for account in response["Accounts"]:
            if account["Status"] == "ACTIVE":
                if account["Id"] != delegated_administrator_id:
                    accounts["Accounts"].append(
                        {"AccountId": account["Id"], "Email": account["Email"]}
                    )
                else:
                    print(
                        f"Delegated Administrator ({delegated_administrator_id}) SKIPPED"
                    )
            else:
                print(f'Found INACTIVE ACCOUNT : {account["Id"]}')
        return accounts
    except botocore.exceptions.ClientError as err:
        print(f"ERROR: {err}")
    raise


def get_delegated_administrator(client):
    print("Getting Delegated Administrators")
    response = client.list_delegated_administrators(
        ServicePrincipal="guardduty.amazonaws.com"
    )
    if response["DelegatedAdministrators"] == []:
        return False
    elif response["DelegatedAdministrators"][0]["Id"] == delegated_administrator_id:
        return True
    else:
        return False


def get_organization_admin(client):
    print("Getting Organization Admins")
    response = client.list_organization_admin_accounts()
    if response["AdminAccounts"] == []:
        return False
    else:
        exists = response["AdminAccounts"][0]["AdminAccountId"]
        return exists


def set_delegated_administrator(client):
    print("Setting Delegated Administrators")
    try:
        response = client.register_delegated_administrator(
            AccountId=delegated_administrator_id,
            ServicePrincipal="guardduty.amazonaws.com",
        )
        return True
    except botocore.exceptions.ClientError as err:
        print(f"ERROR: {err}")
        raise


def set_guardduty_service(client):
    try:
        service = client.enable_aws_service_access(
            ServicePrincipal="guardduty.amazonaws.com"
        )
        return
    except botocore.exceptions.ClientError as err:
        print(f"ERROR: {err}")
        raise


def set_organization_admin(client):
    print("Setting the Organization Admin")
    try:
        response = client.enable_organization_admin_account(
            AdminAccountId=delegated_administrator_id
        )
        return "Success"
    except botocore.exceptions.ClientError as err:
        print(f"ERROR: {err}")
        raise


def set_guardduty_enabled(client):
    response = client.create_detector(
        Enable=True,
        FindingPublishingFrequency="SIX_HOURS",
    )
    return response


def lambda_handler(event, context):
    ### Load Parameter Store values from extension
    print("Loading AWS Systems Manager Parameter Store values from " + ssm_path)
    parameter_url = ('/systemsmanager/parameters/get?name=' + ssm_path)

    config = json.loads(retrieve_extension_value(parameter_url)['Parameter']['Value'])

    # Assume the Org GuardDuty-Monitor Role
    sts = boto3.client("sts")

    # Get the account ID for the delegated admin (this account)
    response = sts.get_caller_identity()
    delegated_administrator_id = response["Account"]

    try:
        assumed_role_object = sts.assume_role(
            RoleArn=org_role,
            RoleSessionName="security-baseline",
        )
    except botocore.exceptions.ClientError as err:
        print(f"ERROR: {err}")
        raise

    # Get the credentials object for the guardduty monitor role
    credentials = assumed_role_object["Credentials"]

    # Enable the service guardduty.amazonaws.com in Org
    ## Setup Organization Boto3 Client
    org = boto3.client(
        "organizations",
        aws_access_key_id=credentials["AccessKeyId"],
        aws_secret_access_key=credentials["SecretAccessKey"],
        aws_session_token=credentials["SessionToken"],
    )
    # Check if the service is enabled, if not enable it.
    get_guardduty_service(org)

    # Get all active accounts
    active_regions = config["configuration"]["regions"]
    accounts = get_active_accounts(org)

    # For each region -> set delegated Administrator
    for region in active_regions:
        # Create GuardDuty Client for region
        guardduty = boto3.client(
            "guardduty",
            aws_access_key_id=credentials["AccessKeyId"],
            aws_secret_access_key=credentials["SecretAccessKey"],
            aws_session_token=credentials["SessionToken"],
            region_name=region,
        )

        organization_admin_account_exists = get_organization_admin(guardduty)
        if organization_admin_account_exists == False:
            set_organization_admin(guardduty)
        else:
            print(f"Organization Account ({organization_admin_account_exists}) Exists!")

        # Create Organizations Client for region
        org = boto3.client(
            "organizations",
            aws_access_key_id=credentials["AccessKeyId"],
            aws_secret_access_key=credentials["SecretAccessKey"],
            aws_session_token=credentials["SessionToken"],
            region_name=region,
        )

        delegated_admin_exist = get_delegated_administrator(org)
        if delegated_admin_exist is True:
            print(f"Delegated Admin Already Exists")
        else:
            print("Creating Delegated Admin")
            set_delegated_administrator(org)

        """
        So this is a dumb thing where the org account 
        has to have a detector enabled before it 
        can be added as member account to the delegated 
        administrator. We then update the detector from 
        the guardduty_audit function.
        """

        org_guardduty_enabled = get_guardduty_enabed(guardduty)
        print(org_guardduty_enabled)
        if org_guardduty_enabled["exists"] != True:
            set_guardduty_enabled(guardduty)
            print("Detector Created!")
        else:
            print("Detector already setup")

    # Return Lambda
    return {
        "Data": {
            "Regions": active_regions,
            "Accounts": accounts["Accounts"],
        }
    }
