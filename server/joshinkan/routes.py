from dataclasses import dataclass
from email.message import EmailMessage
import os

from .config import Config
from .httpd import Router, Response, expect_json, Request, Status
from .validation import Schema, DictOf, Values, OptionalKey, ListOf
from .logger import get_logger
from joshinkan import multipart
from .smtp import SMTP, EmailUser, Mailer

logger = get_logger(__name__)
router = Router()

ADULT_SCHEMA = Schema(
    {
        "first_name": str,
        "last_name": str,
        "email": str,
        "phone": str,
        "privacy": Values("on"),
        "age": str,
    }
)

CHILDREN_SCHEMA = Schema(
    {
        "first_name": str,
        "last_name": str,
        "email": str,
        "phone": str,
        "privacy": Values("on"),
        "age": str,
        "child_first_name": ListOf(str),
        "child_last_name": ListOf(str),
        "child_age": ListOf(str),
        "parents_consent": Values("on"),
    }
)


@dataclass
class AppContext:
    mailer: Mailer

    @staticmethod
    def from_config(config: Config) -> "AppContext":
        mailer = Mailer(
            host=config.SMTP_HOST,
            port=config.SMTP_PORT,
            user=config.SMTP_USER,
            password=config.SMTP_PASSWORD,
        )
        return AppContext(mailer=mailer)


def host_domain(request: Request) -> str:
    return request.environ["HTTP_ORIGIN"]


@router.post("/trial-registration")
@router.with_context()
@router.with_config()
def trial_registration(
    request: Request, context: AppContext, config: Config
) -> Response:
    domain = host_domain(request)
    form_data = request.form_data()
    adult_valid, adult_error = ADULT_SCHEMA.validate(form_data)
    child_valid, child_error = CHILDREN_SCHEMA.validate(form_data)

    first_name = form_data["first_name"]
    last_name = form_data["last_name"]
    email = form_data["email"]
    phone = form_data["phone"]

    if child_valid:
        # TODO(sven): Fix child parsing and email sending

        def make_block(index: int) -> str:
            first_name = form_data["child_first_name"][index]
            last_name = form_data["child_last_name"][index]
            age = form_data["child_age"][index]

            return f"""
            <b>Kind #{index+1}</b><br/>
            Name: {first_name} {last_name}<br/>
            Alter: {age}<br/>
            """

        blocks = "\n<br/>".join(
            make_block(i) for i in range(len(form_data["child_first_name"]))
        )

        message = EmailMessage()
        message.set_content(
            f"""
            Neuanmeldung zum Probetraining für <b>Kinder</b>.<br/>
            <br/>
            {blocks}
            <br/>
            <b>Elternteil</b><br/>
            Name: {first_name} {last_name}<br/>
            Email: {email}<br/>
            Telefon: {phone}<br/>
            """
        )

        message["Subject"] = "Neuanmeldung zum Probetraining für Kinder ({len(blocks)})"
        message["From"] = config.SMTP_USER
        message["To"] = config.SMTP_REPLY_TO or config.SMTP_USER
        message["Cc"] = config.SMTP_CC
        message["Content-Type"] = "text/html; charset=utf-8"
        context.mailer.send(
            message, to_addrs=[config.SMTP_USER] + config.SMTP_CC + config.SMTP_BCC
        )

        def make_names(names: list[str]) -> str:
            if len(names) == 1:
                return names[0]
            else:
                return ", ".join(names[:-1]) + " und " + names[-1]

        ack_message = EmailMessage()
        ack_message.set_content(
            f"""
            Liebe Familie {last_name},<br/>
            <br/>
            Vielen Dank für die Anmeldung von {make_names(form_data["child_first_name"])} \
            zum Probetraining.<br/>
            <br/>
            Einer unserer Trainer wird sich in Kürze bei euch melden und die Anmeldung mit \
            einem Termin zum ersten Training bestätigen. Falls ihr in der Zwischenzeit \
            weitere Fragen habt, findet ihr Infos <a href="{domain}/kontakt">hier</a>.<br/>
            <br/>
            Liebe Grüße,<br/>
            Das Joshinkan Team<br/>
            """
        )

        user_email = str(EmailUser(name=f"{first_name} {last_name}", email=email))
        ack_message["From"] = SMTP_USER
        ack_message["To"] = user_email
        ack_message["Cc"] = SMTP_CC
        ack_message["Reply-To"] = config.SMTP_REPLY_TO or config.SMTP_USER
        ack_message["Content-Type"] = "text/html; charset=utf-8"
        context.mailer.send_message(
            ack_message, to_addrs=[user_email] + SMTP_CC + SMTP_BCC
        )

        return Status.OK, ["message", "Email sent."]
    elif adult_valid:
        age = form_data["age"]

        message = EmailMessage()
        message["From"] = str(config.SMTP_USER)
        message["To"] = str(config.SMTP_REPLY_TO or config.SMTP_USER)
        message["Cc"] = [str(e) for e in config.SMTP_CC]
        message["Subject"] = "Anmeldung zum Probetraining: Erwachsene"
        message.set_content(
            f"""
            Neuanmeldung zum Probetraining für <b>Erwachsene</b>.<br/>
            <br/>
            Name: {first_name} {last_name}<br/>
            Alter: {age}<br/>
            Email: {email}<br/>
            Telefon: {phone}<br/>
        """,
            subtype="html",
        )
        context.mailer.send(
            message, to_addrs=[config.SMTP_USER] + config.SMTP_CC + config.SMTP_BCC
        )

        user_email = EmailUser(name=f"{first_name} {last_name}", email=email)
        ack_message = EmailMessage()
        ack_message["From"] = str(config.SMTP_USER)
        ack_message["To"] = str(user_email)
        ack_message["Cc"] = [str(e) for e in config.SMTP_CC]
        ack_message["Reply-To"] = str(config.SMTP_REPLY_TO or config.SMTP_USER)
        ack_message["Subject"] = "Joshinkan Werder Karate - Anmeldung zum Probetraining"
        ack_message.set_content(
            f"""
            Hallo {first_name},<br/>
            <br/>
            Vielen Dank für die Anmeldung zum Probetraining.<br/>
            <br/>
            Einer unserer Trainer wird sich in Kürze bei dir melden und die Anmeldung mit
            einem Termin zum ersten Training bestätigen. Falls du in der Zwischenzeit
            weitere Fragen hast, findest du Infos <a href="{domain}/kontakt">hier</a>.<br/>
            <br/>
            Liebe Grüße,<br/>
            Das Joshinkan Team<br/>
        """,
            subtype="html",
        )
        context.mailer.send(
            ack_message, to_addrs=[user_email] + config.SMTP_CC + config.SMTP_BCC
        )
        return Status.OK, {"message": "Email sent."}
    else:
        if (
            "child_first_name" in form_data
            or "child_last_name" in form_data
            or "child_age" in form_data
        ):
            error = child_error
        else:
            error = adult_error

        return Status.BAD_REQUEST, {"message": error.message}
