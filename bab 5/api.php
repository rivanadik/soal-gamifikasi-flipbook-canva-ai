<?php
// Ubah 4 nilai ini sesuai database di cPanel.
$DB = ['host' => 'localhost', 'name' => 'NAMA_DATABASE', 'user' => 'USER_DATABASE', 'pass' => 'PASSWORD_DATABASE'];

header('Content-Type: application/json; charset=utf-8');
function out($a, $c = 200) { http_response_code($c); echo json_encode($a, JSON_UNESCAPED_UNICODE); exit; }

try {
  $pdo = new PDO("mysql:host={$DB['host']};dbname={$DB['name']};charset=utf8mb4", $DB['user'], $DB['pass'],
    [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC]);
} catch (Exception $e) { out(['ok' => false, 'pesan' => 'Database belum siap. Hubungi gurumu.'], 500); }

$in = json_decode(file_get_contents('php://input'), true) ?: [];
$aksi = $in['aksi'] ?? '';

function bersih($n) { return preg_replace('/ +/', ' ', trim((string)$n)); }
function valid($n) { return strlen($n) >= 3 && strlen($n) <= 40 && preg_match('/^[A-Za-z]+( [A-Za-z]+)*$/', $n); }
function progres($pdo, $id) {
  $s = $pdo->prepare('SELECT aktivitas, skor FROM progres WHERE siswa_id = ?'); $s->execute([$id]);
  $r = []; foreach ($s as $x) $r[$x['aktivitas']] = (int)$x['skor']; return $r;
}

if ($aksi === 'daftar') {
  $n = bersih($in['nama'] ?? '');
  if (!valid($n)) out(['ok' => false, 'pesan' => 'Nama minimal 3 huruf dan hanya boleh huruf.']);
  try {
    $pdo->prepare('INSERT INTO siswa (nama) VALUES (?)')->execute([$n]);
    out(['ok' => true, 'id' => (int)$pdo->lastInsertId(), 'nama' => $n, 'progres' => new stdClass]);
  } catch (PDOException $e) {
    if ($e->getCode() === '23000') out(['ok' => false, 'pesan' => 'Nama itu sudah dipakai. Tambahkan nama belakang atau pakai nama lain. Kalau itu kamu, tekan "Lanjutkan".']);
    out(['ok' => false, 'pesan' => 'Gagal menyimpan nama.'], 500);
  }
}

if ($aksi === 'masuk') {
  $n = bersih($in['nama'] ?? '');
  if (!valid($n)) out(['ok' => false, 'pesan' => 'Nama hanya boleh huruf.']);
  $s = $pdo->prepare('SELECT id, nama FROM siswa WHERE nama = ?'); $s->execute([$n]); $r = $s->fetch();
  if (!$r) out(['ok' => false, 'pesan' => 'Nama belum terdaftar. Tekan "Daftar baru".']);
  $p = progres($pdo, $r['id']);
  out(['ok' => true, 'id' => (int)$r['id'], 'nama' => $r['nama'], 'progres' => $p ?: new stdClass]);
}

if ($aksi === 'simpan') {
  $id = (int)($in['id'] ?? 0); $akt = (string)($in['aktivitas'] ?? ''); $skor = (int)($in['skor'] ?? -1);
  if (!in_array($akt, ['kuis', 's1', 's2', 's3', 's4', 'game'], true) || $skor < 0 || $skor > 100) out(['ok' => false, 'pesan' => 'Data tidak valid.'], 400);
  $c = $pdo->prepare('SELECT 1 FROM siswa WHERE id = ?'); $c->execute([$id]);
  if (!$c->fetch()) out(['ok' => false, 'pesan' => 'Siswa tidak ditemukan.'], 404);
  // Simpan skor terbaik
  $pdo->prepare('INSERT INTO progres (siswa_id, aktivitas, skor) VALUES (?,?,?)
                 ON DUPLICATE KEY UPDATE skor = GREATEST(skor, VALUES(skor))')->execute([$id, $akt, $skor]);
  out(['ok' => true]);
}

out(['ok' => false, 'pesan' => 'Aksi tidak dikenal.'], 400);
