-- Database progres siswa (MySQL 8.0.16+ / MariaDB 10.4+)
CREATE DATABASE IF NOT EXISTS flipbook_dkv CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE flipbook_dkv;

-- Nama unik (huruf besar/kecil dianggap sama) dan hanya huruf + spasi
CREATE TABLE IF NOT EXISTS siswa (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nama        VARCHAR(30) NOT NULL,
  dibuat_pada TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_siswa_nama (nama),
  CONSTRAINT ck_nama_huruf CHECK (
    CHAR_LENGTH(nama) >= 2 AND nama REGEXP '^[[:alpha:]]+( [[:alpha:]]+)*$'
  )
) ENGINE=InnoDB;

-- Satu baris per siswa, per bab, per jenis (kuis/game)
CREATE TABLE IF NOT EXISTS progres (
  id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  siswa_id        INT UNSIGNED NOT NULL,
  bab             TINYINT UNSIGNED NOT NULL,
  jenis           ENUM('kuis','game') NOT NULL,
  skor            TINYINT UNSIGNED NOT NULL,
  lencana         ENUM('Perunggu','Perak','Emas') NOT NULL,
  materi_ulang    TEXT NULL,
  percobaan       SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  diperbarui_pada TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_progres (siswa_id, bab, jenis),
  CONSTRAINT fk_progres_siswa FOREIGN KEY (siswa_id) REFERENCES siswa(id) ON DELETE CASCADE,
  CONSTRAINT ck_skor CHECK (skor <= 100),
  CONSTRAINT ck_lencana CHECK (
    (skor < 60 AND lencana = 'Perunggu') OR (skor BETWEEN 60 AND 84 AND lencana = 'Perak') OR (skor >= 85 AND lencana = 'Emas')
  )
) ENGINE=InnoDB;

-- Rekap untuk guru
CREATE OR REPLACE VIEW rekap_guru AS
SELECT s.nama, p.bab, p.jenis, p.skor, p.lencana, p.percobaan, p.materi_ulang, p.diperbarui_pada
FROM progres p JOIN siswa s ON s.id = p.siswa_id
ORDER BY p.bab, s.nama, p.jenis;

-- Contoh: simpan hasil (sama dengan teks di kotak "Data untuk database" pada aplikasi)
INSERT IGNORE INTO siswa(nama) VALUES ('Rina Putri');
INSERT INTO progres(siswa_id,bab,jenis,skor,lencana,materi_ulang)
SELECT id,3,'kuis',75,'Perak','Peta situs (sitemap); Deskripsi halaman (SEO)' FROM siswa WHERE nama='Rina Putri'
ON DUPLICATE KEY UPDATE skor=VALUES(skor),lencana=VALUES(lencana),materi_ulang=VALUES(materi_ulang),percobaan=percobaan+1;

-- Catatan: pengecekan nama di database memakai aturan yang sama dengan aplikasi.
-- Untuk server (PHP/Node), validasi juga di sisi server dengan regex: /^\p{L}+(?: \p{L}+)*$/u
