"""Rate limiting middleware using slowapi.

Protects API endpoints from abuse with configurable per-endpoint limits.
"""

from __future__ import annotations

from slowapi import Limiter
from slowapi.util import get_remote_address

# Create limiter instance with sensible defaults
limiter = Limiter(
    key_func=get_remote_address,
    default_limits=["60/minute", "1000/hour"],
    storage_uri="memory://",
    strategy="fixed-window",
)
