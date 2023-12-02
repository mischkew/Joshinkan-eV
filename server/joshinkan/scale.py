import os
import subprocess
import sys
from dataclasses import dataclass
from enum import IntFlag
from typing import Optional


class CommandMode(IntFlag):
    DEFAULT = 0
    TRACE = 1
    EXIT_ON_ERROR = 2


@dataclass
class CommandResult:
    command: str
    stdout: Optional[str]
    stderr: Optional[str]
    exit_code: int


class Shell:
    def __init__(self):
        self.mode = CommandMode.DEFAULT

    def set_mode(self, mode: CommandMode):
        self.mode = mode

    def isset_mode(self, mode: CommandMode) -> bool:
        if mode is CommandMode.DEFAULT:
            return self.mode == CommandMode.DEFAULT

        return (self.mode & mode) == mode

    def trace(self):
        self.set_mode(self.mode | CommandMode.TRACE)

    def exit_on_error(self):
        self.set_mode(self.mode | CommandMode.EXIT_ON_ERROR)

    def build_command(self, *commands: str, kwargs: Optional[dict] = None) -> str:
        def make_list(kwargs):
            kwargs_list = []
            for key, value in kwargs.items():
                if value is None:
                    continue

                kwargs_list.append(str(key))
                if isinstance(value, dict):
                    kwargs_list.extend(make_list(value))
                elif isinstance(value, list):
                    kwargs_list.extend([str(item) for item in value])
                elif value != "":
                    kwargs_list.append(str(value))
            return kwargs_list

        words = []
        words.extend([str(command) for command in commands])
        if kwargs is not None:
            words.extend(make_list(kwargs))
        command = " ".join(words)
        return command

    def run(
        self,
        *commands: str,
        kwargs: Optional[dict] = None,
        stdin: Optional[str] = None,
        capture: bool = False,
    ) -> CommandResult:
        command = self.build_command(*commands, kwargs=kwargs)

        if self.isset_mode(CommandMode.TRACE):
            print(f"> {command}")

        result = subprocess.run(
            command,
            shell=True,
            capture_output=capture,
            text=True,
            input=stdin,
        )

        if self.isset_mode(CommandMode.EXIT_ON_ERROR) and result.returncode != 0:
            if result.stderr is not None:
                print("Process failed:")
                print(f"> {command}")
                print(result.stderr)
            sys.exit(result.returncode)

        return CommandResult(
            command=command,
            stdout=result.stdout,
            stderr=result.stderr,
            exit_code=result.returncode,
        )

    def env(self, name: str, value: str):
        """Set an environment variable."""
        if self.isset_mode(CommandMode.TRACE):
            print(f"Set environment variable {name} = {value}")
        assert isinstance(value, str)
        os.environ[name] = value

    def envs(self, env_mapping: dict[str, str]):
        """Set multiple environment variables."""
        for name, value in env_mapping.items():
            self.env(name, value)

    def __call__(self, *commands: str, **kwargs) -> CommandResult:
        """Alias for run"""
        return self.run(*commands, **kwargs)


shell = Shell()
