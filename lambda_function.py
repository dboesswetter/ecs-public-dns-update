import boto3
import json
import os

def lambda_handler(event, context):
    if event["detail"]["desiredStatus"] == "RUNNING" and event["detail"]["lastStatus"] == "RUNNING":

        # find the ENI attached to this task ...
        attachment = [x for x in event["detail"]["attachments"] if x["type"] == "eni"]
        # ... and its ID
        eni_id = [x["value"] for x in attachment[0]["details"] if x["name"] == "networkInterfaceId"][0]

        # describe the ENI ...
        ec2 = boto3.client("ec2")
        response = ec2.describe_network_interfaces(
            NetworkInterfaceIds=[
                eni_id
            ]
        )

        # ... and retrieve its public IP
        public_ip = response["NetworkInterfaces"][0]['Association']['PublicIp']

        # UPSERT a record in Route53 in the zone and name specified in the environment
        # and the IP address that we just found
        route53 = boto3.client("route53")
        response = route53.change_resource_record_sets(
            HostedZoneId=os.environ["HOSTED_ZONE_ID"],
            ChangeBatch={
                'Comment': 'daniel testet',
                'Changes': [
                    {
                        'Action': 'UPSERT',
                        'ResourceRecordSet': {
                            'Name': os.environ["DNS_NAME"],
                            'Type': 'A',
                            'TTL': int(os.getenv("DNS_TTL")) or 300,
                            'ResourceRecords': [
                                {
                                    'Value': public_ip
                                },
                            ],
                        }
                    },
                ]
            }
        )
        print(f"Successfully updated {os.environ['DNS_NAME']} to {public_ip} in zone {os.environ['HOSTED_ZONE_ID']}")
    else:
        print("Wrong event, doing nothing")

# dirty little test. it will probably fail for you because the ENI and the zone are mine
# and the ENI specified in the test file probably does not exist any longer.
if __name__ == "__main__":
    f = open("eventbridge.json")
    event = json.loads(f.read())
    os.environ["HOSTED_ZONE_ID"] = "Z043591611RUK2FNP2BI1"
    os.environ["DNS_NAME"] = "abc.nadiki.work"
    lambda_handler(event, {})
    f.close()

