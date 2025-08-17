# S3 Static Website Hosting for AutoSpot

## Overview
This guide explains how to deploy the AutoSpot Flutter Web frontend to AWS S3 for static website hosting.

## Benefits
- **99.99% Availability**: S3 SLA guarantee
- **90%+ Cost Reduction**: ~$1/month vs ~$10-15/month for EC2
- **Auto-Scaling**: Handles any traffic automatically
- **Zero Maintenance**: No servers to manage

## Prerequisites
1. AWS Account with IAM user
2. AWS CLI configured or AWS credentials
3. Flutter SDK installed (for building)

## Quick Start

### 1. Set up AWS Credentials
```bash
export AWS_ACCESS_KEY_ID=your_access_key
export AWS_SECRET_ACCESS_KEY=your_secret_key
export AWS_DEFAULT_REGION=ap-southeast-2
```

### 2. Create S3 Bucket and Configure
```bash
python scripts/setup_s3_hosting.py
```

This will:
- Create S3 bucket `autospot-frontend-hosting`
- Enable static website hosting
- Set public access policies
- Enable versioning
- Configure CORS

### 3. Build and Deploy Flutter Web
```bash
python scripts/deploy_to_s3.py
```

This will:
- Build Flutter web app in release mode
- Upload all files to S3
- Set appropriate cache headers
- Provide the website URL

## Demo Talking Points

### Cost Comparison
- **EC2 Hosting**: ~$10-15/month
- **S3 Hosting**: ~$1/month
- **Savings**: 90%+ reduction

### Performance
- Global edge locations ready (add CloudFront)
- Automatic scaling
- No server bottlenecks

### Reliability
- 99.99% uptime SLA
- Multi-AZ redundancy
- Automatic failover

## Testing

1. Visit the S3 website URL:
   ```
   http://autospot-frontend-hosting.s3-website-ap-southeast-2.amazonaws.com
   ```

2. Check CORS is working:
   - Open browser console
   - Should see API calls to https://api.autospot.it.com

3. Test Redis cache performance:
   ```bash
   python scripts/demo_redis_performance.py
   ```

## Advanced Setup (Optional)

### Add CloudFront CDN
1. Create CloudFront distribution
2. Point to S3 bucket
3. Get HTTPS and global CDN

### Custom Domain
1. Update Route 53 DNS
2. Point to CloudFront or S3

## Rollback
S3 versioning is enabled, so you can:
1. Go to S3 console
2. View object versions
3. Restore previous version

## Cost Breakdown
- Storage: $0.023/GB/month (app is ~50MB = $0.001)
- Requests: $0.0004 per 1,000 requests
- Data Transfer: $0.09/GB (first 10TB)
- **Total**: ~$1/month for typical usage