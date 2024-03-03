import logging

_console_handler = None


def setup_logging(loglevel_name: str):
    global _console_handler

    loglevel = getattr(logging, loglevel_name)
    if loglevel is None or not isinstance(loglevel, int):
        raise ValueError(
            f"Unknown loglevel name {loglevel_name}. Please choose from DEBUG,"
            " INFO, WARNING or ERROR"
        )

    _console_handler = logging.StreamHandler()
    _console_handler.setLevel(loglevel)

    formatter = logging.Formatter(fmt="%(levelname)s %(name)s %(asctime)s: %(message)s")
    _console_handler.setFormatter(formatter)


def get_logger(logger_name: str) -> logging.Logger:
    if _console_handler is None:
        raise RuntimeError("Logging not initialized. Call `setup_logging` first!")

    logger = logging.getLogger(logger_name)

    # NOTE(sven): Python logging can set the loglevel on the logger instance and
    # on the handler. Here we allow the logger to always log every level (DEBUG
    # and higher) but the handler has been restricted to the target log level in
    # `setup_logging`.
    logger.setLevel(logging.DEBUG)
    logger.addHandler(_console_handler)
    return logger
