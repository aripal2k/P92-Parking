import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.database import user_collection, wallet_collection, transactions_collection
import json
from datetime import datetime, timedelta

client = TestClient(app)

# Test data
TEST_USER_EMAIL = "test_subscription@example.com"
TEST_PREMIUM_USER_EMAIL = "test_premium@example.com"


@pytest.fixture(scope="function")
def setup_test_user():
    """Setup a test user for subscription tests"""
    # Clean up any existing test data
    user_collection.delete_many(
        {"email": {"$in": [TEST_USER_EMAIL, TEST_PREMIUM_USER_EMAIL]}}
    )
    wallet_collection.delete_many(
        {"user_email": {"$in": [TEST_USER_EMAIL, TEST_PREMIUM_USER_EMAIL]}}
    )
    transactions_collection.delete_many(
        {"user_email": {"$in": [TEST_USER_EMAIL, TEST_PREMIUM_USER_EMAIL]}}
    )

    # Create basic test user
    basic_user_data = {
        "email": TEST_USER_EMAIL,
        "username": "test_basic_user",
        "fullname": "Test Basic User",
        "password": "hashedpassword123",
        "role": "user",
        "subscription_plan": "basic",
    }
    user_collection.insert_one(basic_user_data)

    # Create premium test user (already premium)
    premium_user_data = {
        "email": TEST_PREMIUM_USER_EMAIL,
        "username": "test_premium_user",
        "fullname": "Test Premium User",
        "password": "hashedpassword123",
        "role": "user",
        "subscription_plan": "premium",
        "subscription_expires_at": datetime.utcnow() + timedelta(days=25),
    }
    user_collection.insert_one(premium_user_data)

    # Create wallets with sufficient balance for upgrade
    wallet_collection.insert_many(
        [
            {
                "user_email": TEST_USER_EMAIL,
                "balance": 50.0,
                "created_at": datetime.utcnow(),
                "updated_at": datetime.utcnow(),
            },
            {
                "user_email": TEST_PREMIUM_USER_EMAIL,
                "balance": 100.0,
                "created_at": datetime.utcnow(),
                "updated_at": datetime.utcnow(),
            },
        ]
    )

    yield

    # Clean up after test
    user_collection.delete_many(
        {"email": {"$in": [TEST_USER_EMAIL, TEST_PREMIUM_USER_EMAIL]}}
    )
    wallet_collection.delete_many(
        {"user_email": {"$in": [TEST_USER_EMAIL, TEST_PREMIUM_USER_EMAIL]}}
    )
    transactions_collection.delete_many(
        {"user_email": {"$in": [TEST_USER_EMAIL, TEST_PREMIUM_USER_EMAIL]}}
    )


class TestSubscriptionAPI:
    """Test subscription API endpoints"""

    def test_get_subscription_status_basic_user(self, setup_test_user):
        """Test getting subscription status for basic user"""
        response = client.get(f"/subscription/status?email={TEST_USER_EMAIL}")

        assert response.status_code == 200
        data = response.json()
        assert data["subscription_plan"] == "basic"
        assert data["status"] == "active"
        assert data["expires_at"] is None
        assert data["days_remaining"] is None
        print(f"✅ Basic user status: {data}")

    def test_get_subscription_status_premium_user(self, setup_test_user):
        """Test getting subscription status for premium user"""
        response = client.get(f"/subscription/status?email={TEST_PREMIUM_USER_EMAIL}")

        assert response.status_code == 200
        data = response.json()
        assert data["subscription_plan"] == "premium"
        assert data["status"] == "active"
        assert data["expires_at"] is not None
        assert data["days_remaining"] is not None
        assert data["days_remaining"] > 0
        print(f"✅ Premium user status: {data}")

    def test_get_subscription_pricing(self, setup_test_user):
        """Test getting subscription pricing information"""
        response = client.get("/subscription/pricing")

        assert response.status_code == 200
        data = response.json()
        assert "premium_monthly_price" in data
        assert data["premium_monthly_price"] == 20.0
        assert data["currency"] == "AUD"
        assert "benefits" in data
        assert len(data["benefits"]) >= 3
        print(f"✅ Pricing info: {data}")

    def test_upgrade_subscription_success(self, setup_test_user):
        """Test successful subscription upgrade"""
        # Check initial balance
        initial_wallet = wallet_collection.find_one({"user_email": TEST_USER_EMAIL})
        initial_balance = initial_wallet["balance"]
        print(f"Initial balance: ${initial_balance}")

        response = client.post(
            "/subscription/upgrade",
            json={"email": TEST_USER_EMAIL},
            headers={"Content-Type": "application/json"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["new_plan"] == "premium"
        assert data["amount_charged"] == 20.0
        assert "expires_at" in data
        print(f"✅ Upgrade response: {data}")

        # Verify user was updated in database
        user = user_collection.find_one({"email": TEST_USER_EMAIL})
        assert user["subscription_plan"] == "premium"
        assert user["subscription_expires_at"] is not None
        print(
            f"✅ User updated: plan={user['subscription_plan']}, expires={user['subscription_expires_at']}"
        )

        # Verify wallet balance was deducted
        updated_wallet = wallet_collection.find_one({"user_email": TEST_USER_EMAIL})
        assert updated_wallet["balance"] == initial_balance - 20.0
        print(f"✅ Balance deducted: ${updated_wallet['balance']}")

        # Verify transaction was recorded
        transaction = transactions_collection.find_one(
            {
                "user_email": TEST_USER_EMAIL,
                "transaction_type": "parking_payment",  # The actual transaction type from deduct_from_wallet
            }
        )
        assert transaction is not None
        assert transaction["amount"] == 20.0
        print(f"✅ Transaction recorded: {transaction.get('transaction_id', 'N/A')}")

    def test_upgrade_subscription_insufficient_balance(self, setup_test_user):
        """Test subscription upgrade with insufficient balance"""
        # Set wallet balance to insufficient amount
        wallet_collection.update_one(
            {"user_email": TEST_USER_EMAIL}, {"$set": {"balance": 5.0}}
        )

        response = client.post(
            "/subscription/upgrade",
            json={"email": TEST_USER_EMAIL},
            headers={"Content-Type": "application/json"},
        )

        assert response.status_code == 400
        assert "Insufficient wallet balance" in response.json()["detail"]
        print(f"✅ Insufficient balance error: {response.json()['detail']}")

        # Verify user was not upgraded
        user = user_collection.find_one({"email": TEST_USER_EMAIL})
        assert user["subscription_plan"] == "basic"
        print("✅ User remained basic after failed upgrade")

    def test_upgrade_subscription_already_premium(self, setup_test_user):
        """Test subscription upgrade when user is already premium"""
        response = client.post(
            "/subscription/upgrade",
            json={"email": TEST_PREMIUM_USER_EMAIL},
            headers={"Content-Type": "application/json"},
        )

        assert response.status_code == 400
        assert "already a premium member" in response.json()["detail"]
        print(f"✅ Already premium error: {response.json()['detail']}")

    def test_upgrade_subscription_user_not_found(self, setup_test_user):
        """Test subscription upgrade for non-existent user"""
        response = client.post(
            "/subscription/upgrade",
            json={"email": "nonexistent@example.com"},
            headers={"Content-Type": "application/json"},
        )

        assert response.status_code == 404
        assert response.json()["detail"] == "User not found"
        print(f"✅ User not found error: {response.json()['detail']}")

    def test_subscription_status_user_not_found(self, setup_test_user):
        """Test getting subscription status for non-existent user"""
        response = client.get("/subscription/status?email=nonexistent@example.com")

        assert response.status_code == 404
        assert response.json()["detail"] == "User not found"
        print(f"✅ Status user not found error: {response.json()['detail']}")

    def test_subscription_expired_user_downgrade(self, setup_test_user):
        """Test that expired premium users are automatically downgraded"""
        # Create an expired premium user
        expired_user_email = "expired_premium@example.com"
        expired_user_data = {
            "email": expired_user_email,
            "username": "expired_premium_user",
            "fullname": "Expired Premium User",
            "password": "hashedpassword123",
            "role": "user",
            "subscription_plan": "premium",
            "subscription_expires_at": datetime.utcnow()
            - timedelta(days=1),  # Expired yesterday
        }
        user_collection.insert_one(expired_user_data)

        try:
            # Check status - should automatically downgrade to basic
            response = client.get(f"/subscription/status?email={expired_user_email}")

            assert response.status_code == 200
            data = response.json()
            assert data["subscription_plan"] == "basic"  # Should be downgraded
            assert data["status"] in [
                "expired",
                "active",
            ]  # Status can be either since user is downgraded
            print(f"✅ Expired user auto-downgraded: {data}")

            # Verify user was updated in database
            user = user_collection.find_one({"email": expired_user_email})
            assert user["subscription_plan"] == "basic"
            print("✅ Expired user downgraded in database")

        finally:
            # Clean up
            user_collection.delete_one({"email": expired_user_email})


if __name__ == "__main__":
    pytest.main([__file__, "-v", "-s"])
