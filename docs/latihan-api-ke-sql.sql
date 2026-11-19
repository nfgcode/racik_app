-- =====================================================================
-- Racik — Latihan: dari service Dart → API Supabase → SQL
--
-- Cara pakai:
--   Supabase Dashboard → SQL Editor → tempel file ini → BLOK satu bagian
--   (mis. dari "1.1" sampai sebelum "1.2") → Run. Jangan Run semuanya
--   sekaligus.
--
-- Setiap bagian berisi tiga hal:
--   Dart : potongan kode di lib/services/... yang memanggil API
--   HTTP : request yang sebenarnya dikirim aplikasi ke Supabase (PostgREST)
--   SQL  : query yang setara, bisa dijalankan di SQL Editor
--
-- PENTING (sering bikin bingung):
--   SQL Editor berjalan sebagai role "postgres", yang MELEWATI RLS dan
--   tidak punya auth.uid(). Jadi hasilnya bisa berbeda dengan yang dilihat
--   aplikasi. Untuk meniru aplikasi, pakai blok "begin; set local role ...;
--   ... rollback;" seperti di bagian 0 dan 8.
--
-- Blok yang mengubah data selalu diapit begin ... rollback, jadi datamu
-- tidak benar-benar berubah. Blok bertanda [SENGAJA ERROR] memang
-- dirancang gagal untuk menunjukkan aturan keamanan.
--
-- Butuh: schema.sql + seed.sql sudah dijalankan, dan minimal satu akun
-- pengguna dan satu akun admin sudah terdaftar lewat aplikasi.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 0. PEMANASAN: lihat datanya dulu
-- ---------------------------------------------------------------------
select id, username, role, is_active from public.users order by created_at;
select id, name, is_verified, scan_count from public.foods order by name;


-- ---------------------------------------------------------------------
-- 1. FoodService  (lib/services/food_service.dart)
-- ---------------------------------------------------------------------

-- 1.1 search(query: 'soto')  → tab Resep (Guest & Pengguna)
-- Dart : _client.from('foods').select('*, nutritions(*)')
--          .ilike('name', '%soto%').eq('is_verified', true).order('name')
-- HTTP : GET /rest/v1/foods?select=*,nutritions(*)&name=ilike.%25soto%25
--          &is_verified=eq.true&order=name.asc          (%25 = tanda % yang di-encode di URL)
-- SQL  :
select f.id, f.name, f.category, n.calories, n.sugar_g, n.sodium_mg
from public.foods f
left join public.nutritions n on n.food_id = f.id      -- "nutritions(*)" = join lewat FK
where f.name ilike '%soto%'                             -- .ilike(...)
  and f.is_verified = true                              -- .eq('is_verified', true)
order by f.name;                                        -- .order('name')

-- 1.2 categories()  → chip kategori di tab Resep
-- Dart : _client.from('foods').select('category').eq('is_verified', true)
--          .not('category', 'is', null)      (lalu dibuat unik di Dart)
-- HTTP : GET /rest/v1/foods?select=category&is_verified=eq.true&category=not.is.null
-- SQL  :
select distinct category
from public.foods
where is_verified = true and category is not null
order by category;

-- 1.3 getDetail(id)  → layar Detail Resep
-- Dart : _client.from('foods')
--          .select('*, nutritions(*), steps(*), food_ingredients(*, ingredients(*))')
--          .eq('id', id).maybeSingle()
-- HTTP : GET /rest/v1/foods?select=*,nutritions(*),steps(*),food_ingredients(*,ingredients(*))
--          &id=eq.<uuid>
-- SQL (bentuk JSON bersarang, persis seperti yang diterima Food.fromMap):
select f.name,
       (select to_jsonb(n) from public.nutritions n where n.food_id = f.id)          as nutritions,
       (select jsonb_agg(to_jsonb(s) order by s.step_order)
          from public.steps s where s.food_id = f.id)                                 as steps,
       (select jsonb_agg(jsonb_build_object('quantity', fi.quantity, 'note', fi.note,
                                            'ingredients', to_jsonb(i)))
          from public.food_ingredients fi
          join public.ingredients i on i.id = fi.ingredient_id
         where fi.food_id = f.id)                                                     as food_ingredients
from public.foods f
where f.name = 'Gado-Gado';     -- aplikasi memakai id; di sini pakai nama supaya mudah

-- SQL (bentuk tabel biasa, lebih mudah dibaca): bahan dan langkah
select i.name as bahan, fi.quantity, i.unit, fi.note
from public.food_ingredients fi
join public.ingredients i on i.id = fi.ingredient_id
join public.foods f on f.id = fi.food_id
where f.name = 'Gado-Gado';

select s.step_order, s.instruction, s.duration_minutes
from public.steps s
join public.foods f on f.id = s.food_id
where f.name = 'Gado-Gado'
order by s.step_order;

-- 1.4 findByName('nasi goreng')  → dipakai ScanPipeline setelah AI menebak
-- Dart : tahap 1 .ilike('name', cleanName)      (tanpa %, = sama persis tapi tak peduli huruf besar/kecil)
--        tahap 2 .ilike('name', '%$cleanName%')
--        tahap 3 .ilike('name', '%<dua kata pertama>%')
--        selalu .eq('is_verified', true).limit(1)
-- HTTP : GET /rest/v1/foods?select=...&name=ilike.nasi%20goreng&is_verified=eq.true&limit=1
-- SQL  :
select id, name from public.foods where name ilike 'nasi goreng'   and is_verified limit 1;  -- tahap 1
select id, name from public.foods where name ilike '%goreng%'      and is_verified limit 1;  -- tahap 2 (contoh label "goreng")
select id, name from public.foods where name ilike '%soto ayam%'   and is_verified limit 1;  -- tahap 3 dari label "Soto Ayam Lamongan"

-- 1.5 setVerified(...)  → admin menekan tombol verifikasi
-- Dart : _client.from('foods').update({'is_verified': true, 'verified_by': adminId,
--          'verified_at': <sekarang>}).eq('id', foodId)
-- HTTP : PATCH /rest/v1/foods?id=eq.<uuid>   body: {"is_verified":true, ...}
-- SQL  :
begin;
update public.foods
   set is_verified = false, verified_by = null, verified_at = null      -- batalkan verifikasi
 where name = 'Rendang'
returning name, is_verified;
update public.foods
   set is_verified = true,
       verified_by = (select id from public.users where role = 'admin' order by created_at limit 1),
       verified_at = now()
 where name = 'Rendang'
returning name, is_verified, verified_at;
rollback;

-- 1.6 saveFood(...)  → admin menyimpan form resep (bagian nutrisi)
-- Dart : _client.from('nutritions').upsert({...nutrition.toMap(), 'food_id': foodId},
--          onConflict: 'food_id')
-- HTTP : POST /rest/v1/nutritions?on_conflict=food_id
--          header Prefer: resolution=merge-duplicates
-- SQL  : upsert = insert, dan kalau food_id sudah ada → update
begin;
insert into public.nutritions (food_id, calories, sugar_g)
values ((select id from public.foods where name = 'Gado-Gado'), 400, 10)
on conflict (food_id) do update
   set calories = excluded.calories, sugar_g = excluded.sugar_g
returning food_id, calories, sugar_g;
rollback;

-- 1.7 deleteFood(id)  → admin menghapus resep
-- Dart : _client.from('foods').delete().eq('id', id)
-- HTTP : DELETE /rest/v1/foods?id=eq.<uuid>
-- SQL  : lihat efek ON DELETE CASCADE ke tabel anak
begin;
select (select count(*) from public.steps)            as steps_sebelum,
       (select count(*) from public.food_ingredients) as bahan_resep_sebelum;
delete from public.foods where name = 'Pisang Goreng';
select (select count(*) from public.steps)            as steps_sesudah,
       (select count(*) from public.food_ingredients) as bahan_resep_sesudah;
rollback;

-- 1.8 createFromAi(name, nutrition)  → ScanPipeline, bila makanan belum ada di database
-- Dart : _client.rpc('create_food_from_ai', params: {'p_name': 'Bakso',
--          'p_calories': 300, 'p_protein_g': 15, ... 'p_fiber_g': 1})
-- HTTP : POST /rest/v1/rpc/create_food_from_ai   body: {"p_name":"Bakso","p_calories":300,...}
-- SQL  : dijalankan sebagai pengguna biasa. Resep + nutrisi tersimpan dalam
--        satu transaksi, selalu is_verified = false (menunggu ditinjau admin).
--        Butuh supabase/patch-01-perbaikan-bug.sql (atau schema.sql terbaru).
begin;
select set_config('request.jwt.claims',
       json_build_object('sub', (select id from public.users where role = 'pengguna' order by created_at limit 1),
                         'role', 'authenticated')::text, true);
set local role authenticated;
select public.create_food_from_ai('Bakso', 300, 15, 12, 30, 2, 800, 1) as id_resep_baru;
reset role;                                                 -- kembali jadi postgres untuk melihat hasilnya
select f.name, f.source, f.is_verified, n.calories, n.sodium_mg
from public.foods f join public.nutritions n on n.food_id = f.id
where f.name = 'Bakso';
rollback;


-- ---------------------------------------------------------------------
-- 2. ScanService  (lib/services/scan_service.dart)
-- ---------------------------------------------------------------------

-- 2.1 save(scan)  → langkah 4 ScanPipeline: simpan hasil pindai
-- Dart : _client.from('scan_history').insert(scan.toMap()).select('*, foods(name)').single()
-- HTTP : POST /rest/v1/scan_history?select=*,foods(name)
--          header Prefer: return=representation
-- SQL  : sekalian lihat trigger increment_scan_count bekerja
begin;
select name, scan_count from public.foods where name = 'Gado-Gado';
insert into public.scan_history (user_id, food_id, image_url, ai_confidence,
                                 fuzzy_score, fuzzy_label, scan_status)
values ((select id from public.users where role = 'pengguna' order by created_at limit 1),
        (select id from public.foods where name = 'Gado-Gado'),
        'https://contoh/foto.jpg', 87.50, 58.05, 'Cukup Sehat', 'berhasil')
returning id, scan_status, fuzzy_label;
select name, scan_count from public.foods where name = 'Gado-Gado';   -- naik 1
rollback;

-- 2.2 historyOf(userId)  → tab Riwayat
-- Dart : _client.from('scan_history').select('*, foods(name)')
--          .eq('user_id', userId).order('created_at', ascending: false)
-- HTTP : GET /rest/v1/scan_history?select=*,foods(name)&user_id=eq.<uuid>&order=created_at.desc
-- SQL  : left join karena food_id boleh null ("Makanan belum terdata")
select s.created_at, coalesce(f.name, 'Makanan belum terdata') as makanan,
       s.scan_status, s.ai_confidence, s.fuzzy_score, s.fuzzy_label
from public.scan_history s
left join public.foods f on f.id = s.food_id
where s.user_id = (select id from public.users where role = 'pengguna' order by created_at limit 1)
order by s.created_at desc;

-- 2.3 delete(id)  → hapus dari detail riwayat
-- Dart : _client.from('scan_history').delete().eq('id', id)
-- HTTP : DELETE /rest/v1/scan_history?id=eq.<uuid>
-- SQL  : delete from public.scan_history where id = '<uuid>';


-- ---------------------------------------------------------------------
-- 3. AuthService  (lib/services/auth_service.dart)
-- ---------------------------------------------------------------------

-- 3.1 isUsernameAvailable('budi')  → layar Daftar
-- Dart : _client.rpc('username_available', params: {'p_username': 'budi'})
-- HTTP : POST /rest/v1/rpc/username_available   body: {"p_username":"budi"}
-- SQL  :
select public.username_available('budi')         as budi_tersedia,
       public.username_available('nama_baru_xyz') as nama_baru_tersedia;

-- 3.2 register(...) dan login(...)
-- Ini BUKAN PostgREST, tapi Supabase Auth:
--   POST /auth/v1/signup                       (register)
--   POST /auth/v1/token?grant_type=password    (login)
-- Tidak ada padanan SQL langsung. Yang bisa kamu lihat: hasil trigger
-- handle_new_user yang membuat baris di public.users.
select u.username, u.full_name, u.role, a.email, a.created_at
from public.users u
join auth.users a on a.id = u.id
order by a.created_at desc;

-- 3.3 fetchProfile(userId)  → dipanggil AuthProvider setiap sesi berubah
-- Dart : _client.from('users').select().eq('id', userId).maybeSingle()
-- HTTP : GET /rest/v1/users?select=*&id=eq.<uuid>
-- SQL  :
select * from public.users
where id = (select id from public.users where role = 'pengguna' order by created_at limit 1);

-- 3.4 updateProfile(user)  → layar Ubah Profil
-- Dart : _client.from('users').update(user.toProfileMap()).eq('id', user.id).select().single()
-- HTTP : PATCH /rest/v1/users?id=eq.<uuid>&select=*   body: {"username":..,"full_name":..,"avatar_url":..}
-- SQL  :
begin;
update public.users set full_name = 'Nama Baru Percobaan'
 where id = (select id from public.users where role = 'pengguna' order by created_at limit 1)
returning username, full_name;
rollback;


-- ---------------------------------------------------------------------
-- 4. FavoriteService  (lib/services/favorite_service.dart)
-- ---------------------------------------------------------------------

-- 4.1 isFavorite + toggle  → tombol hati di Detail Resep
-- Dart : select('id').eq('user_id', u).eq('food_id', f).maybeSingle()
--        lalu delete() kalau sudah ada, atau insert({...}) kalau belum
-- HTTP : GET    /rest/v1/favorites?select=id&user_id=eq.<u>&food_id=eq.<f>
--        DELETE /rest/v1/favorites?user_id=eq.<u>&food_id=eq.<f>
--        POST   /rest/v1/favorites   body: {"user_id":..,"food_id":..}
-- 4.2 listOf(userId)  → layar Resep Favorit
-- Dart : select('foods(*, nutritions(*))').eq('user_id', u).order('created_at', ascending: false)
-- SQL  :
begin;
insert into public.favorites (user_id, food_id)
values ((select id from public.users where role = 'pengguna' order by created_at limit 1),
        (select id from public.foods where name = 'Soto Ayam'));
select f.name, n.calories, fav.created_at                        -- listOf
from public.favorites fav
join public.foods f on f.id = fav.food_id
left join public.nutritions n on n.food_id = f.id
where fav.user_id = (select id from public.users where role = 'pengguna' order by created_at limit 1)
order by fav.created_at desc;
rollback;


-- ---------------------------------------------------------------------
-- 5. IngredientService  (lib/services/ingredient_service.dart)
-- ---------------------------------------------------------------------

-- 5.1 list(query: 'bawang')  → tab Bahan (admin)
-- Dart : _client.from('ingredients').select().ilike('name', '%bawang%').order('name')
-- HTTP : GET /rest/v1/ingredients?select=*&name=ilike.%25bawang%25&order=name.asc
-- SQL  :
select * from public.ingredients where name ilike '%bawang%' order by name;

-- 5.2 delete(id)  [SENGAJA ERROR 23503]  → bahan yang masih dipakai resep tidak bisa dihapus
-- Dart : _client.from('ingredients').delete().eq('id', id)
-- Di aplikasi, friendlyError mengubah error ini menjadi
-- "Data ini masih dipakai di tempat lain, jadi belum bisa dihapus."
begin;
delete from public.ingredients where name = 'Telur ayam';
rollback;


-- ---------------------------------------------------------------------
-- 6. UserService  (lib/services/user_service.dart)
-- ---------------------------------------------------------------------

-- 6.1 list(query: 'bu')  → tab Akun (admin)
-- Dart : select().or('username.ilike.%bu%,full_name.ilike.%bu%').order('created_at', ascending: false)
-- HTTP : GET /rest/v1/users?select=*&or=(username.ilike.%25bu%25,full_name.ilike.%25bu%25)&order=created_at.desc
-- SQL  :
select username, full_name, role, is_active
from public.users
where username ilike '%bu%' or full_name ilike '%bu%'
order by created_at desc;

-- 6.2 updateAccess(user)  → admin mengubah peran / menonaktifkan akun
-- Dart : _client.from('users').update({'role': .., 'is_active': ..}).eq('id', user.id)
-- SQL  :
begin;
update public.users set is_active = false
 where id = (select id from public.users where role = 'pengguna' order by created_at limit 1)
returning username, is_active;
rollback;


-- ---------------------------------------------------------------------
-- 7. StatsService  (lib/services/stats_service.dart) — 4 query sekaligus
-- ---------------------------------------------------------------------
-- Dart : Future.wait([ from('scan_history').count(), from('users').count(),
--          from('scan_history').select('created_at, scan_status, fuzzy_label, ai_confidence')
--            .gte('created_at', <7 hari lalu>),
--          from('foods').select('id, name, category, scan_count')
--            .gt('scan_count', 0).order('scan_count', ascending: false).limit(5) ])
-- HTTP : count() = HEAD /rest/v1/scan_history?select=*  header Prefer: count=exact
-- SQL  :
select count(*) as total_pindai from public.scan_history;
select count(*) as total_pengguna from public.users;
select created_at, scan_status, fuzzy_label, ai_confidence
  from public.scan_history where created_at >= current_date - 6;
select id, name, category, scan_count
  from public.foods where scan_count > 0 order by scan_count desc limit 5;

-- Bonus: yang di aplikasi dihitung di Dart, bisa langsung di SQL:
select created_at::date as hari, count(*) as jumlah,
       round(avg(ai_confidence), 1) as rata_keyakinan
from public.scan_history
where created_at >= current_date - 6
group by 1 order by 1;


-- ---------------------------------------------------------------------
-- 8. MENIRU APLIKASI: jalankan query sebagai Guest / Pengguna / Admin
--    (inilah kenapa hasil SQL Editor bisa beda dengan aplikasi)
-- ---------------------------------------------------------------------

-- 8.1 Sebagai GUEST (role anon) — persis seperti aplikasi sebelum login
begin;
update public.foods set is_verified = false where name = 'Rendang';   -- (sebagai postgres) buat 1 resep belum terverifikasi
set local role anon;
select name, is_verified from public.foods order by name;   -- Rendang TIDAK muncul (RLS)
select count(*) as riwayat_terlihat from public.scan_history; -- 0: tamu tidak boleh lihat riwayat
rollback;

-- 8.2 Sebagai PENGGUNA (role authenticated + auth.uid() = id pengguna)
begin;
update public.foods set is_verified = false where name = 'Rendang';
select set_config('request.jwt.claims',
       json_build_object('sub', (select id from public.users where role = 'pengguna' order by created_at limit 1),
                         'role', 'authenticated')::text, true);
set local role authenticated;
select auth.uid() as saya;                                   -- sekarang auth.uid() terisi
select name from public.foods order by name;                 -- Rendang tetap TIDAK muncul
select username, role from public.users;                     -- hanya baris milik sendiri
rollback;

-- 8.3 Sebagai PENGGUNA [SENGAJA ERROR 42501] — mencoba menjadikan diri admin
--     Ditolak trigger protect_user_access_columns. Di aplikasi muncul
--     "Anda tidak punya izin untuk tindakan ini."
begin;
select set_config('request.jwt.claims',
       json_build_object('sub', (select id from public.users where role = 'pengguna' order by created_at limit 1),
                         'role', 'authenticated')::text, true);
set local role authenticated;
update public.users set role = 'admin' where id = auth.uid();
rollback;

-- 8.4 Sebagai PENGGUNA [SENGAJA ERROR 42501] — mencoba menambah resep langsung
--     Pengguna biasa tidak boleh insert ke foods. Karena itu
--     FoodService.createFromAi menyimpan hasil AI lewat RPC
--     create_food_from_ai (bagian 1.8), bukan insert langsung seperti ini.
begin;
select set_config('request.jwt.claims',
       json_build_object('sub', (select id from public.users where role = 'pengguna' order by created_at limit 1),
                         'role', 'authenticated')::text, true);
set local role authenticated;
insert into public.foods (name, source, is_verified) values ('Bakso', 'ai', true);
rollback;

-- 8.5 Sebagai ADMIN — melihat semua resep, termasuk yang belum terverifikasi
begin;
update public.foods set is_verified = false where name = 'Rendang';
select set_config('request.jwt.claims',
       json_build_object('sub', (select id from public.users where role = 'admin' order by created_at limit 1),
                         'role', 'authenticated')::text, true);
set local role authenticated;
select public.is_admin() as saya_admin;
select name, is_verified from public.foods order by name;    -- Rendang MUNCUL (is_admin)
select username, role from public.users;                     -- semua akun terlihat
rollback;


-- ---------------------------------------------------------------------
-- 9. StorageService — bukan PostgREST, tapi Storage API
-- ---------------------------------------------------------------------
-- Dart : _client.storage.from('scan-images').uploadBinary('<userId>/<millis>.jpg', bytes)
-- HTTP : POST /storage/v1/object/scan-images/<userId>/<millis>.jpg
-- Daftar file yang sudah terunggah tercatat di tabel storage.objects:
select bucket_id, name, created_at
from storage.objects
order by created_at desc
limit 10;
