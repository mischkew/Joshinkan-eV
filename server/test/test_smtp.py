import pytest
from joshinkan.smtp import EmailUser


def test_parse_description_missing_closing_caret():
    with pytest.raises(
        EmailUser.ParsingError, match=str(EmailUser.ParsingError.UNEXPECTED_FORMAT)
    ):
        EmailUser.from_description("<missing")


def test_parse_description_missing_opening_caret():
    with pytest.raises(
        EmailUser.ParsingError, match=str(EmailUser.ParsingError.UNEXPECTED_FORMAT)
    ):
        EmailUser.from_description("missing>")


def test_parse_description_text_after_email():
    with pytest.raises(
        EmailUser.ParsingError, match=str(EmailUser.ParsingError.UNEXPECTED_FORMAT)
    ):
        EmailUser.from_description("John Smith <john@example.com> shouldnotbehere")


def test_parse_description_carets_in_name():
    with pytest.raises(
        EmailUser.ParsingError, match=str(EmailUser.ParsingError.INVALID_EMAIL)
    ):
        EmailUser.from_description("Jo<hn Smith <john@example.com>")

    with pytest.raises(
        EmailUser.ParsingError, match=str(EmailUser.ParsingError.UNEXPECTED_FORMAT)
    ):
        EmailUser.from_description("Jo>hn Smith <john@example.com>")

    with pytest.raises(
        EmailUser.ParsingError, match=str(EmailUser.ParsingError.INVALID_EMAIL)
    ):
        EmailUser.from_description("J<o>hn Smith <john@example.com>")


def test_parse_description_invalid_email():
    with pytest.raises(
        EmailUser.ParsingError, match=str(EmailUser.ParsingError.INVALID_EMAIL)
    ):
        EmailUser.from_description("John Smith")

    with pytest.raises(
        EmailUser.ParsingError, match=str(EmailUser.ParsingError.INVALID_EMAIL)
    ):
        EmailUser.from_description("invalid@invalid")

    with pytest.raises(
        EmailUser.ParsingError, match=str(EmailUser.ParsingError.INVALID_EMAIL)
    ):
        EmailUser.from_description("<John Smith>")

    with pytest.raises(
        EmailUser.ParsingError, match=str(EmailUser.ParsingError.INVALID_EMAIL)
    ):
        EmailUser.from_description("<invalid@i.i>")


def test_parse_description_full_description():
    user = EmailUser.from_description("John Smith <john@example.com>")
    assert user.email == "john@example.com"
    assert user.name == "John Smith"


def test_parse_description_full_description_extra_whitespace():
    user = EmailUser.from_description("John Smith    <john@example.com>      ")
    assert user.email == "john@example.com"
    assert user.name == "John Smith"


def test_parse_description_email_only():
    user = EmailUser.from_description("<john@example.com>")
    assert user.email == "john@example.com"
    assert user.name is None


def test_parse_description_email_as_name():
    user = EmailUser.from_description("john@example.com")
    assert user.email == "john@example.com"
    assert user.name is None
