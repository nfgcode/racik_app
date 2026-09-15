-- =====================================================================
-- Racik — skema database Supabase (PostgreSQL)
--
-- Diturunkan dari ERD (dbdiagram.io). Cara pakai:
--   Supabase Dashboard → SQL Editor → New query → tempel file ini → Run.
-- Setelah itu jalankan seed.sql untuk data contoh.
--
-- Baris bertanda  -- [TAMBAHAN]  tidak ada di ERD. Ditambahkan karena
-- dibutuhkan aplikasi; alasannya ditulis di sebelahnya. Silakan
-- dimasukkan ke ERD atau dihapus sesuai keputusan tim.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. TABEL
-- ---------------------------------------------------------------------

-- users — profil. Email & password disimpan Supabase Auth (auth.users),
-- karena itu kolom id di sini sekaligus FK ke auth.users.
create table public.users (
  id          uuid primary key references auth.users (id) on delete cascade,
  username    varchar(50)  not null unique,
  full_name   varchar(100),
  avatar_url  text,
  role        varchar(20)  not null default 'pengguna'
              check (role in ('pengguna', 'admin')),          -- [TAMBAHAN] batasi nilai
  is_active   boolean      not null default true,
  created_at  timestamptz  default now()
);

create table public.foods (
  id                 uuid primary key default gen_random_uuid(),
  name               varchar(120) not null,
  description        text,
  image_url          text,
  category           varchar(50),
  serving_size       varchar(30),
  cook_time_minutes  int,
  difficulty         varchar(20)
                     check (difficulty in ('mudah', 'sedang', 'sulit')),  -- [TAMBAHAN]
  source             varchar(20) default 'admin'
                     check (source in ('admin', 'ai')),                    -- [TAMBAHAN]
  scan_count         int default 0,
  is_verified        boolean default false,
  verified_by        uuid references public.users (id) on delete set null,
  verified_at        timestamptz,
  created_by         uuid references public.users (id) on delete set null,
  created_at         timestamptz default now()
);
-- [TAMBAHAN] Label AI dicocokkan ke foods.name. Nama ganda membuat
-- pencocokan ambigu, jadi nama dibuat unik tanpa membedakan huruf besar/kecil.
create unique index foods_name_lower_key on public.foods (lower(name));

-- nutritions — 1 : 1 dengan foods (food_id unik).
create table public.nutritions (
  id         uuid primary key default gen_random_uuid(),
  food_id    uuid not null unique references public.foods (id) on delete cascade,
  calories   numeric(7,2) not null,
  protein_g  numeric(6,2),
  fat_g      numeric(6,2),
  carbs_g    numeric(6,2),
  sugar_g    numeric(6,2),
  sodium_mg  numeric(7,2),
  fiber_g    numeric(6,2)
);

create table public.ingredients (
  id    uuid primary key default gen_random_uuid(),
  name  varchar(80) not null unique,
  unit  varchar(20)
);

-- food_ingredients — penghubung many-to-many foods ↔ ingredients.
-- ingredient: ON DELETE RESTRICT → bahan yang masih dipakai resep tidak
-- bisa dihapus (aplikasi menampilkan pesan "masih dipakai").
create table public.food_ingredients (
  id             uuid primary key default gen_random_uuid(),
  food_id        uuid not null references public.foods (id) on delete cascade,
  ingredient_id  uuid not null references public.ingredients (id) on delete restrict,
  quantity       numeric(8,2),
  note           varchar(100)
);

create table public.steps (
  id                uuid primary key default gen_random_uuid(),
  food_id           uuid not null references public.foods (id) on delete cascade,
  step_order        int  not null,
  instruction       text not null,
  duration_minutes  int
);

-- scan_history — food_id boleh kosong: AI mengenali label yang resepnya
-- belum ada. ON DELETE SET NULL → riwayat tetap ada saat resep dihapus.
create table public.scan_history (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references public.users (id) on delete cascade,
  food_id        uuid references public.foods (id) on delete set null,
  image_url      text,
  ai_confidence  numeric(5,2),
  fuzzy_score    numeric(5,2),
  fuzzy_label    varchar(20),
  scan_status    varchar(20)
                 check (scan_status in ('berhasil', 'tidak_yakin', 'tidak_ditemukan')), -- [TAMBAHAN]
  created_at     timestamptz default now()
);

create table public.favorites (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.users (id) on delete cascade,
  food_id     uuid not null references public.foods (id) on delete cascade,
  created_at  timestamptz default now(),
  unique (user_id, food_id)                 -- [TAMBAHAN] cegah favorit ganda
);

-- Indeks untuk query yang paling sering dijalankan aplikasi.
create index scan_history_user_created_idx on public.scan_history (user_id, created_at desc);
create index steps_food_idx on public.steps (food_id);
create index food_ingredients_food_idx on public.food_ingredients (food_id);


-- ---------------------------------------------------------------------
-- 2. FUNGSI & TRIGGER
-- ---------------------------------------------------------------------

-- Apakah yang sedang login adalah admin aktif? Dipakai semua kebijakan RLS.
-- SECURITY DEFINER: berjalan dengan hak pemilik fungsi sehingga bisa
-- membaca tabel users tanpa terjebak RLS tabel users sendiri (rekursi).
create or replace function public.is_admin()
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.users
    where id = auth.uid() and role = 'admin' and is_active
  );
$$;

-- Dipanggil halaman Daftar (oleh tamu) untuk mengecek username.
create or replace function public.username_available(p_username text)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select not exists (
    select 1 from public.users where lower(username) = lower(p_username)
  );
$$;
grant execute on function public.username_available(text) to anon, authenticated;

-- Setiap akun baru di Supabase Auth → otomatis satu baris di public.users.
-- username & full_name dikirim aplikasi lewat signUp(data: {...}).
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.users (id, username, full_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'username', split_part(new.email, '@', 1)),
    new.raw_user_meta_data ->> 'full_name'
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Pengguna boleh mengubah profilnya sendiri, TETAPI tidak boleh menjadikan
-- dirinya admin atau mengaktifkan akunnya sendiri.
-- auth.uid() kosong = dijalankan dari SQL Editor / server → diizinkan.
create or replace function public.protect_user_access_columns()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if auth.uid() is not null
     and not public.is_admin()
     and (new.role is distinct from old.role
          or new.is_active is distinct from old.is_active) then
    raise exception 'Hanya admin yang boleh mengubah peran atau status akun'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger users_protect_access_columns
  before update on public.users
  for each row execute function public.protect_user_access_columns();

-- foods.scan_count naik setiap ada pindai yang cocok dengan resep.
-- SECURITY DEFINER karena Pengguna tidak punya izin mengubah tabel foods.
create or replace function public.increment_scan_count()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if new.food_id is not null then
    update public.foods
       set scan_count = coalesce(scan_count, 0) + 1
     where id = new.food_id;
  end if;
  return new;
end;
$$;

create trigger scan_history_increment_count
  after insert on public.scan_history
  for each row execute function public.increment_scan_count();

-- Stored procedure verifikasi resep
create or replace procedure public.sp_verify_food(
  p_food_id uuid,
  p_admin_id uuid
)
language plpgsql security definer
as $$
begin
  update public.foods
     set is_verified = true,
         verified_by = p_admin_id,
         verified_at = now()
   where id = p_food_id;
end;
$$;

-- Stored procedure hapus riwayat pindai
create or replace procedure public.sp_clear_user_history(
  p_user_id uuid
)
language plpgsql security definer
as $$
begin
  delete from public.scan_history
   where user_id = p_user_id;
end;
$$;

grant execute on procedure public.sp_verify_food(uuid, uuid) to authenticated;
grant execute on procedure public.sp_clear_user_history(uuid) to authenticated;


-- ---------------------------------------------------------------------
-- 3. ROW LEVEL SECURITY — hak akses per aktor use case
--    anon          = Guest (belum login)
--    authenticated = Pengguna / Admin (dibedakan dengan is_admin())
-- ---------------------------------------------------------------------

alter table public.users            enable row level security;
alter table public.foods            enable row level security;
alter table public.nutritions       enable row level security;
alter table public.ingredients      enable row level security;
alter table public.food_ingredients enable row level security;
alter table public.steps            enable row level security;
alter table public.scan_history     enable row level security;
alter table public.favorites        enable row level security;

-- users: lihat & ubah profil sendiri; admin melihat & mengubah semua.
create policy "users: baca diri sendiri atau admin" on public.users
  for select to authenticated
  using (id = auth.uid() or public.is_admin());
create policy "users: ubah diri sendiri atau admin" on public.users
  for update to authenticated
  using (id = auth.uid() or public.is_admin());

-- foods: Guest & Pengguna hanya melihat resep terverifikasi (Mencari
-- Resep, Melihat Detail Resep). Admin melihat dan mengelola semuanya.
create policy "foods: baca yang terverifikasi" on public.foods
  for select to anon, authenticated
  using (is_verified or public.is_admin());
create policy "foods: admin tambah" on public.foods
  for insert to authenticated with check (public.is_admin());
create policy "foods: admin ubah" on public.foods
  for update to authenticated using (public.is_admin());
create policy "foods: admin hapus" on public.foods
  for delete to authenticated using (public.is_admin());

-- Tabel anak resep + master bahan: semua boleh baca, hanya admin menulis.
do $$
declare t text;
begin
  foreach t in array array['nutritions', 'steps', 'food_ingredients', 'ingredients'] loop
    execute format(
      'create policy "%1$s: semua boleh baca" on public.%1$I
         for select to anon, authenticated using (true)', t);
    execute format(
      'create policy "%1$s: admin menulis" on public.%1$I
         for all to authenticated
         using (public.is_admin()) with check (public.is_admin())', t);
  end loop;
end $$;

-- scan_history: Pengguna hanya melihat, menambah, dan menghapus miliknya.
-- Admin boleh membaca semua (Melihat Statistik Pemindaian Pengguna).
create policy "scan: baca milik sendiri atau admin" on public.scan_history
  for select to authenticated
  using (user_id = auth.uid() or public.is_admin());
create policy "scan: tambah milik sendiri" on public.scan_history
  for insert to authenticated
  with check (user_id = auth.uid());
create policy "scan: hapus milik sendiri" on public.scan_history
  for delete to authenticated
  using (user_id = auth.uid());

-- favorites: sepenuhnya milik pengguna masing-masing.
create policy "favorites: milik sendiri" on public.favorites
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());


-- ---------------------------------------------------------------------
-- 4. STORAGE — tempat foto
--    Bucket publik: siapa pun yang tahu URL bisa melihat foto.
--    Untuk foto pindai yang lebih privat, jadikan bucket privat dan
--    tampilkan dengan createSignedUrl().
-- ---------------------------------------------------------------------

insert into storage.buckets (id, name, public) values
  ('scan-images', 'scan-images', true),
  ('food-images', 'food-images', true),
  ('avatars',     'avatars',     true)
on conflict (id) do nothing;

-- Pengguna hanya boleh menulis ke folder bernama id-nya sendiri:
--   scan-images/<user_id>/1726040000000.jpg
create policy "storage: unggah ke folder sendiri" on storage.objects
  for insert to authenticated
  with check (
    bucket_id in ('scan-images', 'avatars')
    and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy "storage: hapus file sendiri" on storage.objects
  for delete to authenticated
  using (
    bucket_id in ('scan-images', 'avatars')
    and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy "storage: admin unggah foto resep" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'food-images' and public.is_admin());


-- ---------------------------------------------------------------------
-- 5. ADMIN PERTAMA
--    Daftar lewat aplikasi seperti biasa, lalu jalankan (ganti username):
--
--    update public.users set role = 'admin' where username = 'username_anda';
-- ---------------------------------------------------------------------
