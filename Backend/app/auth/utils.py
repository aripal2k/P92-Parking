from passlib.context import CryptContext

# hashes passwords
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


# returns a hashed version of the password string
def hash_password(password: str) -> str:
    return pwd_context.hash(password)


# checks if the string and hashed version matches
def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)
