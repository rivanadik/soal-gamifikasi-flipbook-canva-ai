-- Initialization schema for Flipbook Gamifikasi Canva AI
-- Automatically executed by MySQL container entrypoint

SET NAMES utf8mb4;

-- ========================================================
-- BAB 1: Students & Quiz/Game Attempts
-- ========================================================
CREATE TABLE IF NOT EXISTS students (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  name        VARCHAR(60)  NOT NULL,
  name_key    VARCHAR(60)  NOT NULL,
  token_hash  CHAR(64)     NOT NULL,
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_students_name_key (name_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS attempts (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  student_id  INT UNSIGNED NOT NULL,
  bab         TINYINT UNSIGNED NOT NULL DEFAULT 1,
  mode        ENUM('quiz','game') NOT NULL,
  score       TINYINT UNSIGNED NOT NULL,
  badge       ENUM('Perunggu','Perak','Emas') NOT NULL,
  review      TEXT NULL,
  created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_attempts_student (student_id, bab, mode),
  CONSTRAINT fk_attempts_student FOREIGN KEY (student_id)
    REFERENCES students(id) ON DELETE CASCADE,
  CONSTRAINT ck_attempts_score CHECK (score <= 100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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

-- ========================================================
-- BAB 2: Hasil Kuis Bengkel Prompt
-- ========================================================
CREATE TABLE IF NOT EXISTS hasil_kuis (
  id        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  siswa_id  INT UNSIGNED NOT NULL,
  bab       TINYINT UNSIGNED NOT NULL DEFAULT 2,
  skor      TINYINT UNSIGNED NOT NULL,
  lencana   ENUM('Perunggu','Perak','Emas') NOT NULL,
  dibuat_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ========================================================
-- BAB 3: Progres Flipbook DKV
-- ========================================================
CREATE TABLE IF NOT EXISTS flipbook_progres (
  id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  siswa_id        INT UNSIGNED NOT NULL,
  bab             TINYINT UNSIGNED NOT NULL,
  jenis           ENUM('kuis','game') NOT NULL,
  skor            TINYINT UNSIGNED NOT NULL,
  lencana         ENUM('Perunggu','Perak','Emas') NOT NULL,
  materi_ulang    TEXT NULL,
  percobaan       SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  dibuat_pada     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ========================================================
-- BAB 5: Siswa & Progres Stasiun / Evaluasi
-- ========================================================
CREATE TABLE IF NOT EXISTS siswa (
  id      INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  nama    VARCHAR(40) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  dibuat  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_siswa_nama (nama),
  CONSTRAINT chk_siswa_nama CHECK (nama REGEXP '^[A-Za-z]+( [A-Za-z]+)*$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS progres (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  siswa_id    INT UNSIGNED NOT NULL,
  aktivitas   VARCHAR(20) NOT NULL,
  skor        TINYINT UNSIGNED NOT NULL DEFAULT 0,
  diperbarui  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_siswa_aktivitas (siswa_id, aktivitas),
  CONSTRAINT fk_progres_siswa FOREIGN KEY (siswa_id) REFERENCES siswa(id) ON DELETE CASCADE,
  CONSTRAINT chk_progres_skor CHECK (skor <= 100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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
