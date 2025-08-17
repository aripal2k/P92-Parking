#!/usr/bin/env python3
"""
S3 Static Website Hosting Setup Script for AutoSpot
Configures S3 bucket for hosting Flutter Web frontend
"""

import boto3
import json
import os
import sys
from datetime import datetime


class S3WebsiteSetup:
    def __init__(self):
        self.s3_client = boto3.client(
            "s3",
            region_name=os.getenv("AWS_DEFAULT_REGION", "ap-southeast-2"),
            aws_access_key_id=os.getenv("AWS_ACCESS_KEY_ID"),
            aws_secret_access_key=os.getenv("AWS_SECRET_ACCESS_KEY"),
        )
        self.bucket_name = "autospot-frontend-hosting"
        self.region = os.getenv("AWS_DEFAULT_REGION", "ap-southeast-2")

    def create_bucket(self):
        """Create S3 bucket for hosting"""
        try:
            # Check if bucket already exists
            try:
                self.s3_client.head_bucket(Bucket=self.bucket_name)
                print(f"✅ Bucket '{self.bucket_name}' already exists")
                return True
            except:
                pass

            # Create bucket with location constraint for non-us-east-1 regions
            if self.region != "us-east-1":
                self.s3_client.create_bucket(
                    Bucket=self.bucket_name,
                    CreateBucketConfiguration={"LocationConstraint": self.region},
                )
            else:
                self.s3_client.create_bucket(Bucket=self.bucket_name)

            print(f"✅ Created bucket '{self.bucket_name}'")
            return True

        except Exception as e:
            print(f"❌ Failed to create bucket: {str(e)}")
            return False

    def configure_website_hosting(self):
        """Configure S3 bucket for static website hosting"""
        try:
            website_configuration = {
                "ErrorDocument": {"Key": "index.html"},
                "IndexDocument": {"Suffix": "index.html"},
            }

            self.s3_client.put_bucket_website(
                Bucket=self.bucket_name, WebsiteConfiguration=website_configuration
            )

            print("✅ Configured static website hosting")
            return True

        except Exception as e:
            print(f"❌ Failed to configure website hosting: {str(e)}")
            return False

    def set_bucket_policy(self):
        """Set bucket policy for public read access"""
        try:
            # First disable public access block
            self.s3_client.put_public_access_block(
                Bucket=self.bucket_name,
                PublicAccessBlockConfiguration={
                    "BlockPublicAcls": False,
                    "IgnorePublicAcls": False,
                    "BlockPublicPolicy": False,
                    "RestrictPublicBuckets": False,
                },
            )
            print("✅ Disabled public access block")

            # Then set bucket policy
            bucket_policy = {
                "Version": "2012-10-17",
                "Statement": [
                    {
                        "Sid": "PublicReadGetObject",
                        "Effect": "Allow",
                        "Principal": "*",
                        "Action": "s3:GetObject",
                        "Resource": f"arn:aws:s3:::{self.bucket_name}/*",
                    }
                ],
            }

            self.s3_client.put_bucket_policy(
                Bucket=self.bucket_name, Policy=json.dumps(bucket_policy)
            )

            print("✅ Set bucket policy for public access")
            return True

        except Exception as e:
            print(f"❌ Failed to set bucket policy: {str(e)}")
            return False

    def enable_versioning(self):
        """Enable versioning for rollback capability"""
        try:
            self.s3_client.put_bucket_versioning(
                Bucket=self.bucket_name, VersioningConfiguration={"Status": "Enabled"}
            )

            print("✅ Enabled versioning")
            return True

        except Exception as e:
            print(f"❌ Failed to enable versioning: {str(e)}")
            return False

    def configure_cors(self):
        """Configure CORS for API access"""
        try:
            cors_configuration = {
                "CORSRules": [
                    {
                        "AllowedHeaders": ["*"],
                        "AllowedMethods": ["GET", "HEAD"],
                        "AllowedOrigins": ["*"],
                        "ExposeHeaders": ["ETag"],
                        "MaxAgeSeconds": 3000,
                    }
                ]
            }

            self.s3_client.put_bucket_cors(
                Bucket=self.bucket_name, CORSConfiguration=cors_configuration
            )

            print("✅ Configured CORS")
            return True

        except Exception as e:
            print(f"❌ Failed to configure CORS: {str(e)}")
            return False

    def get_website_url(self):
        """Get the website endpoint URL"""
        website_url = (
            f"http://{self.bucket_name}.s3-website-{self.region}.amazonaws.com"
        )
        return website_url

    def create_cost_analysis(self):
        """Create cost comparison document"""
        cost_analysis = f"""
# AutoSpot Hosting Cost Comparison

## Current Setup (EC2)
- **Instance Type**: t2.micro or similar
- **Monthly Cost**: ~$10-15
- **Storage**: EBS volume included
- **Bandwidth**: Included in instance cost
- **Availability**: ~99.5% (single instance)

## S3 Static Hosting
- **Storage Cost**: $0.023 per GB/month
  - Flutter Web app: ~50MB = $0.001/month
- **Request Cost**: $0.0004 per 1,000 requests
  - Estimated 100k requests/month = $0.04/month
- **Bandwidth Cost**: $0.09 per GB (first 10TB)
  - Estimated 10GB/month = $0.90/month
- **Total Monthly Cost**: ~$1/month
- **Availability**: 99.99% (S3 SLA)

## Savings
- **Monthly Savings**: ~$9-14 (90%+ reduction)
- **Annual Savings**: ~$108-168
- **Better Availability**: 99.99% vs 99.5%

## Additional Benefits
- No server maintenance
- Automatic scaling
- Built-in versioning
- Global edge locations (with CloudFront)

Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
"""

        with open("/tmp/s3_cost_analysis.md", "w") as f:
            f.write(cost_analysis)

        print("✅ Created cost analysis document")
        return True


def main():
    if not os.getenv("AWS_ACCESS_KEY_ID") or not os.getenv("AWS_SECRET_ACCESS_KEY"):
        print(
            "❌ AWS credentials not found. Please set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables."
        )
        sys.exit(1)

    setup = S3WebsiteSetup()

    print("🚀 Setting up S3 static website hosting for AutoSpot...")
    print(f"📦 Bucket name: {setup.bucket_name}")
    print(f"🌏 Region: {setup.region}")
    print()

    # Run setup steps
    steps = [
        ("Creating S3 bucket", setup.create_bucket),
        ("Configuring website hosting", setup.configure_website_hosting),
        ("Setting bucket policy", setup.set_bucket_policy),
        ("Enabling versioning", setup.enable_versioning),
        ("Configuring CORS", setup.configure_cors),
        ("Creating cost analysis", setup.create_cost_analysis),
    ]

    for step_name, step_func in steps:
        print(f"\n{step_name}...")
        if not step_func():
            print(f"\n❌ Setup failed at: {step_name}")
            sys.exit(1)

    # Print summary
    website_url = setup.get_website_url()
    print("\n" + "=" * 50)
    print("✨ S3 Website Hosting Setup Complete!")
    print("=" * 50)
    print(f"\n📌 Website URL: {website_url}")
    print(f"📦 Bucket Name: {setup.bucket_name}")
    print(f"📊 Cost Analysis: /tmp/s3_cost_analysis.md")
    print("\n🎯 Next Steps:")
    print("1. Run deploy_to_s3.py to upload your Flutter web build")
    print("2. Update your domain DNS to point to this S3 bucket")
    print("3. (Optional) Set up CloudFront for HTTPS and CDN")
    print("\n💡 Demo Talking Points:")
    print("- 99.99% availability guarantee")
    print("- 90%+ cost reduction")
    print("- Automatic scaling")
    print("- Version control built-in")


if __name__ == "__main__":
    main()
