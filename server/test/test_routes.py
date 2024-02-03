import pytest

# from your_module import Client, ServerContext, User, SMTP
from joshinkan.config import Config
from joshinkan.routes import AppContext, router
from joshinkan.httpd import make_app, Client
from unittest.mock import Mock
from smtplib import SMTP


@pytest.fixture
def client():
    config = Config()
    smtp = Mock(spec=SMTP)
    context = AppContext(smtp=smtp)

    router.set_config(config)
    router.set_context(context)

    app = make_app(router)
    return Client(app)


def test_register_adult(client):
    # TODO(sven): Can we read the full request with header and body?
    response = client.get("/adult-registration")
    assert response.status == 200
    assert response.json is not None
    assert response.flat_json()["message"] == "Email sent."
    assert len(client.context.smtp_stub.mails) == 2

    registration_mail = client.context.smtp_stub.mails[0]
    assert registration_mail.subject == "Anmeldung zum Probetraining: Erwachsene"
    assert "Name: sven mkw" in registration_mail.body
    assert "Alter: 23" in registration_mail.body
    assert "Email: sven.mkw@gmail.com" in registration_mail.body
    assert "Telefon: 123456789" in registration_mail.body

    acknowledgement_mail = client.context.smtp_stub.mails[1]
    assert (
        acknowledgement_mail.subject
        == "Joshinkan Werder Karate - Anmeldung zum Probetraining"
    )
    assert "Hallo sven" in acknowledgement_mail.body
    assert (
        "Vielen Dank für die Anmeldung zum Probetraining." in acknowledgement_mail.body
    )


def test_register_no_privacy(client):
    response = client.request("registration-no-privacy")
    assert response.status == 400
    assert response.json is not None
    assert response.flat_json()["error"] == "Form data could not be parsed."

    text = response.read()
    assert "400 Bad Request" in text


def test_register_child(client):
    response = client.request("child-registration")
    assert response.status == 200
    assert response.json is not None
    assert response.flat_json()["message"] == "Email sent."
    assert len(client.context.smtp_stub.mails) == 2

    registration_mail = client.context.smtp_stub.mails[0]
    assert registration_mail.subject == "Anmeldung zum Probetraining: Kinder (1)"
    assert "Name: Boi Fam" in registration_mail.body
    assert "Alter: 17" in registration_mail.body
    assert "Name: Girl Fam" not in registration_mail.body
    assert "Alter: 16" not in registration_mail.body
    assert "Name: Dad Fam" in registration_mail.body
    assert "Email: fam@mail.com" in registration_mail.body
    assert "Telefon: 04912847" in registration_mail.body

    acknowledgement_mail = client.context.smtp_stub.mails[1]
    assert (
        acknowledgement_mail.subject
        == "Joshinkan Werder Karate - Anmeldung zum Probetraining"
    )
    assert "Liebe Familie Fam" in acknowledgement_mail.body
    assert (
        "Vielen Dank für die Anmeldung von Boi zum Probetraining."
        in acknowledgement_mail.body
    )


def test_register_children(client):
    response = client.request("children-registration")
    assert response.status == 200
    assert response.json is not None
    assert response.flat_json()["message"] == "Email sent."
    assert len(client.context.smtp_stub.mails) == 2

    registration_mail = client.context.smtp_stub.mails[0]
    assert registration_mail.subject == "Anmeldung zum Probetraining: Kinder (2)"
    assert "Name: Boi Fam" in registration_mail.body
    assert "Alter: 17" in registration_mail.body
    assert "Name: Girl Fam" in registration_mail.body
    assert "Alter: 16" in registration_mail.body
    assert "Name: Dad Fam" in registration_mail.body
    assert "Email: fam@mail.com" in registration_mail.body
    assert "Telefon: 049127495" in registration_mail.body

    acknowledgement_mail = client.context.smtp_stub.mails[1]
    assert (
        acknowledgement_mail.subject
        == "Joshinkan Werder Karate - Anmeldung zum Probetraining"
    )
    assert "Liebe Familie Fam" in acknowledgement_mail.body
    assert (
        "Vielen Dank für die Anmeldung von Boi und Girl zum Probetraining."
        in acknowledgement_mail.body
    )


def test_send_email_adult():
    smtp_email = "your_smtp_email"
    smtp_password = "your_smtp_password"
    smtp_host = "smtps://smtp.gmail.com:465"

    smtp = SMTP(email=smtp_email, password=smtp_password, hostname=smtp_host)
    context = ServerContext(
        domain="http://localhost:3000",
        sender=User(name="Sender", email=smtp_email),
        smtp=smtp,
        reply_to=User(name="ReplyTo", email="sven.mkw+replyto@gmail.com"),
        cc=[User(name="CC1", email="sven.mkw+cc1@gmail.com")],
        bcc=[User(name="CC2", email="sven.mkw+bcc1@gmail.com")],
    )
    client = Client(context=context)
    response = client.request("adult-registration")
    assert response.status == 200
    assert response.json is not None
    assert response.flat_json()["message"] == "Email sent."


def test_send_email_children():
    smtp_email = "your_smtp_email"
    smtp_password = "your_smtp_password"
    smtp_host = "smtps://smtp.gmail.com:465"

    smtp = SMTP(email=smtp_email, password=smtp_password, hostname=smtp_host)
    context = ServerContext(
        domain="http://localhost:3000",
        sender=User(name="Sender", email=smtp_email),
        smtp=smtp,
        reply_to=User(name="ReplyTo", email="sven.mkw+replyto@gmail.com"),
        cc=[User(name="CC1", email="sven.mkw+cc1@gmail.com")],
        bcc=[User(name="CC2", email="sven.mkw+bcc1@gmail.com")],
    )
    client = Client(context=context)
    response = client.request("children-registration")
    assert response.status == 200
    assert response.json is not None
    assert response.flat_json()["message"] == "Email sent."
