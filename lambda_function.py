import boto3
import json
import os

def lambda_handler(event, context):

    attachment = [x for x in event["attachments"] if x["type"] == "eni"]
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

    # UPSERT a record in Route53 in the zone and name specified in the event
    # and the IP address that we just found
    route53 = boto3.client("route53")
    response = route53.change_resource_record_sets(
        HostedZoneId=event["hosted_zone_id"],
        ChangeBatch={
            'Comment': 'daniel testet',
            'Changes': [
                {
                    'Action': 'UPSERT',
                    'ResourceRecordSet': {
                        'Name': event["dns_name"],
                        'Type': 'A',
                        'TTL': int(event["dns_ttl"]),
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
    print(f"Successfully updated {event['dns_name']} to {public_ip} in zone {event['hosted_zone_id']}")

# dirty little test. it will probably fail for you because the ENI and the zone are mine
# and the ENI specified in the test file probably does not exist any longer.
if __name__ == "__main__":
    event = {
        "attachments": [
            {
                "type": "eni",
                "details": [
                    {
                        "name": "networkInterfaceId",
                        "value": "eni-02c1ac868a8fc80b6"
                    }
                ]
            }
        ],
        "hosted_zone_id": "Z043591611RUK2FNP2BI1",
        "dns_name": "abc.nadiki.work",
        "dns_ttl": 300
    }
    lambda_handler(event, {})
