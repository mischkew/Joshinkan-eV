from smtplib import SMTP
import re
from dataclasses import dataclass
from typing import Optional
from email.message import EmailMessage


@dataclass
class EmailUser:
    name: Optional[str]
    email: str

    class ParsingError(Exception):
        INVALID_EMAIL = "INVALID_EMAIL"
        UNEXPECTED_FORMAT = "UNEXPECTED_FORMAT"

    def __str__(self) -> str:
        if self.name:
            return f"{self.name} <{self.email}>"
        else:
            return f"<{self.email}>"

    @staticmethod
    def is_valid_email(email: str) -> bool:
        email_regex = r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
        return re.fullmatch(email_regex, email) is not None

    @classmethod
    def from_description(cls, description: str) -> "EmailUser":
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


class Mailer:
    def __init__(self, host: str, port: int, user: EmailUser, password: str):
        self.host = host
        self.port = port
        self.user = user
        self.password = password

    def send(self, message: EmailMessage, to_addrs: list[EmailUser]):
        emails = [addr.email for addr in to_addrs]
        smtp = SMTP(self.host, self.port)
        smtp.starttls()
        smtp.login(self.user.email, self.password)
        smtp.send_message(message, to_addrs=emails)
        smtp.quit()
