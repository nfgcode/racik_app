-- =====================================================================
-- Racik — patch 01: perbaikan bug penyimpanan hasil AI & hak akses procedure
--
-- Untuk project Supabase yang SUDAH menjalankan schema.sql versi lama.
-- (Project baru cukup menjalankan schema.sql terbaru; isinya sudah sama.)
-- Cara pakai: SQL Editor → tempel seluruh file ini → Run. Aman dijalankan
-- lebih dari sekali.
--
-- Yang diperbaiki:
--   1. Pengguna biasa tidak bisa menyimpan resep hasil AI (ditolak RLS), dan
--      hasil AI dari admin langsung tampil publik tanpa ditinjau.
--      → fungsi create_food_from_ai: resep disimpan sebagai belum terverifikasi.
--   2. Resep hasil AI bisa tersimpan tanpa nutrisi (dua request terpisah).
--      → resep + nutrisi disimpan dalam satu transaksi.
--   3. sp_verify_food / sp_clear_user_history (SECURITY DEFINER) bisa dipanggil
--      pengguna mana pun. → hak eksekusi dicabut dari anon/authenticated.
-- =====================================================================

-- Simpan makanan hasil pindai AI yang belum ada di foods (dipanggil
-- FoodService.createFromAi lewat RPC). Pengguna biasa tidak boleh menulis ke
-- foods, jadi fungsi ini SECURITY DEFINER, tetapi dibatasi ketat:
--   - wajib login, dan resep selalu is_verified = false sehingga baru tampil
--     ke publik setelah ditinjau admin;
--   - resep + nutrisi disimpan dalam SATU transaksi: bila nutrisi gagal,
--     resepnya ikut batal (tidak ada resep tanpa nutrisi);
--   - nama yang sudah ada (tanpa beda huruf besar/kecil) tidak dibuat ulang;
--     id resep lama yang dikembalikan.
create or replace function public.create_food_from_ai(
  p_name      text,
  p_calories  numeric,
  p_protein_g numeric default null,
  p_fat_g     numeric default null,
  p_carbs_g   numeric default null,
  p_sugar_g   numeric default null,
  p_sodium_mg numeric default null,
  p_fiber_g   numeric default null
)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  v_name text := btrim(p_name);
  v_id   uuid;
begin
  if auth.uid() is null then
    raise exception 'Harus login untuk menyimpan hasil pindai' using errcode = '42501';
  end if;
  if v_name is null or v_name = '' then
    raise exception 'Nama makanan kosong' using errcode = '22023';
  end if;

  insert into public.foods (name, description, category, serving_size,
                            source, is_verified, created_by)
  values (v_name, 'Resep makanan teridentifikasi secara otomatis oleh AI.',
          'Hasil Pindai AI', '1 porsi', 'ai', false, auth.uid())
  on conflict ((lower(name))) do nothing
  returning id into v_id;

  if v_id is null then
    select id into v_id from public.foods where lower(name) = lower(v_name);
  end if;

  insert into public.nutritions (food_id, calories, protein_g, fat_g, carbs_g,
                                 sugar_g, sodium_mg, fiber_g)
  values (v_id, p_calories, p_protein_g, p_fat_g, p_carbs_g,
          p_sugar_g, p_sodium_mg, p_fiber_g)
  on conflict (food_id) do nothing;

  return v_id;
end;
$$;
revoke execute on function public.create_food_from_ai(text, numeric, numeric, numeric,
  numeric, numeric, numeric, numeric) from public, anon;
grant execute on function public.create_food_from_ai(text, numeric, numeric, numeric,
  numeric, numeric, numeric, numeric) to authenticated;

-- Stored procedure (materi Database Programmer). Keduanya SECURITY DEFINER,
-- artinya melewati RLS, jadi TIDAK boleh bisa dipanggil anon/authenticated:
-- siapa pun yang login bisa menghapus riwayat orang lain atau memverifikasi
-- resep. Jalankan hanya dari SQL Editor / server (role postgres).
-- Aplikasi tidak memakainya; verifikasi dari aplikasi lewat FoodService.setVerified.

-- Stored procedure verifikasi resep
create or replace procedure public.sp_verify_food(
  p_food_id uuid,
  p_admin_id uuid
)
language plpgsql security definer set search_path = ''
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
language plpgsql security definer set search_path = ''
as $$
begin
  delete from public.scan_history
   where user_id = p_user_id;
end;
$$;

revoke execute on procedure public.sp_verify_food(uuid, uuid) from public, anon, authenticated;
revoke execute on procedure public.sp_clear_user_history(uuid) from public, anon, authenticated;


-- ---------------------------------------------------------------------
-- Opsional: cek resep hasil AI yang terlanjur tersimpan TANPA nutrisi oleh
-- versi lama. Query ini hanya MENAMPILKAN; putuskan sendiri apakah resepnya
-- dilengkapi lewat menu admin atau dihapus.
-- ---------------------------------------------------------------------
select f.id, f.name, f.is_verified, f.created_at
from public.foods f
left join public.nutritions n on n.food_id = f.id
where f.source = 'ai' and n.id is null
order by f.created_at;
