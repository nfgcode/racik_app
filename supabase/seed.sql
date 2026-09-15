-- =====================================================================
-- Racik — data contoh untuk mencoba aplikasi. Jalankan SETELAH schema.sql.
--
-- PERHATIAN: angka gizi di bawah adalah PERKIRAAN KASAR untuk keperluan
-- uji coba, bukan data resmi. Ganti dengan nilai dari Tabel Komposisi
-- Pangan Indonesia (TKPI) sebelum dipakai di laporan atau demo akhir.
--
-- Nama makanan sama dengan label DemoFoodRecognizer, sehingga alur
-- pindai bisa dicoba sebelum model TFLite selesai dilatih.
-- =====================================================================

insert into public.ingredients (name, unit) values
  ('Nasi putih', 'gram'), ('Telur ayam', 'butir'), ('Bawang merah', 'siung'),
  ('Bawang putih', 'siung'), ('Kecap manis', 'sdm'), ('Cabai merah', 'buah'),
  ('Minyak goreng', 'sdm'), ('Garam', 'sdt'), ('Kol', 'gram'),
  ('Tauge', 'gram'), ('Kacang panjang', 'gram'), ('Kentang', 'buah'),
  ('Tahu', 'potong'), ('Tempe', 'potong'), ('Kacang tanah', 'gram'),
  ('Gula merah', 'gram'), ('Daging ayam', 'gram'), ('Kunyit', 'cm'),
  ('Serai', 'batang'), ('Daun jeruk', 'lembar'), ('Daging sapi', 'gram'),
  ('Santan', 'ml'), ('Pisang kepok', 'buah'), ('Tepung terigu', 'gram'),
  ('Bayam', 'ikat'), ('Jagung manis', 'buah'), ('Air', 'ml')
on conflict (name) do nothing;

-- Pola setiap blok: CTE "f" menyisipkan resep dan mengembalikan id-nya,
-- lalu nutrisi, langkah, dan bahan disisipkan memakai id tersebut.

-- 1. Nasi Goreng ------------------------------------------------------
with f as (
  insert into public.foods (name, description, category, serving_size,
                            cook_time_minutes, difficulty, source, is_verified)
  values ('Nasi Goreng', 'Nasi digoreng dengan bumbu bawang, kecap manis, dan telur.',
          'Nasi', '1 piring (300 g)', 20, 'mudah', 'admin', true)
  returning id
), n as (
  insert into public.nutritions (food_id, calories, protein_g, fat_g, carbs_g,
                                 sugar_g, sodium_mg, fiber_g)
  select id, 520, 15, 18, 72, 5, 950, 2.5 from f
), s as (
  insert into public.steps (food_id, step_order, instruction, duration_minutes)
  select f.id, v.o, v.t, v.d from f, (values
    (1, 'Haluskan bawang merah, bawang putih, dan cabai.', 5),
    (2, 'Tumis bumbu halus dengan minyak sampai harum.', 3),
    (3, 'Masukkan telur, orak-arik sebentar.', 2),
    (4, 'Masukkan nasi, kecap manis, dan garam. Aduk rata sampai panas.', 7)
  ) as v(o, t, d)
)
insert into public.food_ingredients (food_id, ingredient_id, quantity, note)
select f.id, i.id, v.q, v.note from f, (values
  ('Nasi putih', 250, 'nasi dingin lebih baik'), ('Telur ayam', 1, null),
  ('Bawang merah', 4, null), ('Bawang putih', 2, null), ('Cabai merah', 2, null),
  ('Kecap manis', 2, null), ('Minyak goreng', 2, null), ('Garam', 0.5, null)
) as v(name, q, note)
join public.ingredients i on i.name = v.name;

-- 2. Gado-Gado --------------------------------------------------------
with f as (
  insert into public.foods (name, description, category, serving_size,
                            cook_time_minutes, difficulty, source, is_verified)
  values ('Gado-Gado', 'Sayuran rebus, tahu, dan tempe dengan saus kacang.',
          'Sayuran', '1 piring (350 g)', 30, 'sedang', 'admin', true)
  returning id
), n as (
  insert into public.nutritions (food_id, calories, protein_g, fat_g, carbs_g,
                                 sugar_g, sodium_mg, fiber_g)
  select id, 380, 16, 20, 34, 9, 600, 7 from f
), s as (
  insert into public.steps (food_id, step_order, instruction, duration_minutes)
  select f.id, v.o, v.t, v.d from f, (values
    (1, 'Rebus kol, tauge, kacang panjang, dan kentang sampai matang.', 15),
    (2, 'Goreng tahu dan tempe, lalu potong-potong.', 8),
    (3, 'Haluskan kacang tanah goreng, gula merah, cabai, dan garam; beri air.', 5),
    (4, 'Tata sayuran, siram dengan saus kacang.', 2)
  ) as v(o, t, d)
)
insert into public.food_ingredients (food_id, ingredient_id, quantity, note)
select f.id, i.id, v.q, v.note from f, (values
  ('Kol', 50, 'iris kasar'), ('Tauge', 50, null), ('Kacang panjang', 50, 'potong 3 cm'),
  ('Kentang', 1, null), ('Tahu', 2, null), ('Tempe', 2, null),
  ('Kacang tanah', 60, 'goreng dulu'), ('Gula merah', 15, null), ('Cabai merah', 1, null)
) as v(name, q, note)
join public.ingredients i on i.name = v.name;

-- 3. Soto Ayam --------------------------------------------------------
with f as (
  insert into public.foods (name, description, category, serving_size,
                            cook_time_minutes, difficulty, source, is_verified)
  values ('Soto Ayam', 'Sup ayam berkuah kuning dengan kunyit dan serai.',
          'Berkuah', '1 mangkuk (400 g)', 60, 'sedang', 'admin', true)
  returning id
), n as (
  insert into public.nutritions (food_id, calories, protein_g, fat_g, carbs_g,
                                 sugar_g, sodium_mg, fiber_g)
  select id, 310, 22, 12, 28, 3, 1100, 2 from f
), s as (
  insert into public.steps (food_id, step_order, instruction, duration_minutes)
  select f.id, v.o, v.t, v.d from f, (values
    (1, 'Rebus ayam dalam air sampai empuk, angkat lalu suwir.', 30),
    (2, 'Tumis bawang merah, bawang putih, dan kunyit halus bersama serai dan daun jeruk.', 5),
    (3, 'Masukkan bumbu ke kaldu, beri garam, masak 15 menit.', 15),
    (4, 'Sajikan kuah dengan suwiran ayam, tauge, dan telur rebus.', 2)
  ) as v(o, t, d)
)
insert into public.food_ingredients (food_id, ingredient_id, quantity, note)
select f.id, i.id, v.q, v.note from f, (values
  ('Daging ayam', 150, null), ('Air', 500, null), ('Kunyit', 2, 'bakar sebentar'),
  ('Serai', 1, 'memarkan'), ('Daun jeruk', 2, null), ('Bawang merah', 4, null),
  ('Bawang putih', 3, null), ('Tauge', 30, null), ('Telur ayam', 1, 'rebus'),
  ('Garam', 1, null)
) as v(name, q, note)
join public.ingredients i on i.name = v.name;

-- 4. Rendang ----------------------------------------------------------
with f as (
  insert into public.foods (name, description, category, serving_size,
                            cook_time_minutes, difficulty, source, is_verified)
  values ('Rendang', 'Daging sapi dimasak lama dalam santan dan rempah sampai kering.',
          'Lauk', '1 potong (100 g)', 240, 'sulit', 'admin', true)
  returning id
), n as (
  insert into public.nutritions (food_id, calories, protein_g, fat_g, carbs_g,
                                 sugar_g, sodium_mg, fiber_g)
  select id, 470, 27, 37, 8, 4, 800, 2 from f
), s as (
  insert into public.steps (food_id, step_order, instruction, duration_minutes)
  select f.id, v.o, v.t, v.d from f, (values
    (1, 'Haluskan bawang merah, bawang putih, cabai, dan kunyit.', 10),
    (2, 'Masak santan bersama bumbu halus, serai, dan daun jeruk sampai mendidih.', 15),
    (3, 'Masukkan daging, masak dengan api kecil sambil sesekali diaduk.', 180),
    (4, 'Lanjutkan sampai kuah mengering dan bumbu berwarna cokelat gelap.', 35)
  ) as v(o, t, d)
)
insert into public.food_ingredients (food_id, ingredient_id, quantity, note)
select f.id, i.id, v.q, v.note from f, (values
  ('Daging sapi', 500, 'potong sesuai serat'), ('Santan', 1000, null),
  ('Bawang merah', 10, null), ('Bawang putih', 5, null), ('Cabai merah', 8, null),
  ('Kunyit', 3, null), ('Serai', 2, 'memarkan'), ('Daun jeruk', 4, null),
  ('Garam', 1, null)
) as v(name, q, note)
join public.ingredients i on i.name = v.name;

-- 5. Pisang Goreng ----------------------------------------------------
with f as (
  insert into public.foods (name, description, category, serving_size,
                            cook_time_minutes, difficulty, source, is_verified)
  values ('Pisang Goreng', 'Pisang kepok berbalut adonan tepung, digoreng renyah.',
          'Camilan', '2 buah (120 g)', 15, 'mudah', 'admin', true)
  returning id
), n as (
  insert into public.nutritions (food_id, calories, protein_g, fat_g, carbs_g,
                                 sugar_g, sodium_mg, fiber_g)
  select id, 330, 3, 16, 45, 18, 150, 3 from f
), s as (
  insert into public.steps (food_id, step_order, instruction, duration_minutes)
  select f.id, v.o, v.t, v.d from f, (values
    (1, 'Campur tepung terigu, garam, dan air sampai kental.', 3),
    (2, 'Belah pisang, celupkan ke adonan.', 2),
    (3, 'Goreng dalam minyak panas sampai kuning keemasan.', 8)
  ) as v(o, t, d)
)
insert into public.food_ingredients (food_id, ingredient_id, quantity, note)
select f.id, i.id, v.q, v.note from f, (values
  ('Pisang kepok', 2, 'yang matang'), ('Tepung terigu', 60, null),
  ('Air', 80, null), ('Garam', 0.25, null), ('Minyak goreng', 10, 'untuk menggoreng')
) as v(name, q, note)
join public.ingredients i on i.name = v.name;

-- 6. Sayur Bening Bayam -----------------------------------------------
with f as (
  insert into public.foods (name, description, category, serving_size,
                            cook_time_minutes, difficulty, source, is_verified)
  values ('Sayur Bening Bayam', 'Sup bening bayam dan jagung manis.',
          'Berkuah', '1 mangkuk (250 g)', 15, 'mudah', 'admin', true)
  returning id
), n as (
  insert into public.nutritions (food_id, calories, protein_g, fat_g, carbs_g,
                                 sugar_g, sodium_mg, fiber_g)
  select id, 60, 3, 1, 9, 2, 350, 3 from f
), s as (
  insert into public.steps (food_id, step_order, instruction, duration_minutes)
  select f.id, v.o, v.t, v.d from f, (values
    (1, 'Didihkan air bersama irisan bawang merah dan bawang putih.', 5),
    (2, 'Masukkan jagung manis, masak sampai empuk.', 5),
    (3, 'Masukkan bayam dan garam, angkat begitu bayam layu.', 2)
  ) as v(o, t, d)
)
insert into public.food_ingredients (food_id, ingredient_id, quantity, note)
select f.id, i.id, v.q, v.note from f, (values
  ('Bayam', 1, 'petik daunnya'), ('Jagung manis', 1, 'pipil'),
  ('Bawang merah', 3, 'iris'), ('Bawang putih', 1, 'iris'),
  ('Air', 600, null), ('Garam', 0.5, null)
) as v(name, q, note)
join public.ingredients i on i.name = v.name;
