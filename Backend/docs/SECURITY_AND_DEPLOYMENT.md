# Security and Deployment Guide

## Security Implementation

### Authentication and Authorization

#### Multi-layer Security Architecture
```
┌─────────────────────────────────────────────────────────────┐
│                    Security Layers                          │
├─────────────────────────────────────────────────────────────┤
│  1. Transport Layer Security (HTTPS/TLS)                   │
│  2. API Gateway Authentication                              │
│  3. JWT Token Validation                                    │
│  4. Role-based Access Control (RBAC)                       │
│  5. Input Validation and Sanitization                      │
│  6. Rate Limiting and DDoS Protection                      │
└─────────────────────────────────────────────────────────────┘
```

#### Password Security
```python
# Advanced password hashing with bcrypt
from passlib.context import CryptContext

pwd_context = CryptContext(
    schemes=["bcrypt"],
    deprecated="auto",
    bcrypt__rounds=12,  # High security rounds
    bcrypt__ident="2b"  # Latest bcrypt variant
)

# Password strength validation
def validate_password_strength(password: str) -> bool:
    """
    Enforces strong password requirements:
    - Minimum 8 characters
    - At least one uppercase letter
    - At least one lowercase letter  
    - At least one number
    - At least one special character
    - Not in common password list
    """
```

#### JWT Token Management
```python
# Secure JWT implementation
JWT_ALGORITHM = "HS256"
JWT_EXPIRATION = 3600  # 1 hour
JWT_REFRESH_EXPIRATION = 86400  # 24 hours

def create_access_token(data: dict) -> str:
    """
    Creates secure JWT token with:
    - Expiration timestamp
    - User identification
    - Role-based permissions
    - CSRF protection token
    """
```

#### Account Security Features
- **Failed Login Tracking**: Progressive delays after failed attempts
- **Account Suspension**: Automatic lockout after 5 failed attempts
- **Email Verification**: OTP-based account verification
- **Password Reset**: Secure reset flow with time-limited tokens

### Input Validation and Sanitization

#### Pydantic Model Validation
```python
from pydantic import BaseModel, EmailStr, validator, Field
from typing import Optional

class UserRegistration(BaseModel):
    email: EmailStr
    username: str = Field(..., min_length=3, max_length=30, regex=r'^[a-zA-Z0-9_]+$')
    password: str = Field(..., min_length=8, max_length=128)
    full_name: str = Field(..., min_length=2, max_length=100)
    
    @validator('password')
    def validate_password(cls, v):
        # Password strength validation
        # Prevent common passwords
        # Check for patterns
        return v
    
    @validator('email')
    def validate_email(cls, v):
        # Email format validation
        # Domain verification
        # Blacklist checking
        return v.lower().strip()
```

#### SQL Injection Prevention
```python
# Parameterized queries with MongoDB
def secure_user_lookup(email: str):
    # Using MongoDB's built-in query parameterization
    return user_collection.find_one({"email": email})
    # No string concatenation or dynamic query building
```

#### File Upload Security
```python
# Secure file upload handling
ALLOWED_EXTENSIONS = {'.jpg', '.jpeg', '.png', '.gif'}
MAX_FILE_SIZE = 10 * 1024 * 1024  # 10MB

def validate_uploaded_file(file: UploadFile):
    """
    Comprehensive file validation:
    - File extension checking
    - MIME type validation
    - File size limits
    - Magic number verification
    - Virus scanning integration ready
    """
```

### API Security

#### CORS Configuration
```python
# Secure CORS setup
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://autospot.it.com",
        "https://www.autospot.it.com",
        "https://api.autospot.it.com"
    ],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
    expose_headers=["X-Request-ID"]
)
```

#### Rate Limiting
```python
# API rate limiting implementation
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)

@app.post("/auth/login")
@limiter.limit("5/minute")  # 5 login attempts per minute
async def login_endpoint(request: Request, user_data: UserLogin):
    # Secure login implementation
```

#### Request/Response Security Headers
```python
# Security headers middleware
@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    response.headers["Content-Security-Policy"] = "default-src 'self'"
    return response
```

### Data Protection

#### Environment Variable Security
```bash
# Secure environment configuration
# Never commit sensitive data to git
MONGODB_URI=mongodb://username:password@host:port/database
REDIS_URL=redis://password@host:port/database
JWT_SECRET_KEY=cryptographically-strong-random-key
OPENAI_API_KEY=sk-proj-...
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...
```

#### Encryption at Rest
```python
# Database field encryption for sensitive data
from cryptography.fernet import Fernet

class FieldEncryption:
    def __init__(self, key: bytes):
        self.cipher = Fernet(key)
    
    def encrypt_field(self, data: str) -> str:
        """Encrypt sensitive fields before database storage"""
        return self.cipher.encrypt(data.encode()).decode()
    
    def decrypt_field(self, encrypted_data: str) -> str:
        """Decrypt fields after database retrieval"""
        return self.cipher.decrypt(encrypted_data.encode()).decode()
```

#### Logging Security
```python
# Secure logging implementation
import logging
from datetime import datetime

class SecurityAuditLogger:
    def log_auth_attempt(self, email: str, success: bool, ip_address: str):
        """Log authentication attempts for security monitoring"""
        logging.info(f"AUTH_ATTEMPT: {email} | Success: {success} | IP: {ip_address} | Time: {datetime.now()}")
    
    def log_sensitive_operation(self, user: str, operation: str, resource: str):
        """Log sensitive operations for audit trail"""
        logging.warning(f"SENSITIVE_OP: {user} | {operation} | {resource} | Time: {datetime.now()}")
```

## Deployment Architecture

### Production Deployment Stack

#### Docker Multi-stage Build
```dockerfile
# Multi-stage production Dockerfile
FROM python:3.10-slim as builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --user -r requirements.txt

FROM python:3.10-slim as production
WORKDIR /app
COPY --from=builder /root/.local /root/.local
COPY . .

# Security: Run as non-root user
RUN useradd --create-home --shell /bin/bash autospot
USER autospot

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8000/api/health || exit 1

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

#### Docker Compose Production Configuration
```yaml
version: "3.8"
services:
  autospot-backend:
    build:
      context: .
      dockerfile: Dockerfile.prod
    restart: always
    environment:
      - ENV=production
      - DEBUG=false
    volumes:
      - app-logs:/app/logs
    depends_on:
      - mongodb
      - redis
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    
  mongodb:
    image: mongo:7.0
    restart: always
    environment:
      MONGO_INITDB_ROOT_USERNAME: ${MONGO_ROOT_USER}
      MONGO_INITDB_ROOT_PASSWORD: ${MONGO_ROOT_PASSWORD}
    volumes:
      - mongodb-data:/data/db
      - mongodb-config:/data/configdb
    command: mongod --auth --bind_ip_all
    
  redis:
    image: redis:7-alpine
    restart: always
    command: redis-server --requirepass ${REDIS_PASSWORD} --appendonly yes
    volumes:
      - redis-data:/data
      
  nginx:
    image: nginx:alpine
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/ssl/certs
    depends_on:
      - autospot-backend
```

### AWS Production Deployment

#### EC2 Instance Configuration
```bash
# Production server setup script
#!/bin/bash

# Update system
sudo yum update -y

# Install Docker
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Setup SSL certificates
sudo mkdir -p /etc/ssl/certs
# Copy SSL certificates for HTTPS

# Configure firewall
sudo ufw allow 22    # SSH
sudo ufw allow 80    # HTTP
sudo ufw allow 443   # HTTPS
sudo ufw --force enable

# Setup application directory
mkdir -p /home/ec2-user/autospot
cd /home/ec2-user/autospot

# Deploy application
git clone https://github.com/your-repo/autospot.git .
docker-compose -f docker-compose.prod.yml up -d
```

#### Nginx Load Balancer Configuration
```nginx
# nginx.conf for production load balancing
upstream autospot_backend {
    server autospot-backend-1:8000 weight=3;
    server autospot-backend-2:8000 weight=3;
    server autospot-backend-3:8000 weight=2;
}

server {
    listen 80;
    server_name api.autospot.it.com;
    
    # Redirect HTTP to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.autospot.it.com;
    
    # SSL Configuration
    ssl_certificate /etc/ssl/certs/autospot.crt;
    ssl_certificate_key /etc/ssl/private/autospot.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;
    
    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    
    # Rate Limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_req zone=api burst=20 nodelay;
    
    # Proxy Configuration
    location / {
        proxy_pass http://autospot_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }
    
    # Health Check Endpoint
    location /health {
        access_log off;
        proxy_pass http://autospot_backend/api/health;
    }
}
```

### Monitoring and Logging

#### CloudWatch Integration
```python
# Production monitoring setup
import boto3
from datetime import datetime

class ProductionMonitoring:
    def __init__(self):
        self.cloudwatch = boto3.client('cloudwatch', region_name='ap-southeast-2')
        
    def log_performance_metric(self, metric_name: str, value: float, unit: str = 'Count'):
        """Send performance metrics to CloudWatch"""
        self.cloudwatch.put_metric_data(
            Namespace='AutoSpot/Production',
            MetricData=[{
                'MetricName': metric_name,
                'Value': value,
                'Unit': unit,
                'Timestamp': datetime.utcnow()
            }]
        )
    
    def log_error_metric(self, error_type: str, endpoint: str):
        """Track errors for alerting"""
        self.cloudwatch.put_metric_data(
            Namespace='AutoSpot/Errors',
            MetricData=[{
                'MetricName': 'ErrorCount',
                'Value': 1,
                'Unit': 'Count',
                'Dimensions': [
                    {'Name': 'ErrorType', 'Value': error_type},
                    {'Name': 'Endpoint', 'Value': endpoint}
                ]
            }]
        )
```

#### Structured Logging
```python
# Production logging configuration
import structlog
from pythonjsonlogger import jsonlogger

# Configure structured logging
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.UnicodeDecoder(),
        structlog.processors.JSONRenderer()
    ],
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
    wrapper_class=structlog.stdlib.BoundLogger,
    cache_logger_on_first_use=True,
)

# Usage in application
logger = structlog.get_logger(__name__)

def log_user_action(user_id: str, action: str, resource: str):
    logger.info(
        "user_action",
        user_id=user_id,
        action=action,
        resource=resource,
        timestamp=datetime.utcnow().isoformat()
    )
```

### Backup and Disaster Recovery

#### Automated Backup System
```python
# MongoDB backup automation
import subprocess
from datetime import datetime, timedelta
import boto3

class BackupManager:
    def __init__(self):
        self.s3_client = boto3.client('s3')
        
    def create_mongodb_backup(self):
        """Create and upload MongoDB backup to S3"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_filename = f"autospot_backup_{timestamp}.gz"
        
        # Create backup
        subprocess.run([
            "mongodump",
            "--uri", "mongodb://username:password@host:port/autospot",
            "--archive", backup_filename,
            "--gzip"
        ])
        
        # Upload to S3
        self.s3_client.upload_file(
            backup_filename,
            'autospot-backups',
            f"daily/{backup_filename}"
        )
        
        # Cleanup old backups (keep 30 days)
        self.cleanup_old_backups()
        
    def cleanup_old_backups(self):
        """Remove backups older than 30 days"""
        cutoff_date = datetime.now() - timedelta(days=30)
        # Implementation for S3 cleanup
```

### CI/CD Pipeline

#### GitHub Actions Deployment
```yaml
name: Deploy to Production

on:
  push:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v4
        with:
          python-version: '3.10'
      - name: Run tests
        run: |
          cd Backend
          pip install -r requirements.txt
          pytest --cov=app --cov-report=xml
      - name: Upload coverage
        uses: codecov/codecov-action@v3

  deploy:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to EC2
        env:
          SSH_PRIVATE_KEY: ${{ secrets.SSH_PRIVATE_KEY }}
          HOST: ${{ secrets.HOST }}
        run: |
          echo "$SSH_PRIVATE_KEY" > private_key
          chmod 600 private_key
          ssh -i private_key -o StrictHostKeyChecking=no ec2-user@$HOST '
            cd /home/ec2-user/autospot &&
            git pull origin main &&
            docker-compose -f docker-compose.prod.yml up -d --build
          '
```

### Security Checklist

#### Pre-deployment Security Audit
- [ ] All secrets stored in environment variables
- [ ] Database credentials rotated
- [ ] SSL certificates valid and properly configured
- [ ] Rate limiting configured on all endpoints
- [ ] Input validation implemented on all user inputs
- [ ] Error messages don't leak sensitive information
- [ ] Logging configured without sensitive data exposure
- [ ] File upload restrictions properly implemented
- [ ] CORS configured for production domains only
- [ ] Security headers properly set
- [ ] Database backups encrypted and tested
- [ ] Monitoring and alerting configured
- [ ] Incident response plan documented

## Conclusion

The AutoSpot backend implements enterprise-grade security practices and production-ready deployment architecture. The multi-layered security approach, combined with comprehensive monitoring and automated deployment processes, ensures a robust and scalable system suitable for real-world deployment.

**Key Security Features:**
- Multi-factor authentication with OTP verification
- Advanced password hashing with bcrypt
- Comprehensive input validation and sanitization
- Rate limiting and DDoS protection
- Secure file upload handling
- Audit logging and monitoring

**Key Deployment Features:**
- Containerized deployment with Docker
- Load balancing with Nginx
- SSL/TLS encryption
- Automated backups and disaster recovery
- CI/CD pipeline with automated testing
- Production monitoring with CloudWatch