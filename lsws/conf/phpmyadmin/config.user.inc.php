<?php
// phpMyAdmin Security Guard - v1.6
// Reads ./lsws/conf/phpmyadmin/.env for settings

$visible = getenv('PHPMYADMIN_VISIBLE') ?: '0';
$allowed_ip = getenv('PHPMYADMIN_ALLOWED_IP') ?: '';
$auth_user = getenv('PHPMYADMIN_USER') ?: 'admin';
$auth_pass = getenv('PHPMYADMIN_PASSWORD') ?: 'change_me_immediately';

// 1. DISABLED? → 404
if ($visible !== '1') {
    http_response_code(404);
    exit('Not Found');
}

// 2. NO AUTH? → Challenge
if (!isset($_SERVER['PHP_AUTH_USER']) || !isset($_SERVER['PHP_AUTH_PW'])) {
    http_response_code(401);
    header('WWW-Authenticate: Basic realm="phpMyAdmin"');
    exit('Authentication required');
}

// 3. WRONG PASSWORD? → Reject
if ($_SERVER['PHP_AUTH_USER'] !== $auth_user || $_SERVER['PHP_AUTH_PW'] !== $auth_pass) {
    http_response_code(401);
    exit('Unauthorized');
}

// 4. IP WHITELIST? (skip if blank)
if ($allowed_ip && $_SERVER['REMOTE_ADDR'] !== $allowed_ip) {
    http_response_code(403);
    exit('IP not allowed');
}

// ✅ SUCCESS - Load phpMyAdmin
$cfg['Servers'][1]['host'] = 'mariadb';
$cfg['Servers'][1]['auth_type'] = 'cookie';
$cfg['Servers'][1]['compress'] = false;
$cfg['Servers'][1]['AllowNoPassword'] = false;
?>
