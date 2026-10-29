-- =====================================================================
-- Database progres siswa e-modul "Pemanfaatan Canva AI dalam Pembelajaran DKV"
-- Untuk PostgreSQL / Supabase (jalankan di SQL Editor). Berlaku untuk Bab 1-5.
-- Aturan nama: hanya huruf A-Z/a-z dan spasi antar kata, 3-40 karakter,
-- unik tanpa membedakan huruf besar/kecil.
-- =====================================================================

-- ============ TABEL ============
create table if not exists siswa (
  id          uuid primary key default gen_random_uuid(),
  nama        text not null,
  dibuat_pada timestamptz not null default now(),
  constraint nama_hanya_huruf check (nama ~ '^[A-Za-z]+( [A-Za-z]+)*$'),
  constraint nama_panjang     check (char_length(nama) between 3 and 40)
);

create unique index if not exists siswa_nama_unik on siswa (lower(nama));

create table if not exists progres (
  id           bigserial primary key,
  siswa_id     uuid not null references siswa(id) on delete cascade,
  bab          smallint not null check (bab between 1 and 5),
  jenis        text not null check (jenis in ('kuis','game')),
  level        smallint check (level between 1 and 4),   -- null untuk kuis
  skor         smallint not null check (skor between 0 and 100),
  lencana      text check (lencana in ('Perunggu','Perak','Emas')),
  materi_ulang text,                                      -- materi yang perlu diulang
  dibuat_pada  timestamptz not null default now()
);

create index if not exists progres_siswa_idx on progres (siswa_id, bab, jenis);

-- ============ FUNGSI (dipanggil dari aplikasi) ============
create or replace function daftar_siswa(p_nama text)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_nama text := regexp_replace(btrim(p_nama), '\s+', ' ', 'g');
  v_id uuid;
begin
  insert into siswa (nama) values (v_nama) returning id into v_id;
  return v_id;
exception
  when unique_violation then raise exception 'NAMA_SUDAH_ADA';
  when check_violation  then raise exception 'NAMA_TIDAK_VALID';
end $$;

create or replace function masuk_siswa(p_nama text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  select id into v_id from siswa
   where lower(nama) = lower(regexp_replace(btrim(p_nama), '\s+', ' ', 'g'));
  if v_id is null then raise exception 'NAMA_TIDAK_DITEMUKAN'; end if;
  return v_id;
end $$;

create or replace function simpan_progres(
  p_siswa uuid, p_bab smallint, p_jenis text, p_level smallint,
  p_skor smallint, p_lencana text, p_ulang text)
returns void language sql security definer set search_path = public as $$
  insert into progres (siswa_id, bab, jenis, level, skor, lencana, materi_ulang)
  values (p_siswa, p_bab, p_jenis, p_level, p_skor, p_lencana, p_ulang);
$$;

-- ============ KEAMANAN ============
-- Aplikasi hanya boleh memanggil fungsi, tidak boleh membaca tabel langsung.
alter table siswa   enable row level security;
alter table progres enable row level security;
revoke all on siswa, progres from anon, authenticated;
grant execute on function daftar_siswa(text), masuk_siswa(text),
  simpan_progres(uuid, smallint, text, smallint, smallint, text, text) to anon;

-- ============ REKAP UNTUK GURU (lihat lewat dashboard Supabase) ============
create or replace view rekap_siswa as
select s.nama, p.bab, p.jenis,
       max(p.skor)        as skor_terbaik,
       count(*)           as jumlah_percobaan,
       max(p.dibuat_pada) as terakhir
from progres p join siswa s on s.id = p.siswa_id
group by s.nama, p.bab, p.jenis
order by s.nama, p.bab, p.jenis;
