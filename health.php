<?php
// health.php - Liveness & Readiness probe for Docker / CI/CD
header('Content-Type: application/json');

$dbHost = getenv('DB_HOST') ?: 'db';
$dbName = getenv('DB_DATABASE') ?: 'flipbook';
$dbUser = getenv('DB_USERNAME') ?: 'flipbook';
$dbPass = getenv('DB_PASSWORD') ?: 'flipbook_secret';

$dbStatus = 'disconnected';
$error = null;

try {
    $pdo = new PDO("mysql:host={$dbHost};dbname={$dbName};charset=utf8mb4", $dbUser, $dbPass, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_TIMEOUT => 3,
    ]);
    $stmt = $pdo->query('SELECT 1');
    if ($stmt) {
        $dbStatus = 'connected';
    }
} catch (Throwable $e) {
    $error = $e->getMessage();
}

$isOk = ($dbStatus === 'connected');
http_response_code($isOk ? 200 : 503);

echo json_encode([
    'status'    => $isOk ? 'ok' : 'degraded',
    'app'       => 'flipbook-canva-ai',
    'database'  => $dbStatus,
    'timestamp' => date(DATE_ATOM),
    'error'     => $error,
]);

