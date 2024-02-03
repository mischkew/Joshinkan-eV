import pytest
from joshinkan.config import Config
from joshinkan.httpd import (
    WSGIApp,
    make_app,
    Client,
    Router,
    Request,
    Response,
    Status,
    expect_json,
    expect_params,
    expect_form_data,
)
from dataclasses import dataclass
from joshinkan.validation import Schema, ListOf
import http.client
from functools import partialmethod
import urllib.request


@pytest.fixture(scope="module")
def dummy_app() -> WSGIApp:
    R = Router()

    @R.get("/exists_int")
    def exists_int(request: Request) -> Response:
        return 200, "Yay"

    @R.get("/exists_status")
    def exists_status(request: Request) -> Response:
        return Status.OK, "Yay with Status"

    @R.get("/json")
    def json_route(request: Request) -> Response:
        return 200, {"message": "hi sailor"}

    @R.get("/bad-request")
    def json_route(request: Request) -> Response:
        return 400, None

    @R.get("/crashing")
    def json_route(request: Request) -> Response:
        raise ValueError("wrong")

    @R.get("/query_test")
    def query_test(request: Request) -> Response:
        return 200, request.parameters

    @R.post("/expect_json")
    @expect_json(Schema({"foo": ListOf(int)}))
    def expect_json_route(request: Request) -> Response:
        return 200, request.json()

    @R.post("/expect_params")
    @expect_params(Schema({"foo": ListOf(str)}))
    def expect_params_route(request: Request) -> Response:
        return 200, request.parameters

    @R.post("/expect_form")
    @expect_form_data(Schema({"foo": ListOf(str)}))
    def expect_params_route(request: Request) -> Response:
        return 200, request.form_data()

    R.set_config(Config())
    return make_app(R)


@pytest.fixture(scope="module")
def dummy_client(dummy_app) -> Client:
    return Client(dummy_app)


class End2EndClient:
    @dataclass
    class Response:
        headers: dict
        status: Status
        body: str

        def json(self) -> dict:
            return json.loads(self.body)

        @classmethod
        def from_http_response(
            cls,
            response: http.client.HTTPResponse,
        ) -> Response:
            return End2EndClient.Response(
                headers=dict(response.getheaders()),
                status=Status(response.status),
                body=response.read().decode("utf-8"),
            )

    def __init__(self, host: str):
        self.host = host

    def make_request(
        self, method: str, path: str, headers: dict = {}, body: str = ""
    ) -> Response:
        # http request with urrlib

        request = urllib.request.Request(
            f"{self.host}{path}",
            method=method,
            headers=headers,
            data=body.encode("utf-8") if len(body) > 0 else None,
        )
        with urllib.request.urlopen(request) as response:
            return self.Response.from_http_response(response)

    get = partialmethod(make_request, "GET")
    post = partialmethod(make_request, "POST")
    head = partialmethod(make_request, "HEAD")
    put = partialmethod(make_request, "PUT")
    patch = partialmethod(make_request, "PATCH")


@pytest.fixture()
def dummy_server(dummy_app) -> End2EndClient:
    from wsgiref.simple_server import make_server
    import threading

    def run_server():
        with make_server("0.0.0.0", 5001, dummy_app) as httpd:
            httpd.handle_request()

    t = threading.Thread(target=run_server)
    t.start()
    yield End2EndClient("http://localhost:5001")
    t.join()


def test_404(dummy_client):
    res = dummy_client.get("not-found")
    assert res.status == 404
    assert "Not Found" in res.body


def test_route_found_status_is_int(dummy_client):
    res = dummy_client.get("/exists_int")
    assert res.status == 200
    assert res.body == "Yay"


def test_route_found(dummy_client):
    res = dummy_client.get("/exists_status")
    assert res.status == 200
    assert res.body == "Yay with Status"


def test_route_wrong_method_not_found(dummy_client):
    res = dummy_client.post("/exists_status")
    assert res.status == 404


def test_route_leading_slash_required(dummy_client):
    res = dummy_client.post("exists_status")
    assert res.status == 404


def test_json_from_dict(dummy_client):
    res = dummy_client.get("/json")
    assert res.status == 200
    assert res.body == '{"message": "hi sailor"}'
    assert res.json() == {"message": "hi sailor"}


def test_custom_status(dummy_client):
    res = dummy_client.get("/bad-request")
    assert res.status == Status.BAD_REQUEST
    assert res.body == ""


def test_server_error_no_traceback(dummy_client):
    res = dummy_client.get("/crashing")
    assert res.status == 500
    assert "Internal Server Error" in res.body
    assert "ValueError" not in res.body


def test_server_error_with_traceback(dummy_client):
    config = dummy_client.app.config

    assert not config.PRINT_STACKTRACE
    with dummy_client.config("PRINT_STACKTRACE", True):
        assert config.PRINT_STACKTRACE
        res = dummy_client.get("/crashing")
    assert not config.PRINT_STACKTRACE
    assert res.status == 500
    assert "Internal Server Error" in res.body
    assert "ValueError" in res.body


def test_parse_query_string(dummy_client: Client):
    res = dummy_client.get("/query_test?foo=bar&baz=qux")
    assert res.json() == {"foo": "bar", "baz": "qux"}


def test_parse_query_string_with_repeated_keys(dummy_client: Client):
    res = dummy_client.get("/query_test?foo=bar&foo=baz")
    assert res.json() == {"foo": ["bar", "baz"]}


def test_parse_query_string_empty(dummy_client: Client):
    res = dummy_client.get("/query_test")
    assert res.json() == {}


def test_expect_json(dummy_client):
    res = dummy_client.post("/expect_json", body={"foo": [1, 2, 3]})
    assert res.json() == {"foo": [1, 2, 3]}


def test_expect_json_mismatch(dummy_client):
    res = dummy_client.post("/expect_json", body={"bar": "bar"})
    assert res.status == 400
    assert res.json()["message"] == "The key 'foo' is missing."


def test_expect_json_empty(dummy_client):
    res = dummy_client.post("/expect_json")
    assert res.status == 400
    assert res.json()["message"] == "The request body could not be parsed or is empty."


def test_expect_params(dummy_client):
    res = dummy_client.post("/expect_params?foo=1&foo=2&foo=3")
    assert res.status == 200
    assert res.json() == {"foo": ["1", "2", "3"]}


def test_expect_params_mismatch(dummy_client):
    res = dummy_client.post("/expect_params?bar=1&foo=2&foo=3")
    assert res.status == 400
    assert res.json() == {"message": "The key 'bar' is not defined in the schema."}


def test_expect_params_empty(dummy_client):
    res = dummy_client.post("/expect_params")
    assert res.status == 400
    assert res.json()["message"] == "The key 'foo' is missing."


def test_expect_form(dummy_client, shared_datadir):
    res = dummy_client.post(
        "/expect_form",
        headers={
            "Content-Type": "multipart/form-data; boundary=----WebKitFormBoundaryiB5iskbmcAfH1zPo"
        },
        body=(shared_datadir / "form.txt").read_text(),
    )
    assert res.status == 200
    assert res.json() == {"foo": ["1", "2", "3"]}


def test_expect_form_mismatch(dummy_client, shared_datadir):
    res = dummy_client.post(
        "/expect_form",
        headers={
            "Content-Type": "multipart/form-data; boundary=----WebKitFormBoundaryiB5iskbmcAfH1zPo"
        },
        body=(shared_datadir / "adult_registration.txt").read_text(),
    )
    assert res.status == 400
    assert res.json()["message"] == "The key 'foo' is missing."


def test_expect_form_empty(dummy_client, shared_datadir):
    res = dummy_client.post("/expect_form")
    assert res.status == 400
    assert res.json()["message"] == "The request body could not be parsed or is empty."


@pytest.mark.end2end
def test_end2end_request(dummy_server: End2EndClient):
    res = dummy_server.get("/exists_status")
    assert res.status == 200
    assert res.body == "Yay with Status"
