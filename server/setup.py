# create a setup file for the project without dependencies
import setuptools

setuptools.setup(
    name="joshinkan-backend",
    version="0.0.1",
    packages=setuptools.find_packages(),
    author="Sven Mischkewitz",
    author_email="sven.mkw@gmail.com",
    description="joshinkan.de backend",
    extras_require={"dev": ["pytest==7.4.3", "black==23.11.0", "pdbpp==0.10.3"]},
    entry_points={"console_scripts": ["joshinkand = joshinkan.app:main"]},
)
