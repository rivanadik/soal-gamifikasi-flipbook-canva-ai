<?php
// api.php - penghubung e-modul dengan database MySQL (cPanel)
// Ubah 4 nilai di $cfg sesuai database cPanel kamu.
$cfg = ['host' => 'localhost', 'db' => 'NAMA_DATABASE', 'user' => 'USER_DATABASE', 'pass' => 'PASSWORD_DATABASE'];
// Ganti '*' dengan alamat situs e-modulmu agar hanya situs itu yang boleh memanggil API ini.
$allowOrigin = '*';

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: ' . $allowOrigin);
header('Access-Control-Allow-Headers: Content-Type');
header('Access-Control-Allow-Methods: POST, OPTIONS');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { exit; }

function out(array $a, int $code = 200): void {
    http_response_code($code);
    echo json_encode($a, JSON_UNESCAPED_UNICODE);
    exit;
}
if ($_SERVER['REQUEST_METHOD'] !== 'POST') out(['ok' => false, 'message' => 'Metode tidak diizinkan.'], 405);

try {
    $pdo = new PDO("mysql:host={$cfg['host']};dbname={$cfg['db']};charset=utf8mb4", $cfg['user'], $cfg['pass'], [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
} catch (Throwable $e) {
    out(['ok' => false, 'message' => 'Database belum siap. Hubungi guru.'], 500);
}

$in     = json_decode(file_get_contents('php://input'), true) ?: [];
$action = (string)($in['action'] ?? '');
$token  = substr((string)($in['token'] ?? ''), 0, 64);
if (strlen($token) < 16) out(['ok' => false, 'message' => 'Penanda perangkat tidak valid.'], 400);
$tokenHash = hash('sha256', $token);

// Aturan nama: hanya huruf (semua bahasa) dan spasi tunggal, 3-40 karakter.
$name = preg_replace('/\s+/u', ' ', trim((string)($in['name'] ?? '')));
if (!preg_match('/^\p{L}+(?: \p{L}+)*$/u', $name) || mb_strlen($name, 'UTF-8') < 3 || mb_strlen($name, 'UTF-8') > 40) {
    out(['ok' => false, 'message' => 'Nama hanya boleh huruf dan spasi (3-40 karakter).'], 422);
}
$nameKey = mb_strtolower($name, 'UTF-8');

function bestScores(PDO $pdo, int $sid, int $bab): array {
    $q = $pdo->prepare('SELECT mode, MAX(score) AS s FROM attempts WHERE student_id=? AND bab=? GROUP BY mode');
    $q->execute([$sid, $bab]);
    $b = [];
    foreach ($q as $r) { $b[$r['mode']] = (int)$r['s']; }
    return $b;
}

$bab = max(1, min(5, (int)($in['bab'] ?? 1)));

if ($action === 'register') {
    $q = $pdo->prepare('SELECT id, token_hash FROM students WHERE name_key=?');
    $q->execute([$nameKey]);
    $row = $q->fetch();
    if ($row) {
        // Nama sudah ada: hanya perangkat yang sama yang boleh melanjutkan.
        if (hash_equals($row['token_hash'], $tokenHash)) {
            out(['ok' => true, 'best' => bestScores($pdo, (int)$row['id'], $bab)]);
        }
        out(['ok' => false, 'message' => 'Nama ini sudah dipakai. Tambahkan nama belakangmu.'], 409);
    }
    try {
        $pdo->prepare('INSERT INTO students (name, name_key, token_hash) VALUES (?,?,?)')->execute([$name, $nameKey, $tokenHash]);
    } catch (PDOException $e) {
        if ($e->getCode() === '23000') out(['ok' => false, 'message' => 'Nama ini sudah dipakai. Tambahkan nama belakangmu.'], 409);
        out(['ok' => false, 'message' => 'Gagal menyimpan nama.'], 500);
    }
    out(['ok' => true, 'best' => new stdClass()]);
}

if ($action === 'save') {
    $q = $pdo->prepare('SELECT id, token_hash FROM students WHERE name_key=?');
    $q->execute([$nameKey]);
    $row = $q->fetch();
    if (!$row || !hash_equals($row['token_hash'], $tokenHash)) out(['ok' => false, 'message' => 'Siswa tidak dikenali.'], 403);

    $mode  = (string)($in['mode'] ?? '');
    $score = (int)($in['score'] ?? -1);
    if (!in_array($mode, ['quiz', 'game'], true) || $score < 0 || $score > 100) out(['ok' => false, 'message' => 'Data nilai tidak valid.'], 422);
    $badge = $score < 60 ? 'Perunggu' : ($score < 85 ? 'Perak' : 'Emas'); // dihitung ulang di server
    $review = is_array($in['review'] ?? null) ? array_slice(array_map(fn($t) => mb_substr((string)$t, 0, 80), $in['review']), 0, 20) : [];

    $pdo->prepare('INSERT INTO attempts (student_id, bab, mode, score, badge, review) VALUES (?,?,?,?,?,?)')
        ->execute([$row['id'], $bab, $mode, $score, $badge, json_encode($review, JSON_UNESCAPED_UNICODE)]);
    out(['ok' => true, 'best' => bestScores($pdo, (int)$row['id'], $bab)]);
}

out(['ok' => false, 'message' => 'Aksi tidak dikenal.'], 400);
