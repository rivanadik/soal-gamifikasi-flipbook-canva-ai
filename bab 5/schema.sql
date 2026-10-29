-- Database progres siswa (MySQL 5.7+/MariaDB). Jalankan di phpMyAdmin pada database kosong.
-- Tabel siswa dipakai bersama semua bab, jadi satu nama cukup didaftarkan sekali.

CREATE TABLE IF NOT EXISTS siswa (
  id      INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  nama    VARCHAR(40) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  dibuat  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  -- Nama tidak boleh sama (tanpa membedakan huruf besar/kecil: "Rani" = "rani")
  UNIQUE KEY uq_siswa_nama (nama),
  -- Hanya huruf A-Z dan spasi tunggal antarkata. Angka/simbol ditolak.
  -- (CHECK aktif di MySQL 8.0.16+ dan MariaDB 10.2+; di versi lama diabaikan,
  --  tetapi api.php tetap memvalidasi. Hapus baris CHECK jika muncul galat.)
  CONSTRAINT chk_siswa_nama CHECK (nama REGEXP '^[A-Za-z]+( [A-Za-z]+)*$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS progres (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  siswa_id    INT UNSIGNED NOT NULL,
  -- contoh: kuis, s1, s2, s3, s4, game (Bab 5). Bab lain boleh memakai awalan sendiri, mis. b4_kuis.
  aktivitas   VARCHAR(20) NOT NULL,
  skor        TINYINT UNSIGNED NOT NULL DEFAULT 0,
  diperbarui  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_siswa_aktivitas (siswa_id, aktivitas),
  CONSTRAINT fk_progres_siswa FOREIGN KEY (siswa_id) REFERENCES siswa(id) ON DELETE CASCADE,
  CONSTRAINT chk_progres_skor CHECK (skor <= 100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Rekap untuk guru (Bab 5)
CREATE OR REPLACE VIEW rekap_bab5 AS
SELECT s.nama,
       MAX(CASE WHEN p.aktivitas='kuis' THEN p.skor END) AS kuis,
       MAX(CASE WHEN p.aktivitas='s1'   THEN p.skor END) AS stasiun1,
       MAX(CASE WHEN p.aktivitas='s2'   THEN p.skor END) AS stasiun2,
       MAX(CASE WHEN p.aktivitas='s3'   THEN p.skor END) AS stasiun3,
       MAX(CASE WHEN p.aktivitas='s4'   THEN p.skor END) AS stasiun4,
       MAX(CASE WHEN p.aktivitas='game' THEN p.skor END) AS game_total
FROM siswa s LEFT JOIN progres p ON p.siswa_id = s.id
GROUP BY s.id, s.nama
ORDER BY s.nama;

-- Cara pakai: SELECT * FROM rekap_bab5;
