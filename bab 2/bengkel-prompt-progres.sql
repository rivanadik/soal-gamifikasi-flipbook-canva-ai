-- Bengkel Prompt: database progres siswa (MySQL 8.0.17+ / MySQL Workbench / phpMyAdmin)
-- Aturan nama: hanya huruf (spasi antar kata boleh), tidak boleh sama (tanpa membedakan huruf besar/kecil).

CREATE DATABASE IF NOT EXISTS bengkel_prompt
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE bengkel_prompt;

CREATE TABLE siswa (
  id        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nama      VARCHAR(40) NOT NULL,
  dibuat_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  -- collation _ci membuat "Rivan" dan "rivan" dianggap sama
  UNIQUE KEY uq_siswa_nama (nama),
  -- tolak angka, simbol, dan spasi ganda
  CONSTRAINT ck_nama_huruf CHECK (
    CHAR_LENGTH(nama) >= 2 AND nama REGEXP '^[[:alpha:]]+( [[:alpha:]]+)*$'
  )
) ENGINE=InnoDB;

CREATE TABLE hasil_kuis (
  id        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  siswa_id  INT UNSIGNED NOT NULL,
  bab       TINYINT UNSIGNED NOT NULL DEFAULT 2,
  skor      TINYINT UNSIGNED NOT NULL,
  lencana   ENUM('Perunggu','Perak','Emas') NOT NULL,
  dibuat_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT ck_skor_kuis CHECK (skor BETWEEN 0 AND 100),
  FOREIGN KEY (siswa_id) REFERENCES siswa(id) ON DELETE CASCADE,
  INDEX ix_kuis_siswa (siswa_id, bab)
) ENGINE=InnoDB;

-- Rincian per soal: dipakai untuk daftar "materi yang perlu diulang"
CREATE TABLE jawaban_kuis (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  kuis_id    INT UNSIGNED NOT NULL,
  no_soal    TINYINT UNSIGNED NOT NULL,
  materi     VARCHAR(60) NOT NULL,
  percobaan  TINYINT UNSIGNED NOT NULL,   -- 1 atau 2
  benar      BOOLEAN NOT NULL,
  poin       TINYINT UNSIGNED NOT NULL,   -- 10, 5, atau 0
  FOREIGN KEY (kuis_id) REFERENCES hasil_kuis(id) ON DELETE CASCADE,
  CONSTRAINT ck_poin CHECK (poin IN (0,5,10))
) ENGINE=InnoDB;

CREATE TABLE hasil_game (
  id        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  siswa_id  INT UNSIGNED NOT NULL,
  bab       TINYINT UNSIGNED NOT NULL DEFAULT 2,
  level1    TINYINT UNSIGNED NOT NULL,    -- maks 40
  level2    TINYINT UNSIGNED NOT NULL,    -- maks 30
  level3    TINYINT UNSIGNED NOT NULL,    -- maks 30
  skor      TINYINT UNSIGNED GENERATED ALWAYS AS (level1 + level2 + level3) STORED,
  lencana   ENUM('Perunggu','Perak','Emas') NOT NULL,
  dibuat_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT ck_level CHECK (level1 <= 40 AND level2 <= 30 AND level3 <= 30),
  FOREIGN KEY (siswa_id) REFERENCES siswa(id) ON DELETE CASCADE,
  INDEX ix_game_siswa (siswa_id, bab)
) ENGINE=InnoDB;

-- Pendaftaran nama: memberi pesan jelas bila nama sudah dipakai atau tidak valid
DELIMITER //
CREATE PROCEDURE daftar_siswa(IN p_nama VARCHAR(40))
BEGIN
  DECLARE v_nama VARCHAR(40) DEFAULT TRIM(p_nama);
  IF v_nama NOT REGEXP '^[[:alpha:]]+( [[:alpha:]]+)*$' OR CHAR_LENGTH(v_nama) < 2 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Nama hanya boleh huruf, minimal 2 huruf.';
  END IF;
  IF EXISTS (SELECT 1 FROM siswa WHERE nama = v_nama) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Nama sudah dipakai. Tambahkan nama belakang.';
  END IF;
  INSERT INTO siswa (nama) VALUES (v_nama);
  SELECT LAST_INSERT_ID() AS siswa_id;
END//
DELIMITER ;

-- Rekap untuk guru: skor terbaik tiap siswa
CREATE VIEW v_rekap_guru AS
SELECT s.id, s.nama,
       (SELECT MAX(k.skor) FROM hasil_kuis k WHERE k.siswa_id = s.id AND k.bab = 2) AS kuis_terbaik,
       (SELECT MAX(g.skor) FROM hasil_game g WHERE g.siswa_id = s.id AND g.bab = 2) AS game_terbaik
FROM siswa s
ORDER BY s.nama;

-- Contoh pemakaian
-- CALL daftar_siswa('Rivan Adi');
-- INSERT INTO hasil_kuis (siswa_id, skor, lencana) VALUES (1, 90, 'Emas');
-- INSERT INTO hasil_game (siswa_id, level1, level2, level3, lencana) VALUES (1, 36, 25, 30, 'Perak');
-- SELECT * FROM v_rekap_guru;
