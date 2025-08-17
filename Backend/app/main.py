from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from app.auth.router import router as auth_router
from app.admin.router import admin_router
from app.parking.router import router as parking_router
from app.QRcode.router import router as qr_router
from app.wallet.router import router as wallet_router
from app.session.router import router as session_router
from app.subscription.router import router as subscription_router
from app.pathfinding import pathfinding_router
from app.emissions import emissions_router
from app.cloudwatch_metrics import metrics
import time
import logging

logger = logging.getLogger(__name__)

app = FastAPI()


# CloudWatch metrics middleware
@app.middleware("http")
async def cloudwatch_metrics_middleware(request: Request, call_next):
    start_time = time.time()

    # Process the request
    response = await call_next(request)

    # Calculate response time
    process_time = (time.time() - start_time) * 1000  # Convert to milliseconds

    # Record metrics
    if request.url.path != "/api/health":  # Don't record health checks
        metrics.record_api_call(
            endpoint=request.url.path,
            method=request.method,
            status_code=response.status_code,
            response_time=process_time,
        )

    return response


# Configure CORS with specific origins for production
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://autospot.it.com",
        "https://www.autospot.it.com",
        "https://api.autospot.it.com",
        "http://autospot.it.com",
        "http://www.autospot.it.com",
        "http://autospot-frontend-hosting.s3-website-ap-southeast-2.amazonaws.com",
        "https://autospot-frontend-hosting.s3-website-ap-southeast-2.amazonaws.com",
        "http://localhost:3000",
        "http://localhost:8080",
        "http://localhost:49329",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:8080",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/api/health")
def health_check():
    return {"status": "ok"}


@app.get("/api/cache/stats")
def cache_stats():
    """Get Redis cache statistics"""
    from app.cache import cache

    return cache.get_stats()


# for the auth router
app.include_router(auth_router)

# for the admin router
app.include_router(admin_router)

# for the parking router
app.include_router(parking_router)

# for the QR code router
app.include_router(qr_router)

# for the wallet router
app.include_router(wallet_router)

# for the subscription router
app.include_router(subscription_router)

# for the pathfinding router
app.include_router(pathfinding_router)

# for the emissions router
app.include_router(emissions_router)

# for the session router
app.include_router(session_router)
