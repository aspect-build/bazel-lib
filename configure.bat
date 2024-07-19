:: run this on Windows to set up example for use
@echo Configuring workspace for Windows
:: aspect-cli doesn't support windows, so disable it
del %~dp0.bazeliskrc
