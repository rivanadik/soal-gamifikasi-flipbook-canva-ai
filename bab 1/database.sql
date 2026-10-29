-- E-modul Canva AI (DKV) - database progres siswa
-- Jalankan di phpMyAdmin (cPanel) pada database yang sudah dibuat.

SET NAMES utf8mb4;

-- 1) Daftar siswa. name_key bersifat UNIK (tanpa membedakan huruf besar/kecil),
--    jadi nama yang sama tidak bisa didaftarkan dua kali.
CREATE TABLE IF NOT EXISTS students (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  name        VARCHAR(60)  NOT NULL,                          -- nama tampilan
  name_key    VARCHAR(60)  NOT NULL,                          -- nama huruf kecil, spasi dirapikan
  token_hash  CHAR(64)     NOT NULL,                          -- penanda perangkat (SHA-256)
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_students_name_key (name_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2) Setiap kali siswa selesai kuis/game, satu baris tersimpan.
CREATE TABLE IF NOT EXISTS attempts (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  student_id  INT UNSIGNED NOT NULL,
  bab         TINYINT UNSIGNED NOT NULL DEFAULT 1,
  mode        ENUM('quiz','game') NOT NULL,
  score       TINYINT UNSIGNED NOT NULL,                      -- 0-100
  badge       ENUM('Perunggu','Perak','Emas') NOT NULL,
  review      TEXT NULL,                                      -- materi yang perlu diulang (JSON)
  created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_attempts_student (student_id, bab, mode),
  CONSTRAINT fk_attempts_student FOREIGN KEY (student_id)
    REFERENCES students(id) ON DELETE CASCADE,
  CONSTRAINT ck_attempts_score CHECK (score <= 100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3) Rekap untuk guru: nilai terbaik tiap siswa per bab.
CREATE OR REPLACE VIEW v_rekap AS
SELECT s.name,
       a.bab,
       MAX(CASE WHEN a.mode='quiz' THEN a.score END) AS terbaik_kuis,
       MAX(CASE WHEN a.mode='game' THEN a.score END) AS terbaik_game,
       COUNT(*)                                       AS jumlah_percobaan,
       MAX(a.created_at)                              AS terakhir
FROM students s
JOIN attempts a ON a.student_id = s.id
GROUP BY s.id, s.name, a.bab;

-- Contoh pemakaian:
-- SELECT * FROM v_rekap WHERE bab = 1 ORDER BY name;
-- SELECT s.name, a.mode, a.score, a.badge, a.created_at
--   FROM attempts a JOIN students s ON s.id = a.student_id ORDER BY a.created_at DESC;
