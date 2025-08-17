#!/bin/bash

# Create CloudWatch log group
aws logs create-log-group --log-group-name /aws/ecs/autospot-backend --region ap-southeast-2

# Create retention policy (7 days)
aws logs put-retention-policy --log-group-name /aws/ecs/autospot-backend --retention-in-days 7 --region ap-southeast-2

echo "CloudWatch log group created successfully!"