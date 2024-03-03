import urllib.parse as parse
from contextlib import contextmanager
from enum import Enum, auto, IntEnum
import dataclasses
from dataclasses import dataclass
from typing import Callable, Optional, Dict, Union, Iterable, Iterator, Any, Protocol
from functools import partialmethod, partial
import traceback
import json
import sys
from wsgiref.util import setup_testing_defaults, guess_scheme
from io import BytesIO

from .config import Config
from .logger import get_logger
from .validation import Schema, InvalidSchema
import joshinkan.multipart as multipart

logger = get_logger(__name__)


class Status(IntEnum):
    OK = 200
    BAD_REQUEST = 400
    NOT_FOUND = 404
    INTERNAL_SERVER_ERROR = 500

    def __str__(self) -> str:
        if self == Status.OK:
            return "200 OK"
        elif self == Status.BAD_REQUEST:
            return "400 Bad Request"
        elif self == Status.NOT_FOUND:
            return "404 Not Found"
        elif self == Status.INTERNAL_SERVER_ERROR:
            return "500 Internal Server Error"

    @classmethod
    def from_string(cls, status_string: str) -> "Status":
        for status in cls:
            if status_string.startswith(str(status.value)):
                return status
        raise ValueError(f"Unknown status {status_string}")


# See: https://peps.python.org/pep-3333/#environ-variables
WSGIEnv = Dict
# See: https://peps.python.org/pep-3333/#the-start-response-callable
WSGIStartResponse = Callable[
    [
        str,
        list[
            tuple[
                str,
                str,
            ]
        ],
    ],
    None,
]
# See: https://peps.python.org/pep-3333/#buffering-and-streaming
WSGIResponse = Union[Iterable[bytes], Iterator[bytes]]
Response = tuple[int, Optional[dict]]
RequestHandler = Callable[[WSGIEnv], Response]


def normalize_headers(headers: dict) -> dict:
    return {key.lower(): value for key, value in headers.items()}


class Request:
    def __init__(self, environ: WSGIEnv):
        self.environ = environ
        self._parameters: Optional[dict[str, Union[str, list[str]]]] = None
        self._body: Optional[str] = None

    @property
    def parameters(self) -> dict[str, Union[list[str]]]:
        if self._parameters is None:
            self._parameters = parse.parse_qs(self.environ["QUERY_STRING"])
            for key, value in self._parameters.items():
                if len(value) == 1:
                    self._parameters[key] = value[0]
        return self._parameters

    @property
    def body(self) -> str:
        if self._body is None:
            self._body = self.environ["wsgi.input"].read().decode("utf8")
        return self._body

    def json(self) -> dict:
        return json.loads(self.body)

    def form_data(self) -> Optional[dict]:
        content_type = self.environ.get("CONTENT_TYPE", None)
        if content_type is None:
            return None
        try:
            return multipart.parse(body=self.body, content_type=content_type)
        except ValueError as error:
            logger.error(error)
            return None


@dataclass
class Route:
    path: str
    method: str
    handler: RequestHandler


class RouterException(Exception):
    pass


class AppConfig(Protocol):
    PRINT_STACKTRACE: bool
    LOGLEVEL: str


class Router:
    def __init__(self):
        # NOTE(sven): Map from path -> method -> Route
        self.routes: dict[str, dict[str, Route]] = {}
        self.context: Optional[Any] = None
        self.config: Optional[AppConfig] = None

    def has_route(self, method: str, path: str) -> bool:
        return path in self.routes and method in self.routes[path]

    def make_route(self, method: str, path: str) -> Callable[[RequestHandler], None]:
        """This method is supposed to be used as a decorator on a route
        function. Registers the decorated handler in the router."""
        assert len(path) > 0, "Route path cannot be an empty string"
        assert path[0] == "/", f"Route '{path}' must start with a forward-slash!"

        def wrapper(handler: RequestHandler):
            route = Route(path, method, handler)

            if self.has_route(method, path):
                raise RouterException(f"The route {route} already exists!")

            if route.path not in self.routes:
                self.routes[route.path] = {}

            self.routes[route.path][route.method] = route

            # NOTE(sven): This return allows us to call the handler from test
            # methods without having to look it up in the router
            return handler

        return wrapper

    def get_route(self, method: str, path: str) -> Route:
        return self.routes[path][method]

    def with_context(self):
        def wrapper(handler: RequestHandler) -> Response:
            def handler_with_context(*args, **kwargs) -> Response:
                if self.context is None:
                    raise ValueError(
                        "Context is not set. Use `router.set_context` when building the app."
                    )

                return handler(*args, **kwargs, context=self.context)

            return handler_with_context

        return wrapper

        # TODO(sven): Add set_context method which can be an any object on the
        # route. Will be configred when app is built, also helpful for
        # tests. This decorator adds a context kwarg to the request handler. The
        # user can define the context class in the type hints. Should be used
        # for dependency injection instead of "global objects". Avoids mocking
        # in tests.

    def set_context(self, context: Any):
        self.context = context

    def with_config(self):
        def wrapper(handler: RequestHandler) -> Response:
            def handler_with_config(*args, **kwargs) -> Response:
                if self.config is None:
                    raise ValueError(
                        "Config is not set. Use `router.set_config` when building the app."
                    )
                return handler(*args, **kwargs, config=self.config)

            return handler_with_config

        return wrapper

    def set_config(self, config: AppConfig):
        self.config = config

    get = partialmethod(make_route, "GET")
    post = partialmethod(make_route, "POST")
    head = partialmethod(make_route, "HEAD")
    put = partialmethod(make_route, "PUT")
    patch = partialmethod(make_route, "PATCH")


class WSGIApp(Protocol):
    router: Router
    config: Config
    context: Any

    def __call__(
        self, environ: WSGIEnv, start_response: WSGIStartResponse
    ) -> WSGIResponse:
        ...


def make_app(router: Router) -> WSGIApp:
    if router.config is None:
        raise ValueError(
            "Config is not set. Use `router.set_config` when building the app."
        )

    def app(environ: WSGIEnv, start_response: WSGIStartResponse) -> WSGIResponse:
        logger.debug(environ)

        path = environ["PATH_INFO"]
        method = environ["REQUEST_METHOD"]

        if router.has_route(method, path):
            route = router.get_route(method, path)

            try:
                request = Request(environ)
                status, body = route.handler(request)

                # TODO(sven): Support setting custom headers in the route
                # handlers. Also, allow performing a non-json response, i.e. for
                # long polling or HTML.
                headers = {}
                headers = normalize_headers(headers)

                if type(body) == dict:
                    if "content-type" not in headers:
                        headers["content-type"] = "application/json"
                    if headers["content-type"] == "application/json":
                        body = json.dumps(body)

                if body == None:
                    body = ""

                if type(status) == int:
                    status = Status(status)

                start_response(str(status), list(headers.items()))
                return [bytes(body, encoding="utf8")]
            except Exception as error:
                tb = traceback.format_exc()
                logger.error(tb)

                start_response(
                    str(Status.INTERNAL_SERVER_ERROR),
                    [("Content-Type", "text/html; charset=utf-8")],
                )
                return [
                    b"<h1>Internal Server Error</h1>",
                    b"<pre>",
                    bytes(tb, encoding="utf8")
                    if router.config.PRINT_STACKTRACE
                    else b"",
                    b"</pre>",
                ]
        else:
            start_response(
                str(Status.NOT_FOUND), [("Content-Type", "text/html; charset=utf-8")]
            )
            return [
                b"<h1>Not Found</h1>",
                bytes(f"The {method} route at {path} does not exist.", encoding="utf8"),
            ]

    app.router = router
    app.config = router.config
    app.context = router.context
    return app


class ValidationType(Enum):
    PARAMETERS = auto()
    JSON_BODY = auto()
    FORM_DATA = auto()


def expect_schema(
    schema: Schema, validate: ValidationType = ValidationType.PARAMETERS
) -> Callable:
    """A decorator for routes. Applies the validation to the request parameters
    or the json body"""

    def wrapper(handler):
        def validation_handler(request: Request) -> Response:
            if validate is ValidationType.PARAMETERS:
                validation_object = request.parameters
            elif validate is ValidationType.JSON_BODY:
                try:
                    validation_object = request.json()
                except json.JSONDecodeError:
                    return 400, {
                        "message": "The request body could not be parsed or is empty."
                    }
            elif validate is ValidationType.FORM_DATA:
                validation_object = request.form_data()
                if validation_object is None:
                    return 400, {
                        "message": "The request body could not be parsed or is empty."
                    }
            else:
                raise ValueError(f"Unknown validation type {validate}")

            valid, error = schema.validate(validation_object)
            if not valid:
                logger.debug("Request validation failed")
                logger.debug(error)
                return 400, {"message": str(error.message)}
            else:
                return handler(request)

        return validation_handler

    return wrapper


expect_params = partial(expect_schema, validate=ValidationType.PARAMETERS)
expect_json = partial(expect_schema, validate=ValidationType.JSON_BODY)
expect_form_data = partial(expect_schema, validate=ValidationType.FORM_DATA)


class Client:
    """A client to make requests to the given application. Its only purpose is for unit testing."""

    @dataclass
    class Response:
        headers: dict
        status: Status
        body: str

        def json(self) -> dict:
            return json.loads(self.body)

    @contextmanager
    def config(self, key: str, value: Any):
        """A context manager to temporarily set a config value."""
        assert hasattr(self.app, "router")
        assert self.app.router.config is not None
        assert hasattr(self.app.router.config, key)
        backup = getattr(self.app.router.config, key)
        setattr(self.app.router.config, key, value)
        yield
        setattr(self.app.router.config, key, backup)

    def __init__(self, app: WSGIApp):
        self.app = app

    def make_request(
        self, method: str, url: str, headers: dict = {}, body: Union[str, dict] = ""
    ):
        # NOTE(sven): Normalize headers so we have some freedom when writing tests
        headers = normalize_headers(headers)

        environ = {}
        environ["REQUEST_METHOD"] = method.upper()
        if "?" in url:
            path, query = url.split("?", maxsplit=1)
        else:
            path, query = url, ""

        environ["PATH_INFO"] = parse.unquote(path, "iso-8859-1")
        environ["QUERY_STRING"] = query
        environ["CONTENT_TYPE"] = headers.get("content-type", "application/json")

        if type(body) == dict:
            body = json.dumps(body)
        if len(body) > 0:
            environ["wsgi.input"] = BytesIO(bytes(body, encoding="utf8"))
        environ["CONTENT_LENGTH"] = headers.get("content-length", len(body))

        for key, value in headers.items():
            key = key.replace("-", "_").upper()
            value = value.strip()
            if key in environ:
                continue  # skip content length, type, etc.

            if "HTTP_" + key in environ:
                environ["HTTP_" + key] += "," + value  # comma-separate multiple headers
            else:
                environ["HTTP_" + key] = value

        # NOTE(sven): This sets all environment variables a WSGI server would
        # set as default values, which means our values don't get
        # overwridden. They only get accessed when we don't provide them. This
        # method tries to do some guessing based on environment values we have
        # provided, so we call it last.
        setup_testing_defaults(environ)
        environ.setdefault(
            "HTTP_ORIGIN", f'{guess_scheme(environ)}://{environ["SERVER_NAME"]}'
        )

        status = None
        headers = None

        def start_response(status_string: str, header_list: list[tuple[str, str]]):
            nonlocal status, headers
            status = Status.from_string(status_string)
            headers = dict(header_list)

        response_chunks = self.app(environ, start_response)
        assert status is not None
        assert headers is not None

        response_body = b"".join(response_chunks).decode("utf8")
        return Client.Response(status=status, headers=headers, body=response_body)

    get = partialmethod(make_request, "GET")
    post = partialmethod(make_request, "POST")
    head = partialmethod(make_request, "HEAD")
    put = partialmethod(make_request, "PUT")
    patch = partialmethod(make_request, "PATCH")
