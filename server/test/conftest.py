import pytest
import os
from pathlib import Path

from joshinkan.logger import setup_logging

setup_logging("DEBUG")


@pytest.fixture
def global_datadir():
    """Global datadir under `backend/test/data`"""
    return Path(__file__).parent / "data"


@pytest.fixture
def shared_datadir(request):
    """Shared datadir for each subfolder under `backend/test/path/to/subdir/data`"""
    return Path(request.fspath.dirname) / "data"


@pytest.fixture
def datadir(request):
    """Datadir for each individual test under
    `backend/test/path/to/subdir/test_mytest` for a test file named `test_mytest.py`"""
    return Path(os.path.splitext(request.module.__file__)[0])
