import pytest
from joshinkan import multipart


def test_flat_form_data(shared_datadir):
    CONTENT_TYPE = (
        "multipart/form-data; boundary=----WebKitFormBoundaryiB5iskbmcAfH1zPo"
    )
    body = (shared_datadir / "adult_registration.txt").read_text()
    form_data = multipart.parse(body=body, content_type=CONTENT_TYPE)
    assert form_data["first_name"] == "sven"
    assert form_data["last_name"] == "mkw"
    assert form_data["email"] == "sven.mkw@gmail.com"
    assert form_data["phone"] == "123456789"
    assert form_data["age"] == "23"
    assert form_data["privacy"] == "on"


def test_invalid_boundary_1(shared_datadir):
    CONTENT_TYPE = (
        "multipart/form-data; boundary-xxx=----WebKitFormBoundaryJBxGtknRPIBvH5oj"
    )
    body = (shared_datadir / "adult_registration.txt").read_text()
    with pytest.raises(ValueError) as error:
        form_data = multipart.parse(body=body, content_type=CONTENT_TYPE)
    assert "Could not parse" in str(error)


def test_invalid_boundary_2(shared_datadir):
    CONTENT_TYPE = "multipart/form-data; boundary="
    body = (shared_datadir / "adult_registration.txt").read_text()
    with pytest.raises(ValueError) as error:
        form_data = multipart.parse(body=body, content_type=CONTENT_TYPE)
    assert "Could not parse" in str(error)


def test_mismatching_boundary(shared_datadir):
    CONTENT_TYPE = (
        "multipart/form-data; boundary=----WebKitFormBoundaryJBxGtknRPIBvH5oj"
    )
    body = (shared_datadir / "adult_registration.txt").read_text()

    with pytest.raises(ValueError) as error:
        form_data = multipart.parse(body=body, content_type=CONTENT_TYPE)
    assert "Boundary not found" in str(error)


def test_missing_end_boundary(shared_datadir):
    CONTENT_TYPE = (
        "multipart/form-data; boundary=----WebKitFormBoundaryJBxGtknRPIBvH5oj"
    )
    body = (shared_datadir / "children_registration.txt").read_text()
    body = body[:-2]

    with pytest.raises(ValueError) as error:
        form_data = multipart.parse(body=body, content_type=CONTENT_TYPE)
    assert "Invalid end boundary" in str(error)


def test_missing_content_disposition_header(shared_datadir):
    CONTENT_TYPE = (
        "multipart/form-data; boundary=----WebKitFormBoundaryJBxGtknRPIBvH5oj"
    )
    body = (shared_datadir / "no_content_disposition_header.txt").read_text()

    with pytest.raises(ValueError) as error:
        form_data = multipart.parse(body=body, content_type=CONTENT_TYPE)
    assert "content disposition" in str(error)


def test_list_form_data(shared_datadir):
    CONTENT_TYPE = (
        "multipart/form-data; boundary=----WebKitFormBoundaryJBxGtknRPIBvH5oj"
    )
    body = (shared_datadir / "children_registration.txt").read_text()
    form_data = multipart.parse(body=body, content_type=CONTENT_TYPE)
    assert form_data["first_name"] == "Dad"
    assert form_data["last_name"] == "Fam"
    assert form_data["email"] == "fam@mail.com"
    assert form_data["phone"] == "049127495"
    assert form_data["age"] == ""
    assert form_data["parents_consent"] == "on"
    assert form_data["privacy"] == "on"
    assert form_data["child_first_name"] == ["Boi", "Girl"]
    assert form_data["child_last_name"] == ["Fam", "Fam"]
    assert form_data["child_age"] == ["17", "16"]
