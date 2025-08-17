"""
Test cases for Redis cache functionality
Target Coverage: 80%
"""

import pytest
from unittest.mock import patch, MagicMock, call
import json
import time
from app.cache import RedisCache, cached


class TestRedisCache:
    """Test cases for RedisCache class"""

    @patch("app.cache.redis.from_url")
    def test_connect_success(self, mock_redis_from_url):
        """Test successful Redis connection"""
        # Setup mock
        mock_client = MagicMock()
        mock_client.ping.return_value = True
        mock_redis_from_url.return_value = mock_client

        # Create cache instance
        cache = RedisCache()

        # Verify connection
        assert cache.client is not None
        mock_redis_from_url.assert_called_once()
        mock_client.ping.assert_called_once()

    @patch("app.cache.redis.from_url")
    def test_connect_failure(self, mock_redis_from_url):
        """Test Redis connection failure handling"""
        # Setup mock to raise exception
        mock_redis_from_url.side_effect = Exception("Connection refused")

        # Create cache instance
        cache = RedisCache()

        # Verify connection failed gracefully
        assert cache.client is None

    @patch("app.cache.redis.from_url")
    def test_is_connected_true(self, mock_redis_from_url):
        """Test is_connected returns True when connected"""
        # Setup mock
        mock_client = MagicMock()
        mock_client.ping.return_value = True
        mock_redis_from_url.return_value = mock_client

        cache = RedisCache()
        assert cache.is_connected() is True

    @patch("app.cache.redis.from_url")
    def test_is_connected_false_no_client(self, mock_redis_from_url):
        """Test is_connected returns False when no client"""
        mock_redis_from_url.side_effect = Exception("Connection failed")
        cache = RedisCache()
        assert cache.is_connected() is False

    @patch("app.cache.redis.from_url")
    def test_is_connected_false_ping_fails(self, mock_redis_from_url):
        """Test is_connected returns False when ping fails"""
        mock_client = MagicMock()
        mock_client.ping.side_effect = Exception("Ping failed")
        mock_redis_from_url.return_value = mock_client

        cache = RedisCache()
        assert cache.is_connected() is False

    @patch("app.cache.redis.from_url")
    def test_get_existing_key(self, mock_redis_from_url):
        """Test getting existing key from cache"""
        # Setup mock
        mock_client = MagicMock()
        mock_client.ping.return_value = True
        mock_client.get.return_value = '{"data": "test_value"}'
        mock_redis_from_url.return_value = mock_client

        cache = RedisCache()
        result = cache.get("test_key")

        assert result == {"data": "test_value"}
        mock_client.get.assert_called_once_with("test_key")

    @patch("app.cache.redis.from_url")
    def test_get_non_existing_key(self, mock_redis_from_url):
        """Test getting non-existing key from cache"""
        mock_client = MagicMock()
        mock_client.ping.return_value = True
        mock_client.get.return_value = None
        mock_redis_from_url.return_value = mock_client

        cache = RedisCache()
        result = cache.get("non_existing_key")

        assert result is None

    @patch("app.cache.redis.from_url")
    def test_get_with_disconnected_client(self, mock_redis_from_url):
        """Test get returns None when client is disconnected"""
        mock_redis_from_url.side_effect = Exception("Connection failed")
        cache = RedisCache()
        result = cache.get("test_key")
        assert result is None

    @patch("app.cache.redis.from_url")
    def test_set_success(self, mock_redis_from_url):
        """Test setting value in cache"""
        mock_client = MagicMock()
        mock_client.ping.return_value = True
        mock_client.setex.return_value = True
        mock_redis_from_url.return_value = mock_client

        cache = RedisCache()
        result = cache.set("test_key", {"data": "test_value"}, expire=300)

        assert result is True
        mock_client.setex.assert_called_once_with(
            "test_key", 300, '{"data": "test_value"}'
        )

    @patch("app.cache.redis.from_url")
    def test_set_with_default_ttl(self, mock_redis_from_url):
        """Test setting value with default TTL"""
        mock_client = MagicMock()
        mock_client.ping.return_value = True
        mock_client.setex.return_value = True
        mock_redis_from_url.return_value = mock_client

        cache = RedisCache()
        result = cache.set("test_key", "test_value")

        assert result is True
        # Default TTL is 300 seconds
        mock_client.setex.assert_called_once_with("test_key", 300, '"test_value"')

    @patch("app.cache.redis.from_url")
    def test_set_with_disconnected_client(self, mock_redis_from_url):
        """Test set returns False when client is disconnected"""
        mock_redis_from_url.side_effect = Exception("Connection failed")
        cache = RedisCache()
        result = cache.set("test_key", "test_value")
        assert result is False

    @patch("app.cache.redis.from_url")
    def test_delete_success(self, mock_redis_from_url):
        """Test deleting key from cache"""
        mock_client = MagicMock()
        mock_client.ping.return_value = True
        mock_client.delete.return_value = 1
        mock_redis_from_url.return_value = mock_client

        cache = RedisCache()
        result = cache.delete("test_key")

        assert result is True
        mock_client.delete.assert_called_once_with("test_key")

    @patch("app.cache.redis.from_url")
    def test_delete_non_existing_key(self, mock_redis_from_url):
        """Test deleting non-existing key"""
        mock_client = MagicMock()
        mock_client.ping.return_value = True
        mock_client.delete.return_value = 0
        mock_redis_from_url.return_value = mock_client

        cache = RedisCache()
        result = cache.delete("non_existing_key")

        assert result is False

    @patch("app.cache.redis.from_url")
    def test_delete_with_disconnected_client(self, mock_redis_from_url):
        """Test delete returns False when client is disconnected"""
        mock_redis_from_url.side_effect = Exception("Connection failed")
        cache = RedisCache()
        result = cache.delete("test_key")
        assert result is False

    @patch("app.cache.redis.from_url")
    def test_clear_pattern_success(self, mock_redis_from_url):
        """Test clearing keys by pattern"""
        mock_client = MagicMock()
        mock_client.ping.return_value = True
        mock_client.keys.return_value = ["key1", "key2", "key3"]
        mock_client.delete.return_value = 3
        mock_redis_from_url.return_value = mock_client

        cache = RedisCache()
        result = cache.clear_pattern("key*")

        assert result == 3
        mock_client.keys.assert_called_once_with("key*")
        mock_client.delete.assert_called_once_with("key1", "key2", "key3")

    @patch("app.cache.redis.from_url")
    def test_clear_pattern_no_matches(self, mock_redis_from_url):
        """Test clearing pattern with no matches"""
        mock_client = MagicMock()
        mock_client.ping.return_value = True
        mock_client.keys.return_value = []
        mock_redis_from_url.return_value = mock_client

        cache = RedisCache()
        result = cache.clear_pattern("nonexistent*")

        assert result == 0

    @patch("app.cache.redis.from_url")
    def test_get_stats_connected(self, mock_redis_from_url):
        """Test getting cache statistics when connected"""
        mock_client = MagicMock()
        mock_client.ping.return_value = True
        mock_client.info.return_value = {
            "used_memory_human": "1.5M",
            "connected_clients": 5,
            "total_commands_processed": 1000,
            "keyspace_hits": 800,
            "keyspace_misses": 200,
        }
        mock_redis_from_url.return_value = mock_client

        cache = RedisCache()
        stats = cache.get_stats()

        assert stats["connected"] is True
        assert stats["used_memory"] == "1.5M"
        assert stats["connected_clients"] == 5
        assert stats["hit_rate"] == 80.0  # (800/(800+200)) * 100

    @patch("app.cache.redis.from_url")
    def test_get_stats_disconnected(self, mock_redis_from_url):
        """Test getting cache statistics when disconnected"""
        mock_redis_from_url.side_effect = Exception("Connection failed")
        cache = RedisCache()
        stats = cache.get_stats()

        assert stats["connected"] is False


class TestConcurrency:
    """Test cases for concurrent cache operations"""

    @patch("app.cache.redis.from_url")
    def test_concurrent_set_operations(self, mock_redis_from_url):
        """Test concurrent set operations don't interfere"""
        mock_client = MagicMock()
        mock_client.ping.return_value = True
        mock_client.setex.return_value = True
        mock_redis_from_url.return_value = mock_client

        cache = RedisCache()

        # Simulate concurrent sets
        cache.set("key1", "value1", expire=100)
        cache.set("key2", "value2", expire=200)
        cache.set("key1", "value1_updated", expire=150)

        # Verify all operations were called
        assert mock_client.setex.call_count == 3
        calls = mock_client.setex.call_args_list
        assert calls[0] == call("key1", 100, '"value1"')
        assert calls[1] == call("key2", 200, '"value2"')
        assert calls[2] == call("key1", 150, '"value1_updated"')


class TestErrorHandling:
    """Test error handling scenarios"""

    @patch("app.cache.redis.from_url")
    def test_json_decode_error(self, mock_redis_from_url):
        """Test handling of invalid JSON in cache"""
        mock_client = MagicMock()
        mock_client.ping.return_value = True
        mock_client.get.return_value = "invalid json {{"
        mock_redis_from_url.return_value = mock_client

        cache = RedisCache()
        result = cache.get("test_key")

        # Should return None on JSON decode error
        assert result is None

    @patch("app.cache.redis.from_url")
    def test_network_timeout(self, mock_redis_from_url):
        """Test handling of network timeout"""
        mock_client = MagicMock()
        mock_client.ping.return_value = True
        mock_client.get.side_effect = TimeoutError("Network timeout")
        mock_redis_from_url.return_value = mock_client

        cache = RedisCache()
        result = cache.get("test_key")

        assert result is None
