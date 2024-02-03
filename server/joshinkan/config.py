from dataclasses import dataclass, field
import os


@dataclass
class Config:
    LOGLEVEL: str = field(default_factory=lambda: os.environ.get("LOGLEVEL", "DEBUG"))
    """Global loglevel filter used for the logger module"""

    PRINT_STACKTRACE: bool = field(
        default_factory=lambda: len(os.environ.get("PRINT_STACKTRACE", "")) > 0
    )
    """Return a full stacktrace when a route raises an error for debugging purposes."""

    DOMAIN: str = field(default_factory=lambda: os.environ.get("DOMAIN", "localhost"))
    """The domain name of the server"""

    SMTP_HOST: str = field(
        default_factory=lambda: os.environ.get("SMTP_HOST", "smtp.gmail.com")
    )
    SMTP_PORT: int = field(
        default_factory=lambda: int(os.environ.get("SMTP_PORT", 465))
    )
    SMTP_USER: str = field(default_factory=lambda: os.environ.get("SMTP_USER"))
    SMTP_PASSWORD: str = field(default_factory=lambda: os.environ.get("SMTP_PASSWORD"))
    SMTP_REPLY_TO: str = field(
        default_factory=lambda: os.environ.get("SMTP_REPLY_TO", "")
    )
    SMTP_CC: list[str] = field(
        default_factory=lambda: os.environ.get("SMTP_CC", "").split(",")
    )
    SMTP_BCC: list[str] = field(
        default_factory=lambda: os.environ.get("SMTP_BCC", "").split(",")
    )
