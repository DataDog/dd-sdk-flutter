ARG BASE_IMAGE=mcr.microsoft.com/dotnet/framework/runtime:4.8-windowsservercore-ltsc2022
FROM ${BASE_IMAGE}

ENV WINDOWS_VERSION=2022
ENV TARGET_ARCH=x64

# Copy PowerShell scripts from build context into the image
COPY . C:/TEMP/scripts
WORKDIR C:/TEMP/scripts

SHELL ["powershell", "-Command"]
RUN .\build-toolchain-image.ps1

WORKDIR C:/
