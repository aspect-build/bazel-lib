# Copyright 2017 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"Helpers for rules running on windows"

load("@aspect_bazel_lib//lib/private:paths.bzl", "paths")

# cmd.exe function for looking up runfiles.
# Equivalent of the BASH_RLOCATION_FUNCTION in paths.bzl.
# Use this to write actions that don't require bash.
# Originally by @meteorcloudy in
# https://github.com/bazelbuild/rules_nodejs/commit/f06553a
BATCH_RLOCATION_FUNCTION = r"""
rem Usage of rlocation function:
rem        call :rlocation <runfile_path> <abs_path>
rem        The rlocation function maps the given <runfile_path> to its absolute
rem        path and stores the result in a variable named <abs_path>.
rem        This function fails if the <runfile_path> doesn't exist in mainifest
rem        file.
:: Start of rlocation
goto :end
:rlocation
if "%~2" equ "" (
  echo ERROR: Expected two arguments for rlocation function. 1>&2 1>&2
  exit 1
)

:: if set outside this script, these variables may have unix paths. Update to windows.
if not "%RUNFILES_MANIFEST_FILE%"=="" (
    set RUNFILES_MANIFEST_FILE=!RUNFILES_MANIFEST_FILE:/=\!
)
if not "%RUNFILES_DIR%"=="" (
    set RUNFILES_DIR=!RUNFILES_DIR:/=\!
)
if not "%RUNFILES_REPO_MAPPING%"=="" (
    set RUNFILES_REPO_MAPPING=!RUNFILES_REPO_MAPPING:/=\!
)

set GOT_RF=0
if not "%RUNFILES_DIR%"=="" if exist "%RUNFILES_DIR%" (set GOT_RF=1)
if not "%RUNFILES_MANIFEST_FILE%"=="" if exist "%RUNFILES_MANIFEST_FILE%" (set GOT_RF=1)
if "%GOT_RF%"=="0" (
    if exist "%~f0.runfiles_manifest" (
        set "RUNFILES_MANIFEST_FILE=%~f0.runfiles_manifest"
    ) else if exist "%~f0.runfiles\MANIFEST" (
        set "RUNFILES_MANIFEST_FILE=%~f0.runfiles\MANIFEST"
    ) else if exist "%~f0.runfiles" (
        set "RUNFILES_DIR=%~f0.runfiles"
    )
)

if not exist "%RUNFILES_REPO_MAPPING%" (
  set RUNFILES_REPO_MAPPING=%~f0.repo_mapping
)
if "!RUNFILES_LIB_DEBUG!"=="1" (
    echo RUNFILES_LIB_DEBUG=!RUNFILES_LIB_DEBUG! 1>&2
    echo RUNFILES_REPO_MAPPING=%RUNFILES_REPO_MAPPING% 1>&2
    echo RUNFILES_MANIFEST_FILE=%RUNFILES_MANIFEST_FILE% 1>&2
)

:: we always set these; unlike the bash script, this always runs on windows
set _RLOCATION_ISABS_PATTERN="^[a-zA-Z]:[/\\]"
:: Windows paths are case insensitive and Bazel and MSYS2 capitalize differently, so we can't
:: assume that all paths are in the same native case.
set _RLOCATION_GREP_CASE_INSENSITIVE_ARGS=-i

if "!RUNFILES_LIB_DEBUG!"=="1" (
    echo INFO[runfiles.bat]: rlocation(%1^): start 1>&2
)

REM Check if the path is absolute
if "%~f1"=="%1" (
    if "!RUNFILES_LIB_DEBUG!"=="1" (
        echo INFO[runfiles.bat]: rlocation(%1^): absolute path, return 1>&2
    )
    set "convert=%~1"
    set "%~2=!convert:/=\!"
    exit /b 0
)
REM Check if the path is not normalized
if "%1"=="../*" (
    if "!RUNFILES_LIB_DEBUG!"=="1" (
        echo ERROR[runfiles.bat]: rlocation(%1^): path is not normalized 1>&2
    )
    exit /b 1
)
REM Check if the path is absolute without drive name
if "%1:~0,1%"=="\\" (
    if "!RUNFILES_LIB_DEBUG!"=="1" (
        echo ERROR[runfiles.bat]: rlocation(%1^): absolute path without drive name 1>&2
    )
    exit /b 1
)

if exist "%RUNFILES_REPO_MAPPING%" (
    set target_repo_apparent_name=
    for /f "tokens=1 delims=/" %%a in ("%1") do (
        set "target_repo_apparent_name=%%a"
    )
    rem Use -s to get an empty remainder if the argument does not contain a slash.
    rem The repo mapping should not be applied to single segment paths, which may
    rem be root symlinks.    
    set remainder=
    for /f "tokens=2-99 delims=/" %%a in ("%1") do (
        set "remainder=%%a"
    )
    if not "!remainder!"=="" (
        if "%2"=="" (
            call :runfiles_current_repository source_repo 2
        ) else (
            set "source_repo=%2"
        )
        if "!RUNFILES_LIB_DEBUG!"=="1" (
            echo INFO[runfiles.bat]: rlocation(%1^): looking up canonical name for (!target_repo_apparent_name!^) from (!source_repo!^) in (%RUNFILES_REPO_MAPPING%^) 1>&2
        )
        set target_repo=
        for /f "tokens=1-3 delims=," %%a in ('findstr /r /c:"^!source_repo!,!target_repo_apparent_name!," "%RUNFILES_REPO_MAPPING%"') do (
            set "target_repo=%%c"
        )
        if "!RUNFILES_LIB_DEBUG!"=="1" (
            echo INFO[runfiles.bat]: rlocation(%1^): canonical name of target repo is (!target_repo!^) 1>&2
        )
        if not "!target_repo!"=="" (
            set "rlocation_path=!target_repo!/!remainder!"
        ) else (
            set "rlocation_path=%1"
        )
    ) else (
        set "rlocation_path=%1"
    )
) else (
    if "!RUNFILES_LIB_DEBUG!"=="1" (
        echo INFO[runfiles.bat]: rlocation(%1^): not using repository mapping (%RUNFILES_REPO_MAPPING%^) since it does not exist 1>&2
    )
    set "rlocation_path=%1"
)

set "rlocation_checked_out="
call :runfiles_rlocation_checked !rlocation_path! rlocation_checked_out
set "%~2="
if not "%rlocation_checked_out%"=="" (
    set "%~2=%rlocation_checked_out:/=\%"
)
if "!RUNFILES_LIB_DEBUG!"=="1" (
    echo INFO[runfiles.bat]: rlocation(%1^): returning (%~2) 1>&2
)
exit /b 0
:: End of rlocation

:: :runfiles_current_repository <n> <result>
:: Returns the canonical name of the Bazel repository containing the script that
:: calls this function.
:: n: return the canonical name of the N-th caller (pass 1 for standard use cases)
:: result: variable name for the result
::
:: Note: This function only works correctly with Bzlmod enabled. Without Bzlmod,
:: its return value is ignored if passed to rlocation.
:runfiles_current_repository
set "idx=%~1"
if "%idx%"=="" set "idx=1"

set raw_caller_path=
for /f "tokens=%idx%" %%a in ("%~f0") do (
    set "raw_caller_path=%%a"
)

if not exist "!raw_caller_path!" (
    set "caller_path=%~dp0\!raw_caller_path!"
) else (
    set "caller_path=!raw_caller_path!"
)

if "!RUNFILES_LIB_DEBUG!"=="1" (
    echo INFO[runfiles.bat]: runfiles_current_repository(!idx!^): caller's path is (!caller_path!^) 1>&2
)

set "rlocation_path="

if exist "%RUNFILES_MANIFEST_FILE%" (
    REM Escape caller_path for use in the findstr regex below. Also replace \ with / since the manifest
    REM uses / as the path separator even on Windows.
    set "normalized_caller_path=!caller_path:\=/!"
    if "!RUNFILES_LIB_DEBUG!"=="1" (
        echo INFO[runfiles.bat]: runfiles_current_repository(!idx!^): normalized caller's path is (!normalized_caller_path!^) 1>&2
    )
    for /f "tokens=1 delims= " %%a in ('findstr /r /c:"^[^ ]* !normalized_caller_path!$" "%RUNFILES_MANIFEST_FILE%"') do (
        set "rlocation_path=%%a"
    )
    if "%rlocation_path%"=="" (
        if "!RUNFILES_LIB_DEBUG!"=="1" (
            echo ERROR[runfiles.bat]: runfiles_current_repository(!idx!^): (!normalized_caller_path!^) is not the target of an entry in the runfiles manifest (%RUNFILES_MANIFEST_FILE%^) 1>&2
        )
        REM The binary may also be run directly from bazel-bin or bazel-out.
        set repository=
        for /f "tokens=5 delims=/" %%a in ('echo %normalized_caller_path% ^| findstr /r /c:"(^|/)(bazel-out/[^/]+/bin|bazel-bin)/external/[^/]+/"') do ( 1>&2
            set "repository=%%a"
        )
        if not "!repository!"=="" (
            if "!RUNFILES_LIB_DEBUG!"=="1" (
                echo INFO[runfiles.bat]: runfiles_current_repository(!idx!^): (!normalized_caller_path!^) lies in repository (!repository!^) (parsed exec path^) 1>&2
            )
            set "%~2=!repository!"
        ) else (
            if "!RUNFILES_LIB_DEBUG!"=="1" (
                echo INFO[runfiles.bat]: runfiles_current_repository(!idx!^): (!normalized_caller_path!^) lies in the main repository (parsed exec path^) 1>&2
            )
            set %~2=""
        )
        exit /b 1
    ) else (
        if "!RUNFILES_LIB_DEBUG!"=="1" (
            echo INFO[runfiles.bat]: runfiles_current_repository(!idx!^): (!normalized_caller_path!^) is the target of (!rlocation_path!^) in the runfiles manifest 1>&2
        )
    )
)

if "!rlocation_path!"=="" if exist "%RUNFILES_DIR%" (
    set "normalized_caller_path=!caller_path:\=/!"
    set "normalized_dir=!RUNFILES_DIR:/=\!"
    rem if not "!_RLOCATION_GREP_CASE_INSENSITIVE_ARGS!"=="" (
    rem     for /f "tokens=*" %%a in ('echo !normalized_caller_path! ^| tr "[:upper:]" "[:lower:]"') do ( 1>&2
    rem         set "normalized_caller_path=%%a"
    rem     )
    rem     for /f "tokens=*" %%a in ('echo !normalized_dir! ^| tr "[:upper:]" "[:lower:]"') do ( 1>&2
    rem        set "normalized_dir=%%a"
    rem    )
    rem )
    if "!normalized_caller_path:~0,%normalized_dir:~0,-1%!"=="!normalized_dir!" (
        set "rlocation_path=!normalized_caller_path:~%normalized_dir:~0,-1%!"
        set "rlocation_path=!rlocation_path:~1!"
    )
    if "!rlocation_path!"=="" (
        if "!RUNFILES_LIB_DEBUG!"=="1" (
            echo ERROR[runfiles.bat]: runfiles_current_repository(!idx!^): (!normalized_caller_path!^) does not lie under the runfiles directory (!normalized_dir!^) 1>&2
        )
        REM The only shell script that is not executed from the runfiles directory (if it is populated)
        REM is the sh_binary entrypoint. Parse its path under the execroot, using the last match to
        REM allow for nested execroots (e.g. in Bazel integration tests). The binary may also be run
        REM directly from bazel-bin.
        rem for /f "tokens=5 delims=/" %%a in ('echo !normalized_caller_path! ^| findstr /r /c:"(^|/)(bazel-out/[^/]+/bin|bazel-bin)/external/[^/]+/"') do ( 1>&2
        rem     set "repository=%%a"
        rem )
        if not "!repository!"=="" (
            if "!RUNFILES_LIB_DEBUG!"=="1" (
                echo ERROR[runfiles.bat]: runfiles_current_repository(!idx!^): (!normalized_caller_path!^) lies in repository (!repository!^) (parsed exec path^) 1>&2
            )
            set "%~2=!repository!"
        ) else (
            if "!RUNFILES_LIB_DEBUG!"=="1" (
                echo ERROR[runfiles.bat]: runfiles_current_repository(!idx!^): (!normalized_caller_path!^) lies in the main repository (parsed exec path^) 1>&2
            )
            set %~2=""
        )
        exit /b 0
    ) else (
        if "!RUNFILES_LIB_DEBUG!"=="1" (
            echo ERROR[runfiles.bat]: runfiles_current_repository(!idx!^): (!caller_path!^) has path (!rlocation_path^) relative to the runfiles directory (%RUNFILES_DIR%:-^) 1>&2
        )
    )
)

if "!rlocation_path!"=="" (
    if "!RUNFILES_LIB_DEBUG!"=="1" (
        echo ERROR[runfiles.bat]: runfiles_current_repository(!idx!^): cannot determine repository for (!caller_path!^) since neither the runfiles directory (%RUNFILES_DIR%:-^) nor the runfiles manifest (%RUNFILES_MANIFEST_FILE%:-^) exist 1>&2
    )
    exit /b 1
)

if "!RUNFILES_LIB_DEBUG!"=="1" (
    echo INFO[runfiles.bat]: runfiles_current_repository(!idx!^): (!caller_path!^) corresponds to rlocation path (!rlocation_path!^) 1>&2
)

REM Normalize the rlocation_path to be of the form repo/pkg/file.
set "rlocation_path=!rlocation_path:_main/external/=!"
set "rlocation_path=!rlocation_path:_main/../=!"

set repository=
for /f "tokens=1 delims=/" %%a in ("!rlocation_path!") do (
    set "repository=%%a"
)

if "!repository!"=="_main" (
    if "!RUNFILES_LIB_DEBUG!"=="1" (
        echo INFO[runfiles.bat]: runfiles_current_repository(!idx!^): (!rlocation_path!^) lies in the main repository 1>&2
    )
    set %~2=""
) else (
    if "!RUNFILES_LIB_DEBUG!"=="1" (
        echo INFO[runfiles.bat]: runfiles_current_repository(!idx!^): (!rlocation_path!^) lies in repository (!repository!^) 1>&2
    )
    set %~2=!repository!
)

endlocal
exit /b
:: end of runfiles_current_repository

:parent_directory
set "input=%~1"
:: make it look like absolute windows path, to allow pnx to remove child directory
for %%a in ("\%input:/=\%") do for %%b in ("%%~dpa\.") do set "parent=%%~pnxb"
:: remove first character
set parent=%parent:~1%
:: convert back to unix path
set "parent=%parent:\=/%"
set "%~2=%parent%"
exit /b 0

:runfiles_rlocation_checked
set input=%~1
:: there may be both a manifest file and runfiles dir. Look in the manifest first, then runfiles.
if exist "%RUNFILES_MANIFEST_FILE%" (
    if "!RUNFILES_LIB_DEBUG!"=="1" (
        echo INFO[runfiles.bat]: rlocation(%~1^): looking in RUNFILES_MANIFEST_FILE (!RUNFILES_MANIFEST_FILE!^) 1>&2
    )
    set result=
    for /f "tokens=2 delims= " %%a in ('findstr /b /c:"%~1 " "%RUNFILES_MANIFEST_FILE%"') do (
        set "result=%%a"
    )
    if "!result!"=="" (
        REM If path references a runfile that lies under a directory that itself
        REM is a runfile, then only the directory is listed in the manifest. Look
        REM up all prefixes of path in the manifest and append the relative path
        REM from the prefix if there is a match.
        set "prefix=%~1"
        set "prefix_result="
        set "new_prefix="
        :while
        set new_prefix=
        call :parent_directory !prefix! new_prefix
        if "!new_prefix!"=="!prefix!" (
            goto :end_while
        )
        set "prefix=!new_prefix!"
        for /f "tokens=2 delims= " %%a in ('findstr /b /c:"!prefix! " %RUNFILES_MANIFEST_FILE%') do (
            set "prefix_result=%%a"
        )
        if "!prefix_result!"=="" (
            echo INFO[runfiles.bat]: rlocation(%~1^): did not find (!prefix!^) looping on parent directory 1>&2
            goto :while
        )
        call set "suffix=%%input:!prefix!=%%"
        if  "!suffix!"=="!prefix!" (
            if "!RUNFILES_LIB_DEBUG!"=="1" (
                echo ERROR[runfiles.bat]: rlocation(%~1^): could not find suffix from (!prefix!^) 1>&2
            )
            goto :end_while
        )
        set "candidate=!prefix_result!!suffix!"
        set "candidate=!candidate:/=\!"
        if exist "!candidate!" (
            if "!RUNFILES_LIB_DEBUG!"=="1" (
                echo INFO[runfiles.bat]: rlocation(%~1^): found in manifest as (!candidate!^) via prefix (!prefix!^) 1>&2
            )
            set %~2=!candidate!
            exit /b 0
        )
        REM At this point, the manifest lookup of prefix has been successful,
        REM but the file at the relative path given by the suffix does not
        REM exist. We do not continue the lookup with a shorter prefix for two
        REM reasons:
        REM 1. Manifests generated by Bazel never contain a path that is a
        REM    prefix of another path.
        REM 2. Runfiles libraries for other languages do not check for file
        REM    existence and would have returned the non-existent path. It seems
        REM    better to return no path rather than a potentially different,
        REM    non-empty path.
        if "!RUNFILES_LIB_DEBUG!"=="1" (
            echo INFO[runfiles.bat]: rlocation(%~1^): found in manifest as (!candidate!^) via prefix (!prefix!^), but file does not exist 1>&2
        )
        goto :end_while
        :end_while
        if "!RUNFILES_LIB_DEBUG!"=="1" (
            echo INFO[runfiles.bat]: rlocation(%~1^): not found in manifest 1>&2
        )
        set %~2=""
        exit /b 0
    ) else (
        if exist "!result!" (
            if "!RUNFILES_LIB_DEBUG!"=="1" (
                echo INFO[runfiles.bat]: rlocation(%~1^): found in manifest as (!result!^) 1>&2
            )
            set "%~2=!result!"
            exit /b 0
        ) else (
            if "!RUNFILES_LIB_DEBUG!"=="1" (
                echo INFO[runfiles.bat]: rlocation(%~1^): found in manifest as (!result!^), but file does not exist 1>&2
            )
            set %~2=""
            exit /b 0
        )
    )
)
if exist "!RUNFILES_DIR!\%~1" (
    if "!RUNFILES_LIB_DEBUG!"=="1" (
        echo INFO[runfiles.bat]: rlocation(%~1^): found under RUNFILES_DIR (!RUNFILES_DIR!^), return 1>&2
    )
    set "%~2=!RUNFILES_DIR!\%~1"
    exit /b 0
)
if "!RUNFILES_LIB_DEBUG!"=="1" (
    echo ERROR[runfiles.bat]: cannot look up runfile "%~1" (RUNFILES_DIR="!RUNFILES_DIR!", RUNFILES_MANIFEST_FILE="!RUNFILES_MANIFEST_FILE!"^) 1>&2
)
exit /b 1
::end of runfiles_rlocation_checked

:end
:: leave these variables set with forward slashes, for compatibility with any 
:: bash runfile calls made downstream
if not "%RUNFILES_MANIFEST_FILE%"=="" (
    set RUNFILES_MANIFEST_FILE=%RUNFILES_MANIFEST_FILE:\=/%
)
if not "%RUNFILES_DIR%"=="" (
    set RUNFILES_DIR=%RUNFILES_DIR:\=/%
)
if not "%RUNFILES_REPO_MAPPING%"=="" (
    set RUNFILES_REPO_MAPPING=%RUNFILES_REPO_MAPPING:\=/%
)
"""

def create_windows_native_launcher_script(ctx, shell_script):
    """Create a Windows Batch file to launch the given shell script.

    The rule should specify @bazel_tools//tools/sh:toolchain_type as a required toolchain.

    Args:
        ctx: Rule context
        shell_script: The bash launcher script

    Returns:
        A windows launcher script
    """
    name = shell_script.basename
    if name.endswith(".sh"):
        name = name[:-3]
    win_launcher = ctx.actions.declare_file(name + ".bat", sibling = shell_script)
    ctx.actions.write(
        output = win_launcher,
        content = r"""@echo off 1>&2
SETLOCAL ENABLEEXTENSIONS
SETLOCAL ENABLEDELAYEDEXPANSION
set RUNFILES_MANIFEST_ONLY=1
::set RUNFILES_LIB_DEBUG=1
{rlocation_function}
call :rlocation "{sh_script}" run_script
:: convert output path to unix style
set "run_script=!run_script:\=/!"
for %%a in ("{bash_bin}") do set "bash_bin_dir=%%~dpa"
set PATH=%bash_bin_dir%;%PATH%
set args=%*
rem Escape \ and * in args before passsing it with double quote
if defined args (
  set args=!args:\=\\\\!
  set args=!args:"=\"!
)
"{bash_bin}" -c "!run_script! !args!"
""".format(
            bash_bin = ctx.toolchains["@bazel_tools//tools/sh:toolchain_type"].path,
            sh_script = paths.to_rlocation_path(ctx, shell_script),
            rlocation_function = BATCH_RLOCATION_FUNCTION,
        ),
        is_executable = True,
    )
    return win_launcher

# TODO:
# decide: should rlocation return backslash or forward slash paths?
# - users intending to call bash -c would prefer forward slashes
# - users writing native bat would prefer backslashes
# look at commented out lines, are they needed?
