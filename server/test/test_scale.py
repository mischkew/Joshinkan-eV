import os
from pathlib import Path

import pytest

from joshinkan.scale import CommandMode, Shell, shell


def test_build_command():
    assert shell.build_command("echo hello world") == "echo hello world"
    assert shell.build_command("echo", "hello world") == "echo hello world"
    assert shell.build_command("echo", kwargs={"hello": "world"}) == "echo hello world"
    assert (
        shell.build_command("echo", kwargs={"hello": "world", "hidden": None})
        == "echo hello world"
    )
    assert (
        shell.build_command("echo", kwargs={"hello": "world", "number-support": 3.5})
        == "echo hello world number-support 3.5"
    )
    assert shell.build_command("echo", kwargs=None) == "echo"


def test_run_stdout():
    result = shell("echo hello world", capture=True)
    assert result.command == "echo hello world"
    assert result.stdout == "hello world\n"
    assert result.stderr == ""
    assert result.exit_code == 0


def test_run_stderr():
    result = shell("echo hello world 1>&2", capture=True)
    assert result.command == "echo hello world 1>&2"
    assert result.stderr == "hello world\n"
    assert result.stdout == ""
    assert result.exit_code == 0


def test_run_exit_code():
    result = shell("exit 2", capture=True)
    assert result.command == "exit 2"
    assert result.stderr == ""
    assert result.stdout == ""
    assert result.exit_code == 2


def test_run_stdin():
    result = shell("cat", stdin="hi sailor\n", capture=True)
    assert result.command == "cat"
    assert result.stderr == ""
    assert result.stdout == "hi sailor\n"
    assert result.exit_code == 0


def test_run_args():
    result = shell("echo", "hello", "world", capture=True)
    assert result.command == "echo hello world"
    assert result.stdout == "hello world\n"
    assert result.stderr == ""
    assert result.exit_code == 0


def test_run_kwargs_as_args():
    result = shell("echo", kwargs={"hello": "", "world": ""}, capture=True)
    assert result.command == "echo hello world"
    assert result.stdout == "hello world\n"
    assert result.stderr == ""
    assert result.exit_code == 0


def test_run_kwargs():
    result = shell(
        "echo",
        kwargs={"--name": "value", "--int": 5, "--value": None},
        capture=True,
    )
    assert result.command == "echo --name value --int 5"
    assert result.stderr == ""
    assert result.stdout == "--name value --int 5\n"
    assert result.exit_code == 0


def test_run_nested_kwargs():
    result = shell(
        "echo",
        kwargs={
            "--name": "value",
            "--int": 5,
            "sub": {
                "--command": "some-text",
            },
        },
        capture=True,
    )
    assert result.command == "echo --name value --int 5 sub --command some-text"
    assert result.stderr == ""
    assert result.stdout == "--name value --int 5 sub --command some-text\n"
    assert result.exit_code == 0


def test_run_kwargs_makes_path_to_str():
    result = shell(
        "echo",
        Path("./a-path"),
        kwargs={"--path": Path("../help")},
        capture=True,
    )
    assert result.command == "echo a-path --path ../help"
    assert result.stdout == "a-path --path ../help\n"
    assert result.stderr == ""
    assert result.exit_code == 0


def test_run_print_output_directly(capfd):
    result = shell.run("echo hello")
    assert result.stderr is None
    assert result.stdout is None

    captured = capfd.readouterr()
    assert captured.out == "hello\n"


@pytest.fixture
def unset_env():
    unset_keys = []

    def set_keys(*keys: list[str]) -> list[str]:
        unset_keys.extend(keys)

    yield set_keys

    for key in unset_keys:
        if key in os.environ:
            del os.environ[key]


def test_env(unset_env):
    unset_env("my-custom-key")
    assert os.environ.get("my-custom-key") is None

    shell.env("my-custom-key", "value")
    assert os.environ.get("my-custom-key") == "value"


def test_envs(unset_env):
    unset_env("my-custom-key", "my-other-key")
    assert os.environ.get("my-custom-key") is None
    assert os.environ.get("my-other-key") is None

    shell.envs({"my-custom-key": "value", "my-other-key": "value2"})
    assert os.environ.get("my-custom-key") == "value"
    assert os.environ.get("my-other-key") == "value2"


def test_set_mode():
    _shell = Shell()
    assert _shell.isset_mode(CommandMode.DEFAULT)
    assert not _shell.isset_mode(CommandMode.TRACE)

    _shell.set_mode(CommandMode.TRACE)
    assert not _shell.isset_mode(CommandMode.DEFAULT)
    assert _shell.isset_mode(CommandMode.TRACE)

    # NOTE(sven): DEFAULT mode can only be set on it's own. It's like disabling
    # all other modes.
    _shell.set_mode(_shell.mode | CommandMode.DEFAULT)
    assert not _shell.isset_mode(CommandMode.DEFAULT)
    assert _shell.isset_mode(CommandMode.TRACE)

    assert shell.isset_mode(CommandMode.DEFAULT)
    assert not shell.isset_mode(CommandMode.TRACE)


def test_set_mode_trace_shorthand():
    _shell = Shell()
    assert not _shell.isset_mode(CommandMode.TRACE)
    _shell.trace()
    assert _shell.isset_mode(CommandMode.TRACE)


def test_set_mode_exit_on_error_shorthand():
    _shell = Shell()
    assert not _shell.isset_mode(CommandMode.EXIT_ON_ERROR)
    _shell.exit_on_error()
    assert _shell.isset_mode(CommandMode.EXIT_ON_ERROR)


def test_run_with_trace(capfd):
    _shell = Shell()
    _shell.set_mode(CommandMode.TRACE)
    result = _shell.run("echo hello", capture=True)

    captured = capfd.readouterr()
    assert captured.out == "> echo hello\n"


def test_run_with_exit_on_error():
    _shell = Shell()
    with pytest.raises(SystemExit) as system_exit:
        _shell.set_mode(CommandMode.EXIT_ON_ERROR)
        _shell.run("exit 42")

    assert system_exit.value.code == 42


@pytest.mark.end2end
def test_shebang():
    test_script = Path(__file__).parent / "data" / "script.py"
    result = shell(test_script, capture=True)
    result.stdout == "hi sailor\n"
