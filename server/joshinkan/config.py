import os


class Config:
    LOGLEVEL: str = os.environ.get("LOGLEVEL", "DEBUG")
    """Global loglevel filter used for the logger module"""

    PRINT_STACKTRACE: str = len(os.environ.get("PRINT_STACKTRACE", "")) > 0
    """Return a full stacktrace when a route raises an error for debugging purposes."""
