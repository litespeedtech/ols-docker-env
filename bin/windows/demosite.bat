@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================
REM WordPress setup script for Windows
REM Location: /bin/windows/wordpress.bat
REM Project root must contain docker-compose.yml and .env
REM ============================================================

set "APP_NAME=wordpress"
set "CONT_NAME=litespeed"

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

if not exist ".env" (
    echo [X] .env file not found in project root.
    exit /b 1
)

REM ------------------------------------------------------------
REM Read required values from .env
REM ------------------------------------------------------------
for /f "usebackq tokens=1,* delims==" %%A in (".env") do (
    set "ENV_KEY=%%A"
    set "ENV_VALUE=%%B"

    if not "!ENV_KEY!"=="" if not "!ENV_KEY:~0,1!"=="#" (
        if "!ENV_KEY!"=="DOMAIN" set "DOMAIN=!ENV_VALUE!"
        if "!ENV_KEY!"=="MYSQL_DATABASE" set "MYSQL_DATABASE=!ENV_VALUE!"
        if "!ENV_KEY!"=="MYSQL_USER" set "MYSQL_USER=!ENV_VALUE!"
        if "!ENV_KEY!"=="MYSQL_PASSWORD" set "MYSQL_PASSWORD=!ENV_VALUE!"
    )
)

REM Remove surrounding quotes from values if present
if defined DOMAIN (
    set "DOMAIN=!DOMAIN:"=!"
)

if defined MYSQL_DATABASE (
    set "MYSQL_DATABASE=!MYSQL_DATABASE:"=!"
)

if defined MYSQL_USER (
    set "MYSQL_USER=!MYSQL_USER:"=!"
)

if defined MYSQL_PASSWORD (
    set "MYSQL_PASSWORD=!MYSQL_PASSWORD:"=!"
)

REM ============================================================
REM Functions
REM ============================================================

:help_message
if "%~1"=="1" (
    echo.
    echo Script will get DOMAIN and database information from .env
    echo file, then automatically setup the virtual host and
    echo WordPress site for you.
    echo.
    exit /b 0
)

if "%~1"=="2" (
    echo.
    echo Service finished, enjoy your accelerated LiteSpeed server!
    echo.
    exit /b 0
)

:domain_filter
if not defined DOMAIN (
    echo Parameters not supplied, please check!
    exit /b 1
)

REM Remove common URL protocols
set "DOMAIN=!DOMAIN:http://=!"
set "DOMAIN=!DOMAIN:https://=!"
set "DOMAIN=!DOMAIN:ftp://=!"
set "DOMAIN=!DOMAIN:scp://=!"
set "DOMAIN=!DOMAIN:sftp://=!"

REM Remove everything after first /
for /f "tokens=1 delims=/" %%A in ("!DOMAIN!") do set "DOMAIN=%%A"

exit /b 0


:gen_root_fd
set "DOC_FD=.\sites\%~1\"

if exist ".\sites\%~1\" (
    echo [O] The root folder !DOC_FD! exist.
) else (
    echo Creating - document root.

    call "%SCRIPT_DIR%domain.bat" -add "%~1"

    if errorlevel 1 (
        echo [X] Failed to create document root.
        exit /b 1
    )

    echo Finished - document root.
)

exit /b 0


:create_db
if not defined MYSQL_DATABASE (
    echo Parameters not supplied, please check!
    exit /b 1
)

if not defined MYSQL_USER (
    echo Parameters not supplied, please check!
    exit /b 1
)

if not defined MYSQL_PASSWORD (
    echo Parameters not supplied, please check!
    exit /b 1
)

call "%SCRIPT_DIR%database.bat" -D "%~1" -U "%MYSQL_USER%" -P "%MYSQL_PASSWORD%" -DB "%MYSQL_DATABASE%"

if errorlevel 1 (
    echo [X] Database creation failed.
    exit /b 1
)

exit /b 0


:store_credential
if exist "%DOC_FD%.db_pass" (
    echo [O] db file exist!
) else (
    echo Storing database parameter

    (
        echo "Database":"%MYSQL_DATABASE%"
        echo "Username":"%MYSQL_USER%"
        echo "Password":"%MYSQL_PASSWORD:'=%"
    ) > "%DOC_FD%.db_pass"
)

exit /b 0


:app_download
echo Installing %APP_NAME% for %~2...

docker compose exec -T %CONT_NAME% su -c "appinstallctl.sh --app %~1 --domain %~2"

if errorlevel 1 (
    echo [X] WordPress installation failed.
    exit /b 1
)

exit /b 0


:lsws_restart
echo Restarting LiteSpeed...

docker compose exec -T %CONT_NAME% su -c "/usr/local/lsws/bin/lswsctrl restart"

if errorlevel 1 (
    echo [X] Failed to restart LiteSpeed.
    exit /b 1
)

exit /b 0


REM ============================================================
REM Main
REM ============================================================

:main
call :domain_filter
if errorlevel 1 exit /b 1

call :gen_root_fd "%DOMAIN%"
if errorlevel 1 exit /b 1

call :create_db "%DOMAIN%"
if errorlevel 1 exit /b 1

call :store_credential
if errorlevel 1 exit /b 1

call :app_download "%APP_NAME%" "%DOMAIN%"
if errorlevel 1 exit /b 1

call :lsws_restart
if errorlevel 1 exit /b 1

call :help_message 2

exit /b 0


REM ============================================================
REM Argument handling
REM ============================================================

if "%~1"=="" goto main

:arguments
if "%~1"=="" goto main

if /I "%~1"=="-h" goto show_help
if /I "%~1"=="-help" goto show_help
if /I "%~1"=="--help" goto show_help

echo Unknown parameter: %~1
goto show_help

:show_help
call :help_message 1
exit /b 0