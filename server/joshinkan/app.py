from wsgiref.simple_server import make_server


def main():
    import joshinkan.config as config

    from inspect import getmembers, ismodule
    from .logger import setup_logging, get_logger

    setup_logging(config.LOGLEVEL)
    logger = get_logger(__name__)

    from .config import Config

    logger.info(f"Config: {config}")

    from .httpd import make_app
    from .routes import router

    router.set_config(config)
    app = make_app(router)
    with make_server("0.0.0.0", 5000, app) as httpd:
        print("Serving HTTP on port 5000...")

        # Respond to requests until process is killed
        httpd.serve_forever()

        # Alternative: serve one request, then exit
        httpd.handle_request()

    return app
