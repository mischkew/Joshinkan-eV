from wsgiref.simple_server import make_server


def build_app():
    from inspect import getmembers, ismodule
    from .logger import setup_logging, get_logger
    from .config import Config

    config = Config()
    setup_logging(config.LOGLEVEL)
    logger = get_logger(__name__)
    logger.info(f"Config: {config}")

    from .httpd import make_app
    from .routes import router, AppContext

    context = AppContext.from_config(config)
    router.set_context(context)
    router.set_config(config)
    app = make_app(router)
    return app


def serve_gunicorn() -> None:
    import argparse
    from inspect import cleandoc
    from .scale import shell

    parser = argparse.ArgumentParser(description="Joshinkan server")
    parser.add_argument(
        "--host", default="0.0.0.0", help="Bind address. Default: 0.0.0.0"
    )
    parser.add_argument(
        "--port", default=5000, type=int, help="Port number. Default: 5000"
    )
    parser.add_argument(
        "--workers", default=4, type=int, help="Number of workers. Default: 4"
    )
    parser.add_argument(
        "--reload", action="store_true", help="Enable auto-reload. Default: False"
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        help=cleandoc(
            """Allows using a debugger without timeouts. Implies --reload and
            --worksers 1. Default: False"""
        ),
    )
    parser.add_argument(
        "--log-dir",
        help="Store gunicorn access and error logs in this directory. Default: Log to stdout",
    )

    args = parser.parse_args()

    if args.debug:
        args.reload = True
        args.workers = 1

    shell.trace()
    shell.exit_on_error()
    shell(
        "gunicorn",
        kwargs={
            "--reload": "" if args.reload else None,
            "--workers": args.workers,
            "--timeout": 0 if args.debug else None,
            "--worker-class": None if args.debug else "gevent",
            "--bind": f"{args.host}:{args.port}",
            "--access-logfile": f"{args.log_dir}/gunicorn-access.log"
            if args.log_dir
            else "-",
            "--error-logfile": f"{args.log_dir}/gunicorn-error.log"
            if args.log_dir
            else "-",
            "'joshinkan.app:build_app()'": "",
        },
    )


def serve_dev() -> None:
    from .scale import shell

    shell("joshinkand", "--debug")


if __name__ == "__main__":
    serve_dev()
