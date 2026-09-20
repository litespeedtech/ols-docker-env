@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================
REM ACME / Let's Encrypt management
REM Location: /bin/windows/acme.bat
REM
REM Project root:
REM     docker-compose.yml
REM     .env
REM
REM Script location:
REM     bin/windows/acme.bat
REM ============================================================

set "EMAIL="
set "NO_EMAIL="
set "DOMAIN="
set "INSTALL="
set "UNINSTALL="
set "TYPE=0"
set "CONT_NAME=litespeed"
set "ACME_VERSION=3.1.2"
set "ACME_SRC=https://raw.githubusercontent.com/acmesh-official/acme.sh/3.1.2/acme.sh"
set "RENEW="
set "RENEW_ALL="
set "FORCE="
set "REVOKE="
set "REMOVE="
set "DOC_ROOT="
set "DOC_PATH="
set "ALT_DOC_PATH="
set "WWW_DOMAIN="

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

REM ------------------------------------------------------------
REM Read optional DOC_ROOT from .env
REM ------------------------------------------------------------

if exist ".env" (
    for /f "usebackq tokens=1,* delims==" %%A in (".env") do (
        set "ENV_KEY=%%A"
        set "ENV_VALUE=%%B"

        if "!ENV_KEY!"=="DOC_ROOT" (
            set "DOC_ROOT=!ENV_VALUE!"
        )
    )
)

set "DOC_ROOT=%DOC_ROOT:"=%"

REM ============================================================
REM Help
REM ============================================================

:help_message

if "%~1"=="1" (
    echo.
    echo You will need to install acme script at the first time.
    echo Please run:
    echo.
    echo     acme.bat --install --email example@example.com
    echo.
    exit /b 0
)

if "%~1"=="2" (
    echo.
    echo OPTIONS
    echo.
    echo -D, --domain [DOMAIN_NAME]
    echo     Example: acme.bat --domain example.com
    echo     Will auto detect and apply for both example.com and
    echo     www.example.com domains.
    echo.
    echo -H, --help
    echo     Display help and exit.
    echo.
    echo Only for the First time
    echo.
    echo --install --email [EMAIL_ADDR]
    echo     Will install ACME with the Email provided.
    echo.
    echo -r, --renew
    echo     Renew a specific domain with -D or --domain.
    echo     Use -f / --force to force renew.
    echo.
    echo -R, --renew-all
    echo     Renew all domains if possible.
    echo     Use -f / --force to force renew.
    echo.
    echo -f, -F, --force
    echo     Force renew for a specific domain or all domains.
    echo.
    echo -v, --revoke
    echo     Revoke a domain.
    echo.
    echo -V, --remove
    echo     Remove a domain.
    echo.
    echo -u, --uninstall
    echo     Uninstall ACME.
    echo.
    exit /b 0
)

if "%~1"=="3" (
    echo.
    echo Please run:
    echo.
    echo     acme.bat --domain [DOMAIN_NAME]
    echo.
    echo to apply certificate.
    echo.
    exit /b 0
)

exit /b 0


REM ============================================================
REM Check input
REM ============================================================

:check_input

if "%~1"=="" (
    call :help_message 2
    exit /b 1
)

exit /b 0


REM ============================================================
REM Domain filter
REM ============================================================

:domain_filter

if "%~1"=="" (
    call :help_message 3
    exit /b 1
)

set "DOMAIN=%~1"

REM Remove common protocols
set "DOMAIN=!DOMAIN:http://=!"
set "DOMAIN=!DOMAIN:https://=!"
set "DOMAIN=!DOMAIN:ftp://=!"
set "DOMAIN=!DOMAIN:scp://=!"
set "DOMAIN=!DOMAIN:sftp://=!"

REM Remove path after domain
for /f "tokens=1 delims=/" %%A in ("!DOMAIN!") do (
    set "DOMAIN=%%A"
)

call :validate_domain "!DOMAIN!"

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
REM Validate email
REM ============================================================

:email_filter

set "EMAIL_CLEAN=%~1"

if not defined EMAIL_CLEAN (
    echo [X] The E-mail is invalid.
    exit /b 1
)

REM Maximum RFC 5321 length
if not "%EMAIL_CLEAN:~254,1%"=="" (
    echo [X] The E-mail '%EMAIL_CLEAN%' is invalid.
    exit /b 1
)

REM Prevent argument injection
if "%EMAIL_CLEAN:~0,1%"=="-" (
    echo [X] The E-mail '%EMAIL_CLEAN%' is invalid.
    exit /b 1
)

REM Basic email validation
echo(%EMAIL_CLEAN%| findstr /r /x /c:"[A-Za-z0-9._%%+-][A-Za-z0-9._%%+-]*@[A-Za-z0-9][A-Za-z0-9-]*\.[A-Za-z][A-Za-z]*" >nul

if errorlevel 1 (
    echo [X] The E-mail '%EMAIL_CLEAN%' is invalid.
    exit /b 1
)

echo [O] The E-mail %EMAIL_CLEAN% is valid.

exit /b 0


REM ============================================================
REM Add ACME certificate hook
REM ============================================================

:cert_hook

echo [Start] Adding ACME hook

docker compose exec -T %CONT_NAME% su -s /bin/bash -c "certhookctl.sh"

if errorlevel 1 (
    echo [X] Failed to add ACME hook.
    exit /b 1
)

echo [End] Adding ACME hook

exit /b 0


REM ============================================================
REM Determine www domain
REM ============================================================

:www_domain

set "CHECK_WWW=%~1"

if /I "!CHECK_WWW:~0,4!"=="www." (
    set "DOMAIN=!CHECK_WWW:~4!"
) else (
    set "DOMAIN=!CHECK_WWW!"
)

set "WWW_DOMAIN=www.!DOMAIN!"

exit /b 0


REM ============================================================
REM Verify domain accessibility
REM ============================================================

:domain_verify

echo Checking domain %DOMAIN%...

curl.exe -Is "http://%DOMAIN%/" 2>nul | findstr /I "LiteSpeed" >nul

if errorlevel 1 (
    echo [X] The domain name %DOMAIN% is inaccessible, please verify.
    exit /b 1
)

echo [O] The domain name %DOMAIN% is accessible.

set "TYPE=1"

curl.exe -Is "http://%WWW_DOMAIN%/" 2>nul | findstr /I "LiteSpeed" >nul

if not errorlevel 1 (
    echo [O] The domain name %WWW_DOMAIN% is accessible.
    set "TYPE=2"
) else (
    echo [!] The domain name %WWW_DOMAIN% is inaccessible.
)

exit /b 0


REM ============================================================
REM Install ACME
REM ============================================================

:install_acme

echo [Start] Install ACME

if /I "%~1"=="true" (

    docker compose exec -T %CONT_NAME% su -c "cd && wget %ACME_SRC% && chmod 755 acme.sh && ./acme.sh --install --cert-home ~/.acme.sh/certs && /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt && rm ~/acme.sh"

) else if not "%~2"=="" (

    call :email_filter "%~2"
    if errorlevel 1 exit /b 1

    docker compose exec -T -e ACME_SRC="%ACME_SRC%" -e ACME_EMAIL="%~2" %CONT_NAME% su -c "cd && wget \"\$ACME_SRC\" && chmod 755 acme.sh && ./acme.sh --install --cert-home ~/.acme.sh/certs --accountemail \"\$ACME_EMAIL\" && /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt && rm ~/acme.sh"

) else (

    call :help_message 1
    exit /b 1
)

if errorlevel 1 (
    echo [X] ACME installation failed.
    exit /b 1
)

echo [End] Install ACME

exit /b 0


REM ============================================================
REM Uninstall ACME
REM ============================================================

:uninstall_acme

echo [Start] Uninstall ACME

docker compose exec -T %CONT_NAME% su -c "~/.acme.sh/acme.sh --uninstall"

if errorlevel 1 (
    echo [X] ACME uninstall failed.
    exit /b 1
)

echo [End] Uninstall ACME

exit /b 0


REM ============================================================
REM Check ACME installation
REM ============================================================

:check_acme

echo [Start] Checking ACME

docker compose exec -T %CONT_NAME% su -c "test -f /root/.acme.sh/acme.sh"

if errorlevel 1 (

    call :install_acme "%NO_EMAIL%" "%EMAIL%"
    if errorlevel 1 exit /b 1

    call :cert_hook
    if errorlevel 1 exit /b 1

    call :help_message 3
    exit /b 0
)

echo [End] Checking ACME

exit /b 0


REM ============================================================
REM Restart LiteSpeed
REM ============================================================

:lsws_restart

docker compose exec -T %CONT_NAME% su -c "/usr/local/lsws/bin/lswsctrl restart" >nul

exit /b %ERRORLEVEL%


REM ============================================================
REM Verify document root
REM ============================================================

:doc_root_verify

if not defined DOC_ROOT (

    set "DOC_PATH=/var/www/vhosts/%~1/html"
    set "ALT_DOC_PATH=/var/www/vhosts/www.%~1/html"

) else (

    set "DOC_PATH=%DOC_ROOT%"
    set "ALT_DOC_PATH="
)

docker compose exec -T %CONT_NAME% su -c "[ -e %DOC_PATH% ]"

if not errorlevel 1 (
    echo [O] The document root folder %DOC_PATH% does exist.
    exit /b 0
)

if not defined DOC_ROOT (

    docker compose exec -T %CONT_NAME% su -c "[ -e %ALT_DOC_PATH% ]"

    if not errorlevel 1 (
        set "DOC_PATH=%ALT_DOC_PATH%"

        echo [!] The default document root was not found.
        echo [!] Using fallback %DOC_PATH%.
        echo [O] The document root folder %DOC_PATH% does exist.

        exit /b 0
    )
)

echo [X] The document root folder %DOC_PATH% does not exist!

if not defined DOC_ROOT (
    echo [X] The fallback document root %ALT_DOC_PATH% does not exist!
)

exit /b 1


REM ============================================================
REM Install certificate
REM ============================================================

:install_cert

echo [Start] Apply Lets Encrypt Certificate

if "%TYPE%"=="1" (

    docker compose exec -T %CONT_NAME% su -c "/root/.acme.sh/acme.sh --issue -d %~1 -w %DOC_PATH%"

) else if "%TYPE%"=="2" (

    docker compose exec -T %CONT_NAME% su -c "/root/.acme.sh/acme.sh --issue -d %~1 -d www.%~1 -w %DOC_PATH%"

) else (

    echo unknown Type!
    exit /b 2
)

if errorlevel 1 (
    echo [X] Certificate request failed.
    exit /b 1
)

echo [End] Apply Lets Encrypt Certificate

exit /b 0


REM ============================================================
REM Renew specific domain
REM ============================================================

:renew_acme

echo [Start] Renew ACME

if /I "%FORCE%"=="true" (

    docker compose exec -T %CONT_NAME% su -c "~/.acme.sh/acme.sh --renew --domain %~1 --force"

) else (

    docker compose exec -T %CONT_NAME% su -c "~/.acme.sh/acme.sh --renew --domain %~1"
)

if errorlevel 1 (
    echo [X] ACME renewal failed.
    exit /b 1
)

echo [End] Renew ACME

call :lsws_restart

exit /b 0


REM ============================================================
REM Renew all domains
REM ============================================================

:renew_all_acme

echo [Start] Renew all ACME

if /I "%FORCE%"=="true" (

    docker compose exec -T %CONT_NAME% su -c "~/.acme.sh/acme.sh --renew-all --force"

) else (

    docker compose exec -T %CONT_NAME% su -c "~/.acme.sh/acme.sh --renew-all"
)

if errorlevel 1 (
    echo [X] ACME renewal failed.
    exit /b 1
)

echo [End] Renew all ACME

call :lsws_restart

exit /b 0


REM ============================================================
REM Revoke certificate
REM ============================================================

:revoke

echo [Start] Revoke a domain

docker compose exec -T %CONT_NAME% su -c "~/.acme.sh/acme.sh --revoke --domain %~1"

if errorlevel 1 (
    echo [X] Failed to revoke domain.
    exit /b 1
)

echo [End] Revoke a domain

call :lsws_restart

exit /b 0


REM ============================================================
REM Remove domain from ACME
REM ============================================================

:remove

echo [Start] Remove a domain

docker compose exec -T %CONT_NAME% su -c "~/.acme.sh/acme.sh --remove --domain %~1"

if errorlevel 1 (
    echo [X] Failed to remove domain.
    exit /b 1
)

echo [End] Remove a domain

call :lsws_restart

exit /b 0


REM ============================================================
REM Main
REM ============================================================

:main

if /I "%RENEW_ALL%"=="true" (
    call :renew_all_acme
    exit /b %ERRORLEVEL%
)

if /I "%RENEW%"=="true" (
    call :validate_domain "%DOMAIN%"
    if errorlevel 1 exit /b 1

    call :renew_acme "%DOMAIN%"
    exit /b %ERRORLEVEL%
)

if /I "%REVOKE%"=="true" (
    call :validate_domain "%DOMAIN%"
    if errorlevel 1 exit /b 1

    call :revoke "%DOMAIN%"
    exit /b %ERRORLEVEL%
)

if /I "%REMOVE%"=="true" (
    call :validate_domain "%DOMAIN%"
    if errorlevel 1 exit /b 1

    call :remove "%DOMAIN%"
    exit /b %ERRORLEVEL%
)

call :check_acme
if errorlevel 1 exit /b 1

REM If ACME was just installed, check_acme exits after showing
REM the instruction to run the domain command.
if not exist ".acme-installed-marker" (
    REM No-op. ACME existence is checked inside Docker.
)

call :domain_filter "%DOMAIN%"
if errorlevel 1 exit /b 1

call :www_domain "%DOMAIN%"

call :domain_verify
if errorlevel 1 exit /b 1

call :doc_root_verify "%DOMAIN%"
if errorlevel 1 exit /b 1

call :install_cert "%DOMAIN%"
if errorlevel 1 exit /b 1

call :lsws_restart

exit /b %ERRORLEVEL%


REM ============================================================
REM Argument parsing
REM ============================================================

if "%~1"=="" (
    call :help_message 2
    exit /b 1
)

:arguments

if "%~1"=="" goto main

if /I "%~1"=="-h" goto show_help
if /I "%~1"=="-help" goto show_help
if /I "%~1"=="--help" goto show_help

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

if /I "%~1"=="-i" (
    set "INSTALL=true"
    shift
    goto arguments
)

if /I "%~1"=="--install" (
    set "INSTALL=true"
    shift
    goto arguments
)

if /I "%~1"=="-u" (
    set "UNINSTALL=true"
    call :uninstall_acme
    exit /b %ERRORLEVEL%
)

if /I "%~1"=="--uninstall" (
    set "UNINSTALL=true"
    call :uninstall_acme
    exit /b %ERRORLEVEL%
)

if /I "%~1"=="-f" (
    set "FORCE=true"
    shift
    goto arguments
)

if /I "%~1"=="-F" (
    set "FORCE=true"
    shift
    goto arguments
)

if /I "%~1"=="--force" (
    set "FORCE=true"
    shift
    goto arguments
)

if /I "%~1"=="-r" (
    set "RENEW=true"
    shift
    goto arguments
)

if /I "%~1"=="--renew" (
    set "RENEW=true"
    shift
    goto arguments
)

if /I "%~1"=="-R" (
    set "RENEW_ALL=true"
    shift
    goto arguments
)

if /I "%~1"=="--renew-all" (
    set "RENEW_ALL=true"
    shift
    goto arguments
)

if /I "%~1"=="-v" (
    set "REVOKE=true"
    shift
    goto arguments
)

if /I "%~1"=="--revoke" (
    set "REVOKE=true"
    shift
    goto arguments
)

if /I "%~1"=="-V" (
    set "REMOVE=true"
    shift
    goto arguments
)

if /I "%~1"=="--remove" (
    set "REMOVE=true"
    shift
    goto arguments
)

if /I "%~1"=="-e" (
    shift
    call :check_input "%~1"
    if errorlevel 1 exit /b 1
    set "EMAIL=%~1"
    shift
    goto arguments
)

if /I "%~1"=="--email" (
    shift
    call :check_input "%~1"
    if errorlevel 1 exit /b 1
    set "EMAIL=%~1"
    shift
    goto arguments
)

echo [X] Unknown parameter: %~1
call :help_message 2
exit /b 1


:show_help
call :help_message 2
exit /b 0