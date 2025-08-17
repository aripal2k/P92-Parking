import os
from dotenv import load_dotenv
from pymongo import MongoClient

load_dotenv()  # Load variables from .env

MONGODB_URI = os.getenv("MONGODB_URI")

client = MongoClient(MONGODB_URI)
db = client["parking_app"]
user_collection = db["users"]
parking_rates_collection = db["parking_rates"]

# Parking session collection
session_collection = db["sessions"]

# Wallet-related collections
wallet_collection = db["wallets"]
payment_methods_collection = db["payment_methods"]
transactions_collection = db["transactions"]

# Emissions collection
emissions_collection = db["emissions"]
