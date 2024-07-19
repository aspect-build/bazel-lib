@set dir=%~dp0
@set dir=%dir:\=/%
@echo %BAZEL_SH% -c "%dir%test.sh %*"
@%BAZEL_SH% -c "%dir%test.sh %*"
