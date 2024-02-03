from .config import Config
import smtplib
import re
from dataclasses import dataclass
from typing import Optional


_smtp = None


def smtp() -> smtplib.SMTP:
    global _smtp
    if _smtp is None:
        _smtp = smtplib.SMTP(Config.SMTP_HOST, Config.SMTP_PORT)
        _smtp.login(Config.SMPT_USER, Config.SMPT_PASSWORD)
    return _smtp


@dataclass
class EmailUser:
    name: Optional[str]
    email: str

    class ParsingError(Exception):
        INVALID_EMAIL = "INVALID_EMAIL"
        UNEXPECTED_FORMAT = "UNEXPECTED_FORMAT"

    def __str__(self):
        if self.name:
            return f"{self.name} <{self.email}>"
        else:
            return f"<{self.email}>"

    @staticmethod
    def is_valid_email(email):
        email_regex = r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
        return re.fullmatch(email_regex, email) is not None

    @classmethod
    def from_description(cls, description):
        user_regex = r"^(?P<name>[^<>]+)?(\s*<(?P<email>.+)>\s*)?"
        match = re.fullmatch(user_regex, description)

        if not match:
            raise cls.ParsingError(cls.ParsingError.UNEXPECTED_FORMAT)

        if match.group("email") is None and match.group("name") is not None:
            email = match.group("name").strip()
            if not cls.is_valid_email(email):
                raise cls.ParsingError(cls.ParsingError.INVALID_EMAIL)
            return cls(name=None, email=email)

        name = match.group("name").strip() if match.group("name") else None
        email = match.group("email")

        if not email:
            raise cls.ParsingError(cls.ParsingError.UNEXPECTED_FORMAT)

        if name is not None:
            name = name.strip()

        if not cls.is_valid_email(email):
            raise cls.ParsingError(cls.ParsingError.INVALID_EMAIL)

        return cls(name=name, email=email)
