@echo off
setlocal EnableDelayedExpansion

REM ============================================================
REM LiteSpeed WebAdmin helper for Windows
REM Location:
REM     /bin/windows/webadmin.bat
REM
REM Docker Compose:
REM     /docker-compose.yml
REM ============================================================

set "CONT_NAME=litespeed"

REM Find directory where this BAT file is located
set "SCRIPT_DIR=%~dp0"

REM Go two directories up:
REM /bin/windows/ -> /bin/ -> project root
cd /d "%SCRIPT_DIR%..\.."

REM Check that docker-compose.yml exists
if not exist "docker-compose.yml" (
    echo.
    echo ERROR: docker-compose.yml was not found.
    echo.
    echo Expected project root:
    echo %CD%
    echo.
    echo Make sure webadmin.bat is located in:
    echo /bin/windows/
    echo.
    pause
    exit /b 1
)

REM ============================================================
REM ARGUMENT CHECK
REM ============================================================

if "%~1"=="" goto HELP

set "ARG=%~1"

REM ============================================================
REM HELP
REM ============================================================

if /I "%ARG%"=="-h" goto HELP
if /I "%ARG%"=="-H" goto HELP
if /I "%ARG%"=="-help" goto HELP
if /I "%ARG%"=="--help" goto HELP

REM ============================================================
REM RESTART
REM ============================================================

if /I "%ARG%"=="-r" goto RESTART
if /I "%ARG%"=="-R" goto RESTART
if /I "%ARG%"=="-restart" goto RESTART
if /I "%ARG%"=="--restart" goto RESTART

REM ============================================================
REM MODSECURE
REM ============================================================

if /I "%ARG%"=="-M" goto MODSECURE
if /I "%ARG%"=="-mode-secure" goto MODSECURE
if /I "%ARG%"=="--mod-secure" goto MODSECURE

REM ============================================================
REM UPGRADE
REM ============================================================

if /I "%ARG%"=="-lsup" goto UPGRADE
if /I "%ARG%"=="--lsup" goto UPGRADE
if /I "%ARG%"=="--upgrade" goto UPGRADE
if /I "%ARG%"=="-U" goto UPGRADE

REM ============================================================
REM SERIAL
REM ============================================================

if /I "%ARG%"=="-s" goto SERIAL
if /I "%ARG%"=="-S" goto SERIAL
if /I "%ARG%"=="-serial" goto SERIAL
if /I "%ARG%"=="--serial" goto SERIAL

REM ============================================================
REM OTHERWISE = WEB ADMIN PASSWORD
REM ============================================================

goto PASSWORD


REM ============================================================
REM HELP
REM ============================================================

:HELP

echo.
echo ============================================================
echo                    LiteSpeed WebAdmin
echo ============================================================
echo.
echo OPTIONS
echo.
echo   [PASSWORD]
echo       Update LiteSpeed WebAdmin password.
echo.
echo       Example:
echo       webadmin.bat MySecurePassword
echo.
echo   -R, --restart
echo       Gracefully restart LiteSpeed Web Server.
echo.
echo   -M, --mod-secure [enable^|disable]
echo       Enable or disable ModSecurity OWASP rules.
echo.
echo       Example:
echo       webadmin.bat -M enable
echo.
echo   -U, --upgrade
echo       Upgrade LiteSpeed Web Server to latest stable version.
echo.
echo   -S, --serial [SERIAL^|TRIAL]
echo       Apply LiteSpeed serial number.
echo.
echo       Example:
echo       webadmin.bat -S TRIAL
echo.
echo   -H, --help
echo       Display this help and exit.
echo.
echo ============================================================
echo.
goto END


REM ============================================================
REM RESTART
REM ============================================================

:RESTART

echo.
echo Restarting LiteSpeed Web Server...
echo.

docker compose exec -T %CONT_NAME% su -c "/usr/local/lsws/bin/lswsctrl restart"

if errorlevel 1 (
    echo.
    echo ERROR: LiteSpeed restart failed.
    goto END
)

echo.
echo LiteSpeed restarted successfully.
goto END


REM ============================================================
REM MODSECURE
REM ============================================================

:MODSECURE

shift

if "%~1"=="" (
    echo.
    echo ERROR: Please specify enable or disable.
    echo.
    goto HELP
)

if /I "%~1"=="enable" goto MOD_ENABLE
if /I "%~1"=="disable" goto MOD_DISABLE

echo.
echo ERROR: Invalid ModSecurity option: %~1
echo.
goto HELP


REM ============================================================
REM ENABLE MODSECURITY
REM ============================================================

:MOD_ENABLE

echo.
echo Enabling ModSecurity OWASP rules...
echo.

docker compose exec %CONT_NAME% su -s /bin/bash root -c "owaspctl.sh --enable"

if errorlevel 1 (
    echo.
    echo ERROR: Failed to enable ModSecurity.
    goto END
)

echo.
echo Restarting LiteSpeed...
echo.

docker compose exec -T %CONT_NAME% su -c "/usr/local/lsws/bin/lswsctrl restart"

echo.
echo ModSecurity enabled.
goto END


REM ============================================================
REM DISABLE MODSECURITY
REM ============================================================

:MOD_DISABLE

echo.
echo Disabling ModSecurity OWASP rules...
echo.

docker compose exec %CONT_NAME% su -s /bin/bash root -c "owaspctl.sh --disable"

if errorlevel 1 (
    echo.
    echo ERROR: Failed to disable ModSecurity.
    goto END
)

echo.
echo Restarting LiteSpeed...
echo.

docker compose exec -T %CONT_NAME% su -c "/usr/local/lsws/bin/lswsctrl restart"

echo.
echo ModSecurity disabled.
goto END


REM ============================================================
REM UPGRADE
REM ============================================================

:UPGRADE

echo.
echo Upgrade web server to latest stable version.
echo.

docker compose exec %CONT_NAME% su -c "/usr/local/lsws/admin/misc/lsup.sh"

if errorlevel 1 (
    echo.
    echo ERROR: LiteSpeed upgrade failed.
    goto END
)

echo.
echo LiteSpeed upgrade completed.
goto END


REM ============================================================
REM SERIAL
REM ============================================================

:SERIAL

shift

if "%~1"=="" (
    echo.
    echo ERROR: Please specify a serial number or TRIAL.
    echo.
    goto HELP
)

echo.
echo Applying LiteSpeed serial...
echo.

docker compose exec %CONT_NAME% su -c "serialctl.sh --serial %~1"

if errorlevel 1 (
    echo.
    echo ERROR: Failed to apply serial.
    goto END
)

echo.
echo Restarting LiteSpeed...
echo.

docker compose exec -T %CONT_NAME% su -c "/usr/local/lsws/bin/lswsctrl restart"

echo.
echo LiteSpeed serial applied successfully.
goto END


REM ============================================================
REM PASSWORD
REM ============================================================

:PASSWORD

echo.
echo Updating LiteSpeed WebAdmin password...
echo.

if "%~1"=="" goto HELP

docker compose exec %CONT_NAME% su -s /bin/bash lsadm -c "if [ -e /usr/local/lsws/admin/fcgi-bin/admin_php ]; then echo admin:$(/usr/local/lsws/admin/fcgi-bin/admin_php -q /usr/local/lsws/admin/misc/htpasswd.php '%~1') > /usr/local/lsws/admin/conf/htpasswd; else echo admin:$(/usr/local/lsws/admin/fcgi-bin/admin_php5 -q /usr/local/lsws/admin/misc/htpasswd.php '%~1') > /usr/local/lsws/admin/conf/htpasswd; fi"

if errorlevel 1 (
    echo.
    echo ERROR: Failed to update WebAdmin password.
    goto END
)

echo.
echo WebAdmin password updated successfully.
goto END


REM ============================================================
REM END
REM ============================================================

:END

echo.
endlocal
exit /b
