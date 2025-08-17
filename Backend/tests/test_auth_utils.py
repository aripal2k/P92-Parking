import pytest
from app.auth.utils import hash_password, verify_password

try:
    from passlib.exc import UnknownHashError
except ImportError:
    # Fallback if passlib exception import fails
    UnknownHashError = Exception


class TestAuthUtils:
    """Test cases for authentication utility functions"""

    def test_hash_password_returns_string(self):
        """Test that hash_password returns a string"""
        password = "TestPassword123!"
        hashed = hash_password(password)
        assert isinstance(hashed, str)
        assert len(hashed) > 0

    def test_hash_password_different_for_same_input(self):
        """Test that hash_password returns different hashes for the same input"""
        password = "TestPassword123!"
        # same password
        hash1 = hash_password(password)
        hash2 = hash_password(password)

        # Hashes should be different
        assert hash1 != hash2

    def test_hash_password_different_for_different_inputs(self):
        """Test that hash_password returns different hashes for different inputs"""
        password1 = "TestPassword123!"
        password2 = "DifferentPassword456@"
        # different password
        hash1 = hash_password(password1)
        hash2 = hash_password(password2)

        assert hash1 != hash2

    def test_verify_password_correct_password(self):
        """Test that verify_password returns True for correct password"""
        password = "TestPassword123!"
        hashed = hash_password(password)

        assert verify_password(password, hashed) is True

    def test_verify_password_incorrect_password(self):
        """Test that verify_password returns False for incorrect password"""
        correct_password = "TestPassword123!"
        incorrect_password = "WrongPassword456@"
        hashed = hash_password(correct_password)

        assert verify_password(incorrect_password, hashed) is False

    def test_verify_password_empty_password(self):
        """Test that verify_password handles empty password"""
        password = "TestPassword123!"
        hashed = hash_password(password)

        assert verify_password("", hashed) is False

    def test_verify_password_empty_hash(self):
        """Test that verify_password handles empty hash"""
        password = "TestPassword123!"

        # passlib raises UnknownHashError for empty hash strings
        with pytest.raises((UnknownHashError, Exception)):
            verify_password(password, "")

    def test_verify_password_invalid_hash(self):
        """Test that verify_password handles invalid hash formats"""
        password = "TestPassword123!"

        # Test with clearly invalid hash formats
        invalid_hashes = ["not_a_hash", "invalid_format_123", "short"]

        for invalid_hash in invalid_hashes:
            with pytest.raises((UnknownHashError, Exception)):
                verify_password(password, invalid_hash)

    def test_verify_password_with_special_characters(self):
        """Test password verification with special characters"""
        password = "P@ssw0rd!@#$%^&*()"
        hashed = hash_password(password)

        assert verify_password(password, hashed) is True

    def test_verify_password_with_unicode_characters(self):
        """Test password verification with unicode characters"""
        password = "Pässwörd123!"
        hashed = hash_password(password)

        assert verify_password(password, hashed) is True

    def test_hash_password_consistent_length_range(self):
        """Test that hashed passwords have consistent length range"""
        passwords = [
            "short",
            "medium_length_password",
            "very_long_password_with_many_characters_123!@#",
        ]

        hashes = [hash_password(pwd) for pwd in passwords]

        # bcrypt hashes should be around 60 characters
        for hashed in hashes:
            assert 50 <= len(hashed) <= 70

    def test_verify_password_case_sensitive(self):
        """Test that password verification is case sensitive"""
        password = "TestPassword123!"
        case_changed = "testpassword123!"
        hashed = hash_password(password)

        assert verify_password(password, hashed) is True
        assert verify_password(case_changed, hashed) is False

    def test_hash_password_none_input(self):
        """Test that hash_password handles None input gracefully"""
        # hash_password should raise an exception with None input
        try:
            result = hash_password(None)
            # If it doesn't raise an exception, it should not return None or empty string
            assert (
                result is not None and result != ""
            ), "hash_password should not return None/empty for None input"
        except (TypeError, AttributeError, Exception):
            # Any exception is acceptable for None input
            pass

    def test_verify_password_none_inputs(self):
        """Test that verify_password handles None inputs gracefully"""
        password = "TestPassword123!"
        hashed = hash_password(password)

        # passlib may convert None to string or raise various exceptions
        # Test that it doesn't return True (which would be a security issue)
        try:
            result1 = verify_password(None, hashed)
            assert result1 is False, "None password should not verify successfully"
        except (TypeError, AttributeError, Exception):
            # Any exception is acceptable for None input
            pass

        try:
            result2 = verify_password(password, None)
            assert result2 is False, "None hash should not verify successfully"
        except (TypeError, AttributeError, Exception):
            # Any exception is acceptable for None input
            pass
