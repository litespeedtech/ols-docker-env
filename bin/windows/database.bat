@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================
REM Database management script for Windows
REM Location: /bin/windows/database.bat
REM Project root must contain docker-compose.yml and .env
REM ============================================================

set "CONT_NAME=litespeed"
set "MYSQL_CONTAINER=mysql"

set "DOMAIN="
set "SQL_DB="
set "SQL_USER="
set "SQL_PASS="
set "METHOD=0"
set "SET_OK=0"

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
REM Read MYSQL_ROOT_PASSWORD from .env
REM ------------------------------------------------------------
for /f "usebackq tokens=1,* delims==" %%A in (".env") do (
    set "ENV_KEY=%%A"
    set "ENV_VALUE=%%B"

    if "!ENV_KEY!"=="MYSQL_ROOT_PASSWORD" (
        set "MYSQL_ROOT_PASSWORD=!ENV_VALUE!"
    )
)

set "MYSQL_ROOT_PASSWORD=%MYSQL_ROOT_PASSWORD:"=%"

REM ============================================================
REM Help
REM ============================================================

:help_message
if "%~1"=="1" (
    echo.
    echo OPTIONS
    echo.
    echo -D, --domain [DOMAIN_NAME]
    echo     Example: database.bat -D example.com
    echo     Will auto-generate Database/username/password for the domain.
    echo.
    echo -D, --domain [DOMAIN_NAME] -U, --user [xxx] -P, --password [xxx] -DB, --database [xxx]
    echo     Example: database.bat -D example.com -U USERNAME -P PASSWORD -DB DATABASENAME
    echo     Will create Database/username/password by given values.
    echo.
    echo -R, --delete -DB, --database [xxx] -U, --user [xxx]
    echo     Example: database.bat -r -DB DATABASENAME -U USERNAME
    echo     Will delete the database and username.
    echo.
    echo -H, --help
    echo     Display help and exit.
    echo.
    exit /b 0
)

REM ============================================================
REM Validation
REM ============================================================

:validate_identifier
set "VALIDATE_VALUE=%~1"

if not defined VALIDATE_VALUE (
    echo [X] Identifier cannot be empty.
    exit /b 1
)

echo(%VALIDATE_VALUE%| findstr /r /x /c:"[A-Za-z0-9_][A-Za-z0-9_]*" >nul
if errorlevel 1 (
    echo [X] Invalid identifier '%VALIDATE_VALUE%'. Allowed: [A-Za-z0-9_], max 63 chars.
    exit /b 1
)

if not "%VALIDATE_VALUE:~63,1%"=="" (
    echo [X] Invalid identifier '%VALIDATE_VALUE%'. Maximum 63 characters.
    exit /b 1
)

exit /b 0


:validate_password
set "VALIDATE_PASS=%~1"

if not defined VALIDATE_PASS (
    echo [X] Password cannot be empty.
    exit /b 1
)

if "%VALIDATE_PASS:~7,1%"=="" (
    echo [X] Password too short (minimum 8 characters).
    exit /b 1
)

REM Password characters forbidden by original Bash script:
REM '  "  \  $  `
echo(%VALIDATE_PASS%| findstr /r /c:"['"\^$`\\]" >nul 2>&1
if not errorlevel 1 (
    echo [X] Password contains forbidden characters: ' " \ $ `
    exit /b 1
)

exit /b 0


:validate_domain
set "VALIDATE_DOMAIN=%~1"

if /I "%VALIDATE_DOMAIN%"=="localhost" exit /b 0

echo(%VALIDATE_DOMAIN%| findstr /r /x /c:"[A-Za-z0-9][A-Za-z0-9-]*\.[A-Za-z][A-Za-z]*" >nul
if errorlevel 1 (
    echo [X] Invalid domain name: '%VALIDATE_DOMAIN%'. Abort!
    exit /b 1
)

exit /b 0


REM ============================================================
REM Check required input
REM ============================================================

:check_input
if not defined %~1 (
    call :help_message 1
    exit /b 1
)
exit /b 0


REM ============================================================
REM Generate random password
REM ============================================================

:gen_pass
set "RANDOM_PASS="

REM Generate a random 12-byte Base64 password using PowerShell
for /f "delims=" %%A in ('powershell -NoProfile -Command "[Convert]::ToBase64String((1..12 | ForEach-Object { Get-Random -Minimum 0 -Maximum 256 }))"') do (
    set "RANDOM_PASS=%%A"
)

if not defined RANDOM_PASS (
    echo [X] Failed to generate random password.
    exit /b 1
)

exit /b 0


REM ============================================================
REM Convert domain to database/user name
REM Removes "." and "-"
REM ============================================================

:trans_name
set "TRANSNAME=%~1"
set "TRANSNAME=%TRANSNAME:.=%"
set "TRANSNAME=%TRANSNAME:-=%"
exit /b 0


REM ============================================================
REM Display credentials
REM ============================================================

:display_credential
if "%SET_OK%"=="0" (
    echo.
    echo Database: %SQL_DB%
    echo Username: %SQL_USER%
    echo Password: %SQL_PASS%
    echo.
)
exit /b 0


REM ============================================================
REM Store credentials
REM ============================================================

:store_credential

if not exist ".\sites\%~1\" (
    echo .\sites\%~1 not found, abort credential store!
    exit /b 0
)

if exist ".\sites\%~1\.db_pass" (
    move /Y ".\sites\%~1\.db_pass" ".\sites\%~1\.db_pass.bk" >nul
)

(
    echo "Database":"%SQL_DB%"
    echo "Username":"%SQL_USER%"
    echo "Password":"%SQL_PASS%"
) > ".\sites\%~1\.db_pass"

exit /b 0


REM ============================================================
REM Check MySQL access
REM ============================================================

:check_db_access

docker compose exec -T mysql su -c "mariadb -uroot --password=%MYSQL_ROOT_PASSWORD% -e status" >nul 2>&1

if errorlevel 1 (
    echo [X] DB access failed, please check!
    exit /b 1
)

exit /b 0


REM ============================================================
REM Check whether database exists
REM ============================================================

:check_db_exist

docker compose exec -T mysql su -c "test -e /var/lib/mysql/%~1"

if not errorlevel 1 (
    echo Database %~1 already exist, skip DB creation!
    exit /b 1
)

exit /b 0


REM ============================================================
REM Check whether database does NOT exist
REM ============================================================

:check_db_not_exist

docker compose exec -T mysql su -c "test -e /var/lib/mysql/%~1"

if errorlevel 1 (
    echo Database %~1 doesn't exist, skip DB deletion!
    exit /b 1
)

exit /b 0


REM ============================================================
REM Create database and user
REM ============================================================

:db_setup

echo Creating database and user...

docker compose exec -T mysql su -c "mariadb -uroot --password=%MYSQL_ROOT_PASSWORD% -e \"CREATE DATABASE %SQL_DB%;\" -e \"GRANT ALL PRIVILEGES ON %SQL_DB%.* TO '%SQL_USER%'@'%%' IDENTIFIED BY '%SQL_PASS%';\" -e \"FLUSH PRIVILEGES;\""

set "SET_OK=%ERRORLEVEL%"

exit /b 0


REM ============================================================
REM Delete database and user
REM ============================================================

:db_delete

if not defined SQL_DB (
    echo Database parameter is required!
    exit /b 0
)

call :validate_identifier "%SQL_DB%"
if errorlevel 1 exit /b 1

if not defined SQL_USER (
    set "SQL_USER=%SQL_DB%"
)

call :validate_identifier "%SQL_USER%"
if errorlevel 1 exit /b 1

call :check_db_not_exist "%SQL_DB%"
if errorlevel 1 exit /b 0

echo Deleting database and user...

docker compose exec -T mysql su -c "mariadb -uroot --password=%MYSQL_ROOT_PASSWORD% -e \"DROP DATABASE IF EXISTS %SQL_DB%;\" -e \"DROP USER IF EXISTS '%SQL_USER%'@'%%';\" -e \"FLUSH PRIVILEGES;\""

echo Database %SQL_DB% and User %SQL_USER% are deleted!

exit /b 0


REM ============================================================
REM Auto setup
REM ============================================================

:auto_setup_main

if not defined DOMAIN (
    call :help_message 1
    exit /b 1
)

call :validate_domain "%DOMAIN%"
if errorlevel 1 exit /b 1

call :gen_pass
if errorlevel 1 exit /b 1

call :trans_name "%DOMAIN%"

set "SQL_DB=%TRANSNAME%"
set "SQL_USER=%TRANSNAME%"
set "SQL_PASS=%RANDOM_PASS%"

call :validate_identifier "%SQL_DB%"
if errorlevel 1 exit /b 1

call :validate_identifier "%SQL_USER%"
if errorlevel 1 exit /b 1

call :check_db_exist "%SQL_DB%"
if errorlevel 1 exit /b 0

call :check_db_access
if errorlevel 1 exit /b 1

call :db_setup

call :display_credential

call :store_credential "%DOMAIN%"

exit /b 0


REM ============================================================
REM Specified setup
REM ============================================================

:specify_setup_main

call :validate_identifier "%SQL_USER%"
if errorlevel 1 exit /b 1

call :validate_identifier "%SQL_DB%"
if errorlevel 1 exit /b 1

call :validate_password "%SQL_PASS%"
if errorlevel 1 exit /b 1

call :check_db_exist "%SQL_DB%"
if errorlevel 1 exit /b 0

call :check_db_access
if errorlevel 1 exit /b 1

call :db_setup

call :display_credential

call :store_credential "%DOMAIN%"

exit /b 0


REM ============================================================
REM Main
REM ============================================================

:main

if "%METHOD%"=="1" (
    call :db_delete
    exit /b 0
)

if defined SQL_USER if defined SQL_PASS if defined SQL_DB (
    call :specify_setup_main
) else (
    call :auto_setup_main
)

exit /b %ERRORLEVEL%


REM ============================================================
REM Argument parsing
REM ============================================================

if "%~1"=="" (
    call :help_message 1
    exit /b 1
)

:arguments

if "%~1"=="" goto main

if /I "%~1"=="-h" goto show_help
if /I "%~1"=="-help" goto show_help
if /I "%~1"=="--help" goto show_help

if /I "%~1"=="-d" (
    shift
    set "DOMAIN=%~1"
    shift
    goto arguments
)

if /I "%~1"=="-domain" (
    shift
    set "DOMAIN=%~1"
    shift
    goto arguments
)

if /I "%~1"=="--domain" (
    shift
    set "DOMAIN=%~1"
    shift
    goto arguments
)

if /I "%~1"=="-u" (
    shift
    set "SQL_USER=%~1"
    shift
    goto arguments
)

if /I "%~1"=="-user" (
    shift
    set "SQL_USER=%~1"
    shift
    goto arguments
)

if /I "%~1"=="--user" (
    shift
    set "SQL_USER=%~1"
    shift
    goto arguments
)

if /I "%~1"=="-p" (
    shift
    set "SQL_PASS=%~1"
    shift
    goto arguments
)

if /I "%~1"=="-password" (
    shift
    set "SQL_PASS=%~1"
    shift
    goto arguments
)

if /I "%~1"=="--password" (
    shift
    set "SQL_PASS=%~1"
    shift
    goto arguments
)

if /I "%~1"=="-db" (
    shift
    set "SQL_DB=%~1"
    shift
    goto arguments
)

if /I "%~1"=="-database" (
    shift
    set "SQL_DB=%~1"
    shift
    goto arguments
)

if /I "%~1"=="--database" (
    shift
    set "SQL_DB=%~1"
    shift
    goto arguments
)

if /I "%~1"=="-r" goto delete_mode
if /I "%~1"=="-del" goto delete_mode
if /I "%~1"=="--del" goto delete_mode
if /I "%~1"=="--delete" goto delete_mode

echo [X] Unknown parameter: %~1
call :help_message 1
exit /b 1


:delete_mode
set "METHOD=1"
shift
goto arguments


:show_help
call :help_message 1
exit /b 0