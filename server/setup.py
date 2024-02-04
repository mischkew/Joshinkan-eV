# create a setup file for the project without dependencies
import setuptools

setuptools.setup(
    name="joshinkan-backend",
    version="0.0.1",
    packages=setuptools.find_packages(),
    author="Sven Mischkewitz",
    author_email="sven.mkw@gmail.com",
    description="joshinkan.de backend",
    install_requires=["gunicorn[gevent]==20.1.0"],
    extras_require={"dev": ["pytest==7.4.3", "black==23.11.0", "pdbpp==0.10.3"]},
    entry_points={
        "console_scripts": [
            "joshinkand = joshinkan.app:serve_gunicorn",
            "joshinkand-dev = joshinkan.app:serve_dev",
        ]
    },
)
