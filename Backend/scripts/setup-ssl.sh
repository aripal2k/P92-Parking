#!/bin/bash

# SSL Setup Script for AutoSpot
# This script installs Let's Encrypt SSL certificates for all domains

set -e

echo "=== AutoSpot SSL Certificate Setup ==="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run this script with sudo"
    exit 1
fi

# Install certbot if not already installed
if ! command -v certbot &> /dev/null; then
    echo "Installing Certbot..."
    apt-get update
    apt-get install -y certbot python3-certbot-nginx
fi

# Stop nginx temporarily to avoid conflicts
echo "Stopping Nginx temporarily..."
systemctl stop nginx || true

# Email for Let's Encrypt notifications
EMAIL="whoisjackie1127@gmail.com"  # Change this to your email

# Request certificates for all domains
echo "Requesting SSL certificates..."
certbot certonly --standalone \
    --non-interactive \
    --agree-tos \
    --email $EMAIL \
    -d autospot.it.com \
    -d www.autospot.it.com \
    -d api.autospot.it.com

# Copy Nginx configuration
echo "Setting up Nginx configuration..."
cp /home/ubuntu/capstone-project-25t2-3900-t16a-cherry/Backend/nginx/autospot.conf /etc/nginx/sites-available/autospot

# Enable the site
ln -sf /etc/nginx/sites-available/autospot /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
echo "Testing Nginx configuration..."
nginx -t

# Start Nginx
echo "Starting Nginx..."
systemctl start nginx
systemctl enable nginx

# Setup auto-renewal
echo "Setting up auto-renewal..."
(crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -

echo "=== SSL Setup Complete! ==="
echo "Your domains are now secured with HTTPS:"
echo "  - https://autospot.it.com"
echo "  - https://www.autospot.it.com"  
echo "  - https://api.autospot.it.com"
echo ""
echo "Certificates will auto-renew every 60 days."