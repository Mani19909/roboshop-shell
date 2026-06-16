#!/bin/bash

instances=("mongodb" "redis" "mysql" "rabbitmq" "catalogue" "user" "cart" "shipping" "payment" "web")
domain_name="daws.info"
hosted_zone_id="Z06516712DQCAUJQEM73K"
for name in ${instances[@]}; do
    if [ $name == "shipping" ] || [ $name == "mysql" ]
    then
        instance_type="t3.medium"
    else
        instance_type="t3.micro"
    fi
    echo "creating instance for: $name with instance type: $instance_type"
    instance_id=$(aws ec2 run-instances --image-id ami-0220d79f3f480ecf5 --instance-type $instance_type --security-group-ids sg-07eb8366c0af7070b --subnet-id subnet-0541e90ebd6e0c784 --query 'Instances[0].InstanceId' --output text)
    echo "Instance created for: $name"

    aws ec2 create-tags --resources $instance_id --tags key=Name,value=$name

    private_ip=$(aws ec2 describe-instances --instance-ids i-0b9d7fdcd7c44cdd5 --query 'Reservations[0].Instances[0].[PrivateIpAddress]' --output text)

    if [ $name == "web" ]
    then
        aws ec2 wait instance-running --instance-ids $instance_id
        public_ip=$(aws ec2 describe-instances --instance-ids $instance_id --query 'Reservations[0].Instances[0].[PublicIpAddress]' --output text)
        ip_to_use=$public_ip
    else
        private_ip=$(aws ec2 describe-instances --instance-ids $instance_id --query 'Reservations[0].Instances[0].[PrivateIpAddress]' --output text)
        ip_to_use=$private_ip
    fi

    aws route53 change-resource-record-sets --hosted-zone-id $hosted_zone_id --change-batch '
    {   
        "Comment": "Creating a record set for '$name'"
        "Changes": [
          {
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "'$name.$domain_name'",
                "Type": "A",
                "TTL": 1,
                "ResourceRecords": [
                    {
                        "Value": "'$ip_to_use'"
                    }
                ]
            }
        }
    ]
    }'   
done