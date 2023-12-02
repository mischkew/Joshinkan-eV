import os

from .httpd import Router, Response, expect_json, Request, Status
from .validation import Schema, DictOf, Values
from .logger import get_logger
from joshinkan import multipart

logger = get_logger(__name__)
router = Router()


@router.get("/env")
def print_env(request: Request) -> Response:
    return Status.OK, dict(os.environ)


@router.get("/trial-registration")
def register(request: Request) -> Response:
    form_data = request.form_data()
    if form_data is None:
        return Status.BAD_REQUEST, {"error": "Bad form data or content type"}

    return Status.OK, form_data
