@echo off
setlocal EnableDelayedExpansion

REM ============================================================
REM OpenLiteSpeed Domain Manager for Windows
REM
REM Location:
REM     /bin/windows/domain.bat
REM
REM Project root:
REM     /docker-compose.yml
REM ============================================================

set "CONT_NAME=litespeed"

REM ------------------------------------------------------------
REM Find project root
REM /bin/windows/ -> /bin/ -> project root
REM ------------------------------------------------------------

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%..\.."

REM ------------------------------------------------------------
REM Check docker-compose.yml
REM ------------------------------------------------------------

if not exist "docker-compose.yml" (
    echo.
    echo [X] docker-compose.yml was not found!
    echo.
    echo Expected project root:
    echo %CD%
    echo.
    echo Make sure domain.bat is located in:
    echo /bin/windows/
    echo.
    pause
    exit /b 1
)

REM ============================================================
REM ARGUMENT CHECK
REM ============================================================

if "%~1"=="" goto HELP

REM ============================================================
REM ARGUMENT PARSER
REM ============================================================

:PARSE

if "%~1"=="" goto END

REM ------------------------------------------------------------
REM HELP
REM ------------------------------------------------------------

if /I "%~1"=="-h" goto HELP
if /I "%~1"=="-H" goto HELP
if /I "%~1"=="-help" goto HELP
if /I "%~1"=="--help" goto HELP

REM ------------------------------------------------------------
REM ADD DOMAIN
REM ------------------------------------------------------------

if /I "%~1"=="-a" goto ADD_ARG
if /I "%~1"=="-A" goto ADD_ARG
if /I "%~1"=="-add" goto ADD_ARG
if /I "%~1"=="--add" goto ADD_ARG

REM ------------------------------------------------------------
REM DELETE DOMAIN
REM ------------------------------------------------------------

if /I "%~1"=="-d" goto DEL_ARG
if /I "%~1"=="-D" goto DEL_ARG
if /I "%~1"=="-del" goto DEL_ARG
if /I "%~1"=="--del" goto DEL_ARG
if /I "%~1"=="--delete" goto DEL_ARG

echo.
echo [X] Unknown option: %~1
echo.
goto HELP


REM ============================================================
REM ADD DOMAIN ARGUMENT
REM ============================================================

:ADD_ARG

shift

if "%~1"=="" (
    echo.
    echo [X] Domain name is required!
    echo.
    goto END_ERROR
)

set "DOMAIN=%~1"

call :VALIDATE_DOMAIN "%DOMAIN%"

if errorlevel 1 goto END_ERROR

call :ADD_DOMAIN "%DOMAIN%"

if errorlevel 1 goto END_ERROR

shift
goto PARSE


REM ============================================================
REM DELETE DOMAIN ARGUMENT
REM ============================================================

:DEL_ARG

shift

if "%~1"=="" (
    echo.
    echo [X] Domain name is required!
    echo.
    goto END_ERROR
)

set "DOMAIN=%~1"

call :VALIDATE_DOMAIN "%DOMAIN%"

if errorlevel 1 goto END_ERROR

call :DEL_DOMAIN "%DOMAIN%"

if errorlevel 1 goto END_ERROR

shift
goto PARSE


REM ============================================================
REM HELP
REM ============================================================

:HELP

echo.
echo ============================================================
echo                    OpenLiteSpeed Domains
echo ============================================================
echo.
echo OPTIONS
echo.
echo   -A, --add [DOMAIN_NAME]
echo       Add domain to LiteSpeed Listener and automatically
echo       create a new Virtual Host.
echo.
echo       Example:
echo       domain.bat -A example.com
echo.
echo   -D, --del [DOMAIN_NAME]
echo       Delete domain from LiteSpeed Listener.
echo.
echo       Example:
echo       domain.bat -D example.com
echo.
echo   -H, --help
echo       Display help and exit.
echo.
echo ============================================================
echo.
goto END


REM ============================================================
REM VALIDATE DOMAIN
REM ============================================================

:VALIDATE_DOMAIN

set "TEST_DOMAIN=%~1"

if /I "%TEST_DOMAIN%"=="localhost" (
    exit /b 0
)

echo %TEST_DOMAIN% | findstr /R /C:"^[a-zA-Z0-9][a-zA-Z0-9-]*\.[a-zA-Z][a-zA-Z]*$" >nul

if errorlevel 1 (
    echo.
    echo [X] Invalid domain name: '%TEST_DOMAIN%'
    echo.
    exit /b 1
)

exit /b 0


REM ============================================================
REM ADD DOMAIN
REM ============================================================

:ADD_DOMAIN

set "DOMAIN=%~1"

echo.
echo [Start] Adding domain: %DOMAIN%
echo.

REM ------------------------------------------------------------
REM Add domain inside OpenLiteSpeed container
REM ------------------------------------------------------------

docker compose exec -T %CONT_NAME% su -s /bin/bash lsadm -c "cd /usr/local/lsws/conf && domainctl.sh --add %DOMAIN%"

if errorlevel 1 (
    echo.
    echo [X] Failed to add domain to OpenLiteSpeed.
    echo.
    exit /b 1
)

REM ------------------------------------------------------------
REM Create site directories on Windows host
REM ------------------------------------------------------------

if not exist ".\sites\%DOMAIN%" (
    echo.
    echo [!] Creating site directory structure...
    echo.

    mkdir ".\sites\%DOMAIN%\html"
    mkdir ".\sites\%DOMAIN%\logs"
    mkdir ".\sites\%DOMAIN%\certs"

    echo [O] Created:
    echo     .\sites\%DOMAIN%\html
    echo     .\sites\%DOMAIN%\logs
    echo     .\sites\%DOMAIN%\certs
) else (
    echo.
    echo [i] Site directory already exists:
    echo     .\sites\%DOMAIN%
)

REM ------------------------------------------------------------
REM Restart LiteSpeed
REM ------------------------------------------------------------

echo.
echo [!] Restarting OpenLiteSpeed...
echo.

docker compose exec -T %CONT_NAME% su -c "/usr/local/lsws/bin/lswsctrl restart"

if errorlevel 1 (
    echo.
    echo [X] Failed to restart OpenLiteSpeed.
    echo.
    exit /b 1
)

echo.
echo ============================================================
echo [SUCCESS] Domain added successfully:
echo            %DOMAIN%
echo ============================================================
echo.

exit /b 0


REM ============================================================
REM DELETE DOMAIN
REM ============================================================

:DEL_DOMAIN

set "DOMAIN=%~1"

echo.
echo [Start] Removing domain: %DOMAIN%
echo.

REM ------------------------------------------------------------
REM Remove domain from OpenLiteSpeed
REM ------------------------------------------------------------

docker compose exec -T %CONT_NAME% su -s /bin/bash lsadm -c "cd /usr/local/lsws/conf && domainctl.sh --del %DOMAIN%"

if errorlevel 1 (
    echo.
    echo [X] Failed to remove domain from OpenLiteSpeed.
    echo.
    exit /b 1
)

REM ------------------------------------------------------------
REM Restart LiteSpeed
REM ------------------------------------------------------------

echo.
echo [!] Restarting OpenLiteSpeed...
echo.

docker compose exec -T %CONT_NAME% su -c "/usr/local/lsws/bin/lswsctrl restart"

if errorlevel 1 (
    echo.
    echo [X] Failed to restart OpenLiteSpeed.
    echo.
    exit /b 1
)

echo.
echo ============================================================
echo [SUCCESS] Domain removed successfully:
echo            %DOMAIN%
echo ============================================================
echo.

exit /b 0


REM ============================================================
REM ERROR
REM ============================================================

:END_ERROR

echo.
echo Operation failed.
echo.
endlocal
exit /b 1


REM ============================================================
REM END
REM ============================================================

:END

echo.
endlocal
exit /b 0