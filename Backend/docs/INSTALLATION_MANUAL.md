# AutoSpot Backend Installation Guide

## Prerequisites
- **Docker & Docker Compose** (recommended)
- **Python 3.10+** (for local development)
- **4GB RAM minimum**

## Quick Start (Docker - Recommended)

```bash
# 1. Install Docker Desktop
# Download from: https://docker.com/products/docker-desktop

# 2. Clone and start
git clone <your-repository-url>
cd capstone-project-25t2-3900-t16a-cherry/Backend
docker-compose up --build

# 3. Load sample data (optional but recommended)
python app/examples/local_mongodb_storage.py

# 4. Verify installation
curl http://localhost:8000/api/health
```

✅ **That's it!** Backend runs at http://localhost:8000

📖 **API Documentation**: http://localhost:8000/docs

🧪 **Sample data loaded**: Test users, parking maps, and API examples ready to use

## Local Development Setup

### 1. Install Requirements
```bash
# Install Python 3.10+, MongoDB, Redis
# Ubuntu: sudo apt install python3.10 mongodb redis-server
# macOS: brew install python@3.10 mongodb redis
```

### 2. Setup Application
```bash
# Clone and setup
git clone <your-repository-url>
cd capstone-project-25t2-3900-t16a-cherry/Backend

# Create virtual environment
python3.10 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Create environment file
echo "MONGODB_URI=mongodb://localhost:27017
REDIS_URL=redis://localhost:6379
DEBUG=true" > .env
```

### 3. Start Services
```bash
# Start MongoDB and Redis (if not running)
# Then start backend
uvicorn app.main:app --reload --port 8000

# In another terminal, load sample data
python app/examples/local_mongodb_storage.py
```

## Production Deployment

### AWS EC2 Quick Deploy
```bash
# 1. Launch Ubuntu 20.04 EC2 instance (t3.medium+)
# 2. Install Docker
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker ubuntu

# 3. Deploy application
git clone <your-repository-url>
cd capstone-project-25t2-3900-t16a-cherry/Backend
docker-compose -f docker-compose.prod.yml up -d
```

### Environment Variables (Production)
```env
MONGODB_URI=mongodb://mongo:27017
REDIS_URL=redis://redis:6379
JWT_SECRET_KEY=your-32-character-secret
OPENAI_API_KEY=your-api-key
DEBUG=false
```

## Testing and Verification

### Quick Health Check
```bash
# Check if backend is running
curl http://localhost:8000/api/health

# Expected: {"status": "ok"}
```

### Run Tests
```bash
# Run all tests (75% coverage)
pytest

# View test coverage
pytest --cov=app --cov-report=html
```

### Access Documentation
- **API Docs**: http://localhost:8000/docs
- **Alternative**: http://localhost:8000/redoc

## Troubleshooting

### Docker Issues
```bash
# Check if Docker is running
docker --version

# Restart Docker services
docker-compose restart

# View logs
docker-compose logs backend
```

### Port Issues
```bash
# Check what's using port 8000
sudo lsof -i :8000

# Use different port
uvicorn app.main:app --port 8001
```

### Database Connection
```bash
# Check if MongoDB is running in Docker
docker-compose ps

# Restart database services
docker-compose restart mongo redis
```

### Permission Issues
```bash
# Fix Docker permissions
sudo usermod -aG docker $USER
# Then logout and login again
```

## Performance Notes

- **Average response time**: <200ms
- **Test coverage**: 75%
- **Concurrent users**: 1,000+ supported
- **Memory usage**: ~2GB for full stack

## Additional Resources

📚 **Detailed Documentation**:
- [Performance & Scalability](PERFORMANCE_AND_SCALABILITY.md)
- [Security & Deployment](SECURITY_AND_DEPLOYMENT.md)
- [API Documentation](API_DOCUMENTATION.md)

🔧 **For Production**: See Security & Deployment guide for SSL, monitoring, and backup setup.