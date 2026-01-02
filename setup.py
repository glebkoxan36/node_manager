from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

with open("requirements.txt", "r", encoding="utf-8") as fh:
    requirements = [line.strip() for line in fh if line.strip() and not line.startswith("#")]

setup(
    name="blockchain-module",
    version="2.0.0",
    author="Blockchain Module Team",
    description="Универсальный модуль для работы с криптовалютами через Nownodes API с мультипользовательской системой",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/yourusername/blockchain-module",
    packages=find_packages(),
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "Topic :: Software Development :: Libraries :: Python Modules",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.7",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Operating System :: OS Independent",
    ],
    python_requires=">=3.7",
    install_requires=requirements,
    entry_points={
        "console_scripts": [
            "blockchain-module=blockchain_module.cli:cli",
            "blockchain-cli=blockchain_module.cli:cli",
        ],
    },
    include_package_data=True,
    package_data={
        "blockchain_module": ["configs/*.json"],
    },
)