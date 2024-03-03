from dataclasses import dataclass
import textwrap
import pytest

# from your_module import Client, ServerContext, User, SMTP
from joshinkan.config import Config
from joshinkan.routes import AppContext, router
from joshinkan.httpd import make_app, Client
from joshinkan.smtp import Mailer, EmailUser
from unittest.mock import Mock


@pytest.fixture
def client():
    config = Config(
        SMTP_USER=EmailUser.from_description("sender@example.com"),
        SMTP_CC=[
            EmailUser.from_description("cc@example.com"),
            EmailUser.from_description("cc2@example.com"),
        ],
        SMTP_BCC=[
            EmailUser.from_description("bcc@example.com"),
            EmailUser.from_description("bcc2@example.com"),
        ],
        SMTP_PASSWORD="password",
    )
    mailer = Mock(spec=Mailer)
    context = AppContext(mailer=mailer)

    router.set_config(config)
    router.set_context(context)

    app = make_app(router)
    return Client(app)


@dataclass
class RequestData:
    headers: dict
    body: str


@pytest.fixture
def adult_registration() -> RequestData:
    return RequestData(
        headers={
            "Content-Type": "multipart/form-data; boundary=----WebKitFormBoundaryiB5iskbmcAfH1zPo",
            "Content-Length": "618",
        },
        body=textwrap.dedent(
            """\
            ------WebKitFormBoundaryiB5iskbmcAfH1zPo
            Content-Disposition: form-data; name="first_name"

            sven
            ------WebKitFormBoundaryiB5iskbmcAfH1zPo
            Content-Disposition: form-data; name="last_name"

            mkw
            ------WebKitFormBoundaryiB5iskbmcAfH1zPo
            Content-Disposition: form-data; name="email"

            sven.mkw@gmail.com
            ------WebKitFormBoundaryiB5iskbmcAfH1zPo
            Content-Disposition: form-data; name="phone"

            123456789
            ------WebKitFormBoundaryiB5iskbmcAfH1zPo
            Content-Disposition: form-data; name="age"

            23
            ------WebKitFormBoundaryiB5iskbmcAfH1zPo
            Content-Disposition: form-data; name="privacy"

            on
            ------WebKitFormBoundaryiB5iskbmcAfH1zPo--
            """
        ),
    )


@pytest.fixture
def register_no_privacy() -> RequestData:
    return RequestData(
        headers={
            "Content-Type": "multipart/form-data; boundary=----WebKitFormBoundaryiB5iskbmcAfH1zPo",
            "Content-Length": "619",
        },
        body=textwrap.dedent(
            """\
            ------WebKitFormBoundaryiB5iskbmcAfH1zPo
            Content-Disposition: form-data; name="first_name"

            sven
            ------WebKitFormBoundaryiB5iskbmcAfH1zPo
            Content-Disposition: form-data; name="last_name"

            mkw
            ------WebKitFormBoundaryiB5iskbmcAfH1zPo
            Content-Disposition: form-data; name="email"

            sven.mkw@gmail.com
            ------WebKitFormBoundaryiB5iskbmcAfH1zPo
            Content-Disposition: form-data; name="phone"

            123456789
            ------WebKitFormBoundaryiB5iskbmcAfH1zPo
            Content-Disposition: form-data; name="age"

            23
            ------WebKitFormBoundaryiB5iskbmcAfH1zPo
            Content-Disposition: form-data; name="privacy"

            off
            ------WebKitFormBoundaryiB5iskbmcAfH1zPo--
            """
        ),
    )


@pytest.fixture
def child_registration() -> RequestData:
    return RequestData(
        headers={
            "Content-Type": "multipart/form-data; boundary=----WebKitFormBoundary8uvuEcsk7hsemph9",
            "Content-Length": "1010",
        },
        body=textwrap.dedent(
            """\
            ------WebKitFormBoundary8uvuEcsk7hsemph9
            Content-Disposition: form-data; name="child_first_name[]"

            Boi
            ------WebKitFormBoundary8uvuEcsk7hsemph9
            Content-Disposition: form-data; name="child_last_name[]"

            Fam
            ------WebKitFormBoundary8uvuEcsk7hsemph9
            Content-Disposition: form-data; name="child_age[]"

            17
            ------WebKitFormBoundary8uvuEcsk7hsemph9
            Content-Disposition: form-data; name="first_name"

            Dad
            ------WebKitFormBoundary8uvuEcsk7hsemph9
            Content-Disposition: form-data; name="last_name"

            Fam
            ------WebKitFormBoundary8uvuEcsk7hsemph9
            Content-Disposition: form-data; name="email"

            fam@mail.com
            ------WebKitFormBoundary8uvuEcsk7hsemph9
            Content-Disposition: form-data; name="phone"

            04912847
            ------WebKitFormBoundary8uvuEcsk7hsemph9
            Content-Disposition: form-data; name="age"


            ------WebKitFormBoundary8uvuEcsk7hsemph9
            Content-Disposition: form-data; name="parents_consent"

            on
            ------WebKitFormBoundary8uvuEcsk7hsemph9
            Content-Disposition: form-data; name="privacy"

            on
            ------WebKitFormBoundary8uvuEcsk7hsemph9--
            """
        ),
    )


@pytest.fixture
def children_registration() -> RequestData:
    return RequestData(
        headers={
            "Content-Type": "multipart/form-data; boundary=----WebKitFormBoundaryJBxGtknRPIBvH5oj",
            "Content-Length": "1316",
        },
        body=textwrap.dedent(
            """\
            ------WebKitFormBoundaryJBxGtknRPIBvH5oj
            Content-Disposition: form-data; name="child_first_name[]"

            Boi
            ------WebKitFormBoundaryJBxGtknRPIBvH5oj
            Content-Disposition: form-data; name="child_last_name[]"

            Fam
            ------WebKitFormBoundaryJBxGtknRPIBvH5oj
            Content-Disposition: form-data; name="child_age[]"

            17
            ------WebKitFormBoundaryJBxGtknRPIBvH5oj
            Content-Disposition: form-data; name="child_first_name[]"

            Girl
            ------WebKitFormBoundaryJBxGtknRPIBvH5oj
            Content-Disposition: form-data; name="child_last_name[]"

            Fam
            ------WebKitFormBoundaryJBxGtknRPIBvH5oj
            Content-Disposition: form-data; name="child_age[]"

            16
            ------WebKitFormBoundaryJBxGtknRPIBvH5oj
            Content-Disposition: form-data; name="first_name"

            Dad
            ------WebKitFormBoundaryJBxGtknRPIBvH5oj
            Content-Disposition: form-data; name="last_name"

            Fam
            ------WebKitFormBoundaryJBxGtknRPIBvH5oj
            Content-Disposition: form-data; name="email"

            fam@mail.com
            ------WebKitFormBoundaryJBxGtknRPIBvH5oj
            Content-Disposition: form-data; name="phone"

            049127495
            ------WebKitFormBoundaryJBxGtknRPIBvH5oj
            Content-Disposition: form-data; name="age"


            ------WebKitFormBoundaryJBxGtknRPIBvH5oj
            Content-Disposition: form-data; name="parents_consent"

            on
            ------WebKitFormBoundaryJBxGtknRPIBvH5oj
            Content-Disposition: form-data; name="privacy"

            on
            ------WebKitFormBoundaryJBxGtknRPIBvH5oj--
            """
        ),
    )


def test_register_adult(client: Client, adult_registration: RequestData):
    # TODO(sven): Can we read the full request with header and body?
    response = client.post(
        "/trial-registration",
        headers=adult_registration.headers,
        body=adult_registration.body,
    )
    assert response.status == 200
    assert response.json()["message"] == "Email sent."
    assert client.app.context.mailer.send.call_count == 2

    registration_mail = client.app.context.mailer.send.call_args_list[0].args[0]
    assert registration_mail["Subject"] == "Anmeldung zum Probetraining: Erwachsene"
    body = registration_mail.get_content()
    assert "Name: sven mkw" in body
    assert "Alter: 23" in body
    assert "Email: sven.mkw@gmail.com" in body
    assert "Telefon: 123456789" in body

    acknowledgement_mail = client.app.context.mailer.send.call_args_list[1].args[0]
    assert (
        acknowledgement_mail["Subject"]
        == "Joshinkan Werder Karate - Anmeldung zum Probetraining"
    )
    body = acknowledgement_mail.get_content()
    assert "Hallo sven" in body
    assert "Vielen Dank für die Anmeldung zum Probetraining." in body


def test_register_no_privacy(client: Client, register_no_privacy: RequestData):
    response = client.post(
        "/trial-registration",
        headers=register_no_privacy.headers,
        body=register_no_privacy.body,
    )
    assert response.status == 400
    assert "'privacy' is off" in response.json()["message"]


def test_register_child(client: Client, child_registration: RequestData):
    response = client.post(
        "/trial-registration",
        headers=child_registration.headers,
        body=child_registration.body,
    )
    assert response.status == 200
    assert response.json()["message"] == "Email sent."
    assert client.app.context.mailer.send.call_count == 2

    registration_mail = client.app.context.mailer.send.call_args_list[0].args[0]
    assert registration_mail["Subject"] == "Anmeldung zum Probetraining: Kinder (1)"
    body = registration_mail.get_content()
    assert "Name: Boi Fam" in body
    assert "Alter: 17" in body
    assert "Name: Girl Fam" not in body
    assert "Alter: 16" not in body
    assert "Name: Dad Fam" in body
    assert "Email: fam@mail.com" in body
    assert "Telefon: 04912847" in body
    assert registration_mail["From"] == "sender@example.com"

    acknowledgement_mail = client.app.context.mailer.send.call_args_list[1].args[0]
    assert (
        acknowledgement_mail["Subject"]
        == "Joshinkan Werder Karate - Anmeldung zum Probetraining"
    )
    body = acknowledgement_mail.get_content()
    assert "Liebe Familie Fam" in body
    print(body)
    assert "Vielen Dank für die Anmeldung von Boi zum Probetraining." in body


def test_register_children(client: Client, children_registration: RequestData):
    response = client.post(
        "/trial-registration",
        headers=children_registration.headers,
        body=children_registration.body,
    )
    assert response.status == 200
    assert response.json()["message"] == "Email sent."
    assert client.app.context.mailer.send.call_count == 2

    registration_mail = client.app.context.mailer.send.call_args_list[0].args[0]
    assert registration_mail["Subject"] == "Anmeldung zum Probetraining: Kinder (2)"
    body = registration_mail.get_content()
    assert "Name: Boi Fam" in body
    assert "Alter: 17" in body
    assert "Name: Girl Fam" in body
    assert "Alter: 16" in body
    assert "Name: Dad Fam" in body
    assert "Email: fam@mail.com" in body
    assert "Telefon: 049127495" in body

    acknowledgement_mail = client.app.context.mailer.send.call_args_list[1].args[0]
    assert (
        acknowledgement_mail["Subject"]
        == "Joshinkan Werder Karate - Anmeldung zum Probetraining"
    )
    body = acknowledgement_mail.get_content()
    assert "Liebe Familie Fam" in body
    assert "Vielen Dank für die Anmeldung von Boi und Girl zum Probetraining." in body
