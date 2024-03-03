from dataclasses import dataclass, field
from .smtp import EmailUser
import os
from typing import Optional


@dataclass
class Config:
    LOGLEVEL: str = field(
        default_factory=lambda: os.environ.get("LOGLEVEL", "DEBUG").strip()
    )
    """Global loglevel filter used for the logger module"""

    PRINT_STACKTRACE: bool = field(
        default_factory=lambda: len(os.environ.get("PRINT_STACKTRACE", "").strip()) > 0
    )
    """Return a full stacktrace when a route raises an error for debugging purposes."""

    SMTP_HOST: str = field(
        default_factory=lambda: os.environ.get("SMTP_HOST", "smtp.gmail.com").strip()
    )
    SMTP_PORT: int = field(
        default_factory=lambda: int(os.environ.get("SMTP_PORT", 587))
    )
    SMTP_USER: EmailUser = field(
        default_factory=lambda: EmailUser.from_description(
            os.environ.get("SMTP_USER").strip()
        )
    )
    SMTP_PASSWORD: str = field(
        default_factory=lambda: os.environ.get("SMTP_PASSWORD").strip()
    )
    SMTP_REPLY_TO: Optional[EmailUser] = field(
        default_factory=lambda: None
        if os.environ.get("SMTP_REPLY_TO") is None
        else EmailUser.from_description(os.environ.get("SMTP_REPLY_TO").strip())
    )
    SMTP_CC: list[EmailUser] = field(
        default_factory=lambda: [
            EmailUser.from_description(email.strip())
            for email in os.environ.get("SMTP_CC", "").split(",")
            if email != ""
        ]
    )
    SMTP_BCC: list[EmailUser] = field(
        default_factory=lambda: [
            EmailUser.from_description(email.strip())
            for email in os.environ.get("SMTP_BCC", "").split(",")
            if email != ""
        ]
    )
