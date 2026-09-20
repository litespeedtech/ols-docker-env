@echo off
setlocal EnableDelayedExpansion

REM ============================================================
REM OpenLiteSpeed / mkcert helper for Windows
REM
REM Location:
REM     /bin/windows/mkcert.bat
REM
REM Project root:
REM     /docker-compose.yml
REM ============================================================

set "CONT_NAME=litespeed"
set "CERT_DIR=.\certs"
set "DOMAIN="
set "INSTALL=false"
set "REMOVE=false"

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
    echo Make sure this script is located in:
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

if "%~1"=="" goto MAIN

if /I "%~1"=="-h" goto HELP
if /I "%~1"=="-H" goto HELP
if /I "%~1"=="-help" goto HELP
if /I "%~1"=="--help" goto HELP

if /I "%~1"=="-d" goto DOMAIN_ARG
if /I "%~1"=="-D" goto DOMAIN_ARG
if /I "%~1"=="-domain" goto DOMAIN_ARG
if /I "%~1"=="--domain" goto DOMAIN_ARG

if /I "%~1"=="-i" goto INSTALL_ARG
if /I "%~1"=="-I" goto INSTALL_ARG
if /I "%~1"=="--install" goto INSTALL_ARG

if /I "%~1"=="-r" goto REMOVE_ARG
if /I "%~1"=="-R" goto REMOVE_ARG
if /I "%~1"=="--remove" goto REMOVE_ARG

echo.
echo [X] Unknown option: %~1
echo.
goto HELP


REM ============================================================
REM DOMAIN
REM ============================================================

:DOMAIN_ARG

shift

if "%~1"=="" (
    echo.
    echo [X] Domain name is required!
    echo.
    exit /b 1
)

set "DOMAIN=%~1"

REM Remove protocol
set "DOMAIN=!DOMAIN:http://=!"
set "DOMAIN=!DOMAIN:https://=!"
set "DOMAIN=!DOMAIN:ftp://=!"

REM Remove path
for /f "tokens=1 delims=/" %%A in ("!DOMAIN!") do set "DOMAIN=%%A"

REM Remove trailing slash
if "!DOMAIN:~-1!"=="/" set "DOMAIN=!DOMAIN:~0,-1!"

call :VALIDATE_DOMAIN "!DOMAIN!"

shift
goto PARSE


REM ============================================================
REM INSTALL
REM ============================================================

:INSTALL_ARG

set "INSTALL=true"
shift
goto PARSE


REM ============================================================
REM REMOVE
REM ============================================================

:REMOVE_ARG

set "REMOVE=true"
shift
goto PARSE


REM ============================================================
REM HELP
REM ============================================================

:HELP

echo.
echo ============================================================
echo                         USAGE
echo ============================================================
echo.
echo   mkcert.bat [OPTIONS]
echo.
echo OPTIONS
echo.
echo   -D, --domain [DOMAIN_NAME]
echo       Create certificate for DOMAIN_NAME and www.DOMAIN_NAME
echo.
echo       Example:
echo       mkcert.bat --domain example.test
echo.
echo   -I, --install
echo       Install mkcert on Windows.
echo       Requires Chocolatey.
echo.
echo   -R, --remove
echo       Remove certificate for a specific domain.
echo       Must be used together with --domain.
echo.
echo       Example:
echo       mkcert.bat --remove --domain example.test
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

if /I "!TEST_DOMAIN!"=="localhost" exit /b 0

echo !TEST_DOMAIN! | findstr /R /C:"^[a-zA-Z0-9][a-zA-Z0-9-]*\.[a-zA-Z][a-zA-Z]*$" >nul

if errorlevel 1 (
    echo.
    echo [X] Invalid domain name: '!TEST_DOMAIN!'
    echo.
    exit /b 1
)

exit /b 0


REM ============================================================
REM CHECK MKCERT
REM ============================================================

:CHECK_MKCERT

echo.
echo [Start] Checking mkcert installation...

where mkcert.exe >nul 2>&1

if errorlevel 1 (
    where mkcert >nul 2>&1

    if errorlevel 1 (
        echo.
        echo [X] mkcert not found!
        echo.
        echo Please run:
        echo.
        echo     mkcert.bat --install
        echo.
        echo Or install manually using Chocolatey:
        echo.
        echo     choco install mkcert -y
        echo.
        exit /b 1
    )
)

echo [O] mkcert found.

echo [!] Ensuring local CA is installed...
mkcert -install

if errorlevel 1 (
    echo [X] Failed to install local CA.
    exit /b 1
)

echo [O] Local CA configured.
echo [End] mkcert check completed.

exit /b 0


REM ============================================================
REM INSTALL MKCERT
REM ============================================================

:INSTALL_MKCERT

echo.
echo [Start] Installing mkcert...

where mkcert.exe >nul 2>&1

if not errorlevel 1 (
    echo [O] mkcert is already installed.
    echo [!] Ensuring local CA is installed...
    mkcert -install
    echo [O] Local CA configured.
    echo [End] mkcert installation complete.
    exit /b 0
)

where mkcert >nul 2>&1

if not errorlevel 1 (
    echo [O] mkcert is already installed.
    echo [!] Ensuring local CA is installed...
    mkcert -install
    echo [O] Local CA configured.
    echo [End] mkcert installation complete.
    exit /b 0
)

where choco >nul 2>&1

if errorlevel 1 (
    echo.
    echo [X] Chocolatey not found!
    echo.
    echo Install Chocolatey first:
    echo https://chocolatey.org/install
    echo.
    exit /b 1
)

echo [*] Installing mkcert using Chocolatey...

choco install mkcert -y

if errorlevel 1 (
    echo.
    echo [X] mkcert installation failed!
    echo.
    exit /b 1
)

echo.
echo [O] mkcert installed successfully.
echo [!] Creating local CA...

mkcert -install

if errorlevel 1 (
    echo.
    echo [X] Failed to configure local CA!
    echo.
    exit /b 1
)

echo [O] Local CA configured.
echo [End] mkcert installation complete.

exit /b 0


REM ============================================================
REM CREATE CERTIFICATE DIRECTORY
REM ============================================================

:CREATE_CERT_DIR

if not exist "%CERT_DIR%" (
    echo [!] Creating certificate directory: %CERT_DIR%
    mkdir "%CERT_DIR%"
)

exit /b 0


REM ============================================================
REM GENERATE CERTIFICATE
REM ============================================================

:GENERATE_CERT

echo.
echo [Start] Generating SSL certificate

call :CREATE_WWW_DOMAIN

call :CREATE_CERT_DIR

set "CERT_HOST_PATH=%CERT_DIR%\%DOMAIN%"

if not exist "%CERT_HOST_PATH%" mkdir "%CERT_HOST_PATH%"

echo.
echo [!] Generating certificate for:
echo     %DOMAIN%
echo     %WWW_DOMAIN%
echo.

cd /d "%CERT_HOST_PATH%"

mkcert -key-file key.pem -cert-file cert.pem "%DOMAIN%" "%WWW_DOMAIN%"

if errorlevel 1 (
    echo.
    echo [X] Failed to generate certificate!
    echo.
    cd /d "%SCRIPT_DIR%..\.."
    rmdir /S /Q "%CERT_HOST_PATH%" 2>nul
    exit /b 1
)

echo.
echo [O] Certificate generated successfully.
echo.
echo     Cert: %CERT_HOST_PATH%\cert.pem
echo     Key:  %CERT_HOST_PATH%\key.pem
echo.

cd /d "%SCRIPT_DIR%..\.."

echo [End] Generating SSL certificate

exit /b 0


REM ============================================================
REM CREATE WWW DOMAIN
REM ============================================================

:CREATE_WWW_DOMAIN

set "WWW_DOMAIN="

if /I "!DOMAIN:~0,4!"=="www." (
    set "DOMAIN=!DOMAIN:~4!"
)

set "WWW_DOMAIN=www.!DOMAIN!"

exit /b 0


REM ============================================================
REM VERIFY DOMAIN IN CONTAINER
REM ============================================================

:DOMAIN_VERIFY

set "DOC_PATH=/var/www/vhosts/%DOMAIN%/html"

echo.
echo [!] Checking if domain '%DOMAIN%' has been added...

docker compose exec -T %CONT_NAME% bash -c "[ -d '%DOC_PATH%' ]" >nul 2>&1

if errorlevel 1 (
    echo.
    echo [X] Domain '%DOMAIN%' has NOT been added yet!
    echo [!] Document root not found:
    echo     %DOC_PATH%
    echo.
    echo [!] Please add this domain first.
    echo.
    exit /b 1
)

echo [O] Domain '%DOMAIN%' exists.

exit /b 0


REM ============================================================
REM CREATE LOCAL TEMPLATE
REM ============================================================

:CREATE_LOCAL_TEMPLATE

echo.
echo [Start] Creating docker-local.conf template

docker compose exec -T %CONT_NAME% bash -c "if [ -f /usr/local/lsws/conf/templates/docker-local.conf ]; then echo '[i] Template file already exists'; else cp /usr/local/lsws/conf/templates/docker.conf /usr/local/lsws/conf/templates/docker-local.conf && sed -i '/^  vhssl  {/,/^  }/d; $d' /usr/local/lsws/conf/templates/docker-local.conf && cat >> /usr/local/lsws/conf/templates/docker-local.conf <<'VHSSL_EOF'
  vhssl  {
    keyFile               /usr/local/lsws/conf/cert/\$VH_NAME/key.pem
    certFile              /usr/local/lsws/conf/cert/\$VH_NAME/cert.pem
    certChain             1
  }
}
VHSSL_EOF
chown nobody:nogroup /usr/local/lsws/conf/templates/docker-local.conf 2>/dev/null || chown lsadm:lsadm /usr/local/lsws/conf/templates/docker-local.conf
chmod 644 /usr/local/lsws/conf/templates/docker-local.conf
echo '[O] Template created successfully'; fi"

if errorlevel 1 (
    echo [X] Failed to create docker-local.conf
    exit /b 1
)

echo [End] Creating docker-local.conf template

exit /b 0


REM ============================================================
REM REGISTER LOCAL TEMPLATE
REM ============================================================

:REGISTER_LOCAL_TEMPLATE

echo.
echo [Start] Registering vhTemplate: dockerLocal

docker compose exec -T %CONT_NAME% bash -c "if ! grep -q 'vhTemplate dockerLocal {' /usr/local/lsws/conf/httpd_config.conf; then cat >> /usr/local/lsws/conf/httpd_config.conf <<'EOF'

vhTemplate dockerLocal {
  templateFile            conf/templates/docker-local.conf
  listeners               HTTP, HTTPS
  note                    dockerLocal
}
EOF
echo '[O] Template dockerLocal registered.'; else echo '[i] Template dockerLocal already exists, skipped.'; fi"

if errorlevel 1 (
    echo [X] Failed to register dockerLocal template.
    exit /b 1
)

echo [End] Registering vhTemplate complete.

exit /b 0


REM ============================================================
REM CONFIGURE LITESPEED
REM ============================================================

:CONFIGURE_LITESPEED

echo.
echo [Start] Configuring OpenLiteSpeed for local SSL

set "CERT_HOST_PATH=%CERT_DIR%\%DOMAIN%"

if not exist "%CERT_HOST_PATH%\cert.pem" (
    echo [X] Certificate file not found:
    echo     %CERT_HOST_PATH%\cert.pem
    exit /b 1
)

if not exist "%CERT_HOST_PATH%\key.pem" (
    echo [X] Key file not found:
    echo     %CERT_HOST_PATH%\key.pem
    exit /b 1
)

set "CERT_CONTAINER_PATH=/usr/local/lsws/conf/cert/%DOMAIN%"

echo.
echo [!] Step 1: Creating docker-local template...
call :CREATE_LOCAL_TEMPLATE

if errorlevel 1 exit /b 1

echo.
echo [!] Step 2: Registering dockerLocal template...
call :REGISTER_LOCAL_TEMPLATE

if errorlevel 1 exit /b 1

echo.
echo [!] Step 3: Searching for Virtual Host mapped to '%DOMAIN%'...

for /f "delims=" %%A in ('docker compose exec -T %CONT_NAME% bash -c "grep -B 2 'vhDomain.*%DOMAIN%' /usr/local/lsws/conf/httpd_config.conf | grep 'member' | awk '{print $2}'" 2^>nul') do (
    set "VHOST_NAME=%%A"
)

if not defined VHOST_NAME (
    echo.
    echo [X] No Virtual Host found for domain '%DOMAIN%'.
    echo [!] Please add this domain to your environment first.
    exit /b 1
)

echo [O] Found Virtual Host member name: '%VHOST_NAME%'

echo.
echo [!] Step 4: Checking if domain is already configured for SSL...

docker compose exec -T %CONT_NAME% bash -c "sed -n '/^vhTemplate dockerLocal {/,/^}/p' /usr/local/lsws/conf/httpd_config.conf | grep -q 'member %VHOST_NAME%'"

if not errorlevel 1 (
    echo [O] Domain '%DOMAIN%' is already in dockerLocal template.
    echo [!] Updating certificates and restarting...

    docker compose exec -T %CONT_NAME% bash -c "mkdir -p %CERT_CONTAINER_PATH%"

    docker compose cp "%CERT_HOST_PATH%\cert.pem" "%CONT_NAME%:%CERT_CONTAINER_PATH%/cert.pem"
    docker compose cp "%CERT_HOST_PATH%\key.pem" "%CONT_NAME%:%CERT_CONTAINER_PATH%/key.pem"

    call :LSWS_RESTART

    echo [End] Configuration complete.
    exit /b 0
)

echo.
echo [!] Step 5: Copying certificates to container...

docker compose exec -T %CONT_NAME% bash -c "mkdir -p %CERT_CONTAINER_PATH%"

docker compose cp "%CERT_HOST_PATH%\cert.pem" "%CONT_NAME%:%CERT_CONTAINER_PATH%/cert.pem"
docker compose cp "%CERT_HOST_PATH%\key.pem" "%CONT_NAME%:%CERT_CONTAINER_PATH%/key.pem"

echo [O] Certificates copied to:
echo     %CERT_CONTAINER_PATH%

echo.
echo [!] Step 6: Moving domain from 'docker' template to 'dockerLocal' template...

docker compose exec -T %CONT_NAME% bash -c "cp /usr/local/lsws/conf/httpd_config.conf /usr/local/lsws/conf/httpd_config.conf.backup.$(date +%%Y%%m%%d_%%H%%M%%S) && sed -i '/^vhTemplate docker {/,/^}/ { /member %VHOST_NAME% {/,/}/d }' /usr/local/lsws/conf/httpd_config.conf && sed -i '/^vhTemplate dockerLocal {/,/^}/ { /^}/ i\  member %VHOST_NAME% {\n    vhDomain              %DOMAIN%,www.%DOMAIN%\n  }' /usr/local/lsws/conf/httpd_config.conf"

if errorlevel 1 (
    echo.
    echo [X] Failed to move domain to dockerLocal template.
    exit /b 1
)

echo [O] Domain '%DOMAIN%' moved to dockerLocal template.

echo [!] Restarting OpenLiteSpeed...

call :LSWS_RESTART

echo.
echo [End] Configuring OpenLiteSpeed

exit /b 0


REM ============================================================
REM REMOVE CERTIFICATE
REM ============================================================

:REMOVE_CERT

echo.
echo [Start] Removing SSL certificate

set "CERT_HOST_PATH=%CERT_DIR%\%DOMAIN%"
set "CERT_CONTAINER_PATH=/usr/local/lsws/conf/cert/%DOMAIN%"
set "HTTPD_CONF=/usr/local/lsws/conf/httpd_config.conf"

echo.
echo [!] Step 1: Finding Virtual Host for domain '%DOMAIN%'...

for /f "delims=" %%A in ('docker compose exec -T %CONT_NAME% bash -c "grep -B 2 'vhDomain.*%DOMAIN%' %HTTPD_CONF% | grep 'member' | awk '{print $2}'" 2^>nul') do (
    set "VHOST_NAME=%%A"
)

if not defined VHOST_NAME (
    echo [!] No Virtual Host found for domain '%DOMAIN%'.
    echo [!] Certificate may already have been removed.
) else (
    echo [O] Found Virtual Host member name: '%VHOST_NAME%'

    echo.
    echo [!] Step 2: Removing domain from dockerLocal template...

    docker compose exec -T %CONT_NAME% bash -c "sed -n '/^vhTemplate dockerLocal {/,/^}/p' %HTTPD_CONF% | grep -q 'member %VHOST_NAME%'"

    if not errorlevel 1 (
        echo [O] Domain is configured for SSL.
        echo [!] Moving it back to docker template...

        docker compose exec -T %CONT_NAME% bash -c "cp %HTTPD_CONF% %HTTPD_CONF%.backup.$(date +%%Y%%m%%d_%%H%%M%%S) && sed -i '/^vhTemplate dockerLocal {/,/^}/ { /member %VHOST_NAME% {/,/}/d }' %HTTPD_CONF% && sed -i '/^vhTemplate docker {/,/^}/ { /^}/ i\  member %VHOST_NAME% {\n    vhDomain              %DOMAIN%,www.%DOMAIN%\n  }' %HTTPD_CONF%"

        if errorlevel 1 (
            echo [X] Failed to move domain back to docker template.
        ) else (
            echo [O] Domain '%DOMAIN%' moved back to docker template.
        )
    ) else (
        echo [!] Domain is not in dockerLocal template.
    )
)

echo.
echo [!] Step 3: Removing certificate files from host...

if exist "%CERT_HOST_PATH%" (
    rmdir /S /Q "%CERT_HOST_PATH%"
    echo [O] Removed:
    echo     %CERT_HOST_PATH%
) else (
    echo [!] Certificate directory not found on host.
)

echo.
echo [!] Step 4: Removing certificate files from container...

docker compose exec -T %CONT_NAME% bash -c "if [ -d %CERT_CONTAINER_PATH% ]; then rm -rf %CERT_CONTAINER_PATH%; echo '[O] Removed certificate directory from container'; else echo '[!] Certificate directory not found in container'; fi"

echo.
echo [!] Step 5: Checking if dockerLocal template has any members...

for /f "delims=" %%A in ('docker compose exec -T %CONT_NAME% bash -c "grep -A 20 'vhTemplate dockerLocal' %HTTPD_CONF% | grep -c 'member'" 2^>nul') do (
    set "MEMBER_COUNT=%%A"
)

if "%MEMBER_COUNT%"=="0" (
    echo [!] dockerLocal template has no members, removing template...

    docker compose exec -T %CONT_NAME% bash -c "sed -i '/^vhTemplate dockerLocal {/,/^}/d' %HTTPD_CONF%"

    echo [O] Removed empty dockerLocal template.

    docker compose exec -T %CONT_NAME% bash -c "if [ -f /usr/local/lsws/conf/templates/docker-local.conf ]; then rm /usr/local/lsws/conf/templates/docker-local.conf; echo '[O] Removed docker-local.conf template file'; fi"
) else (
    echo [i] dockerLocal template still has %MEMBER_COUNT% member(s), keeping template.
)

echo.
echo [!] Step 6: Restarting OpenLiteSpeed...

call :LSWS_RESTART

echo.
echo ============================================================
echo [SUCCESS] Certificate removed for domain: %DOMAIN%
echo ============================================================
echo.

echo [End] Removing SSL certificate

exit /b 0


REM ============================================================
REM RESTART LITESPEED
REM ============================================================

:LSWS_RESTART

docker compose exec -T %CONT_NAME% su -c "/usr/local/lsws/bin/lswsctrl restart"

if errorlevel 1 (
    echo [X] Failed to restart OpenLiteSpeed.
) else (
    echo [O] OpenLiteSpeed restarted successfully.
)

exit /b 0


REM ============================================================
REM MAIN
REM ============================================================

:MAIN

if /I "%INSTALL%"=="true" (
    call :INSTALL_MKCERT
    goto END
)

if "%DOMAIN%"=="" (
    echo.
    echo [X] Domain is required!
    echo.
    goto HELP
)

if /I "%REMOVE%"=="true" (
    call :REMOVE_CERT
    goto END
)

call :CHECK_MKCERT
if errorlevel 1 goto END

call :DOMAIN_VERIFY
if errorlevel 1 goto END

call :GENERATE_CERT
if errorlevel 1 goto END

call :CONFIGURE_LITESPEED
if errorlevel 1 goto END

echo.
echo ============================================================
echo [SUCCESS] SSL configuration completed for:
echo            %DOMAIN%
echo            www.%DOMAIN%
echo ============================================================
echo.

goto END


REM ============================================================
REM END
REM ============================================================

:END

echo.
endlocal
exit /b
