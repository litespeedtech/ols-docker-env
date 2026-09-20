@echo off
setlocal EnableExtensions

REM ============================================================
REM OpenLiteSpeed App Installer
REM Location: /bin/windows/appinstall.bat
REM ============================================================

set "APP_NAME="
set "DOMAIN="

REM ------------------------------------------------------------
REM Find project root relative to this script
REM %~dp0 = /bin/windows/
REM ..\.. = project root
REM ------------------------------------------------------------
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%..\.."

if not exist "docker-compose.yml" (
    echo [X] docker-compose.yml not found.
    echo     Expected project root:
    cd
    exit /b 1
)

REM ============================================================
REM Help
REM ============================================================

:help_message
echo.
echo OPTIONS
echo.
echo -A, --app [app_name] -D, --domain [DOMAIN_NAME]
echo     Example: appinstall.bat -A wordpress -D example.com
echo     Will install WordPress CMS under the example.com domain.
echo.
echo -H, --help
echo     Display help and exit.
echo.
exit /b 0


REM ============================================================
REM Check input
REM ============================================================

:check_input
if "%~1"=="" (
    call :help_message
    exit /b 1
)
exit /b 0


REM ============================================================
REM Validate domain
REM ============================================================

:validate_domain

if /I "%~1"=="localhost" (
    exit /b 0
)

echo(%~1| findstr /r /x /c:"[A-Za-z0-9][A-Za-z0-9-]*\.[A-Za-z][A-Za-z]*" >nul

if errorlevel 1 (
    echo [X] Invalid domain name: '%~1'. Abort!
    exit /b 1
)

exit /b 0


REM ============================================================
REM Validate application
REM ============================================================

:validate_app_name

if /I "%~1"=="wordpress" exit /b 0
if /I "%~1"=="wp" exit /b 0

echo [X] Invalid app name: '%~1'. Abort!
exit /b 1


REM ============================================================
REM Install application
REM ============================================================

:app_download

call :validate_app_name "%~1"
if errorlevel 1 exit /b 1

call :validate_domain "%~2"
if errorlevel 1 exit /b 1

echo Installing %~1 for %~2...

docker compose exec -T litespeed su -c "appinstallctl.sh --app %~1 --domain %~2"

if errorlevel 1 (
    echo [X] Application installation failed.
    exit /b 1
)

echo.
echo Restarting LiteSpeed...

docker compose exec -T litespeed su -c "/usr/local/lsws/bin/lswsctrl restart"

if errorlevel 1 (
    echo [X] LiteSpeed restart failed.
    exit /b 1
)

exit /b 0


REM ============================================================
REM Main
REM ============================================================

:main

if not defined APP_NAME (
    echo [X] Application name is required.
    call :help_message
    exit /b 1
)

if not defined DOMAIN (
    echo [X] Domain is required.
    call :help_message
    exit /b 1
)

call :app_download "%APP_NAME%" "%DOMAIN%"

exit /b %ERRORLEVEL%


REM ============================================================
REM Argument parsing
REM ============================================================

if "%~1"=="" (
    call :help_message
    exit /b 1
)

:arguments

if "%~1"=="" goto main

if /I "%~1"=="-h" goto show_help
if /I "%~1"=="-help" goto show_help
if /I "%~1"=="--help" goto show_help

if /I "%~1"=="-a" (
    shift
    call :check_input "%~1"
    if errorlevel 1 exit /b 1
    set "APP_NAME=%~1"
    shift
    goto arguments
)

if /I "%~1"=="-app" (
    shift
    call :check_input "%~1"
    if errorlevel 1 exit /b 1
    set "APP_NAME=%~1"
    shift
    goto arguments
)

if /I "%~1"=="--app" (
    shift
    call :check_input "%~1"
    if errorlevel 1 exit /b 1
    set "APP_NAME=%~1"
    shift
    goto arguments
)

if /I "%~1"=="-d" (
    shift
    call :check_input "%~1"
    if errorlevel 1 exit /b 1
    set "DOMAIN=%~1"
    shift
    goto arguments
)

if /I "%~1"=="-domain" (
    shift
    call :check_input "%~1"
    if errorlevel 1 exit /b 1
    set "DOMAIN=%~1"
    shift
    goto arguments
)

if /I "%~1"=="--domain" (
    shift
    call :check_input "%~1"
    if errorlevel 1 exit /b 1
    set "DOMAIN=%~1"
    shift
    goto arguments
)

echo [X] Unknown parameter: %~1
call :help_message
exit /b 1


:show_help
call :help_message
exit /b 0