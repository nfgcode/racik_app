-- =====================================================================
-- Racik — patch 03: gizi konsisten & foto kandidat dari hasil pindai
--
-- Untuk project Supabase yang SUDAH menjalankan schema.sql versi lama
-- (setelah patch-02). Project baru cukup menjalankan schema.sql terbaru;
-- isinya sudah sama.
-- Cara pakai: SQL Editor → tempel seluruh file ini → Run. Aman dijalankan
-- lebih dari sekali. Jalankan BERSAMAAN dengan memasang build aplikasi baru:
-- build lama tetap jalan, tetapi resep hasil AI tidak tertaut ke riwayatnya.
--
-- Isinya:
--   1. create_food_from_ai mengembalikan resep + gizi yang TERSIMPAN, bukan
--      hanya id. Pengguna kedua yang memindai makanan yang sama (resepnya
--      belum diverifikasi) melihat angka gizi yang sama dengan database.
--   2. Kolom scan_history.share_photo + fungsi share_scan_photo: izin
--      pengguna agar foto pindainya boleh dijadikan foto resep. Izin hanya
--      bisa diberikan bila resepnya belum punya foto.
--   3. Admin boleh membaca file di scan-images untuk menyalin foto kandidat
--      ke food-images.
-- =====================================================================

-- 1. Gizi konsisten -----------------------------------------------------
drop function if exists public.create_food_from_ai(text, numeric, numeric, numeric,
  numeric, numeric, numeric, numeric);
create function public.create_food_from_ai(
  p_name      text,
  p_calories  numeric,
  p_protein_g numeric default null,
  p_fat_g     numeric default null,
  p_carbs_g   numeric default null,
  p_sugar_g   numeric default null,
  p_sodium_mg numeric default null,
  p_fiber_g   numeric default null
)
returns jsonb
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

  -- Bentuknya sama dengan select '*, nutritions(*)' supaya bisa dibaca
  -- Food.fromMap. created_by sengaja tidak ikut (id pengguna lain).
  return (
    select jsonb_build_object(
      'id', f.id, 'name', f.name, 'description', f.description,
      'image_url', f.image_url, 'category', f.category,
      'serving_size', f.serving_size, 'source', f.source,
      'is_verified', f.is_verified,
      'nutritions', (select to_jsonb(n) from public.nutritions n
                     where n.food_id = f.id))
    from public.foods f where f.id = v_id);
end;
$$;
revoke execute on function public.create_food_from_ai(text, numeric, numeric, numeric,
  numeric, numeric, numeric, numeric) from public, anon;
grant execute on function public.create_food_from_ai(text, numeric, numeric, numeric,
  numeric, numeric, numeric, numeric) to authenticated;

-- 2. Izin foto pindai -------------------------------------------------
alter table public.scan_history
  add column if not exists share_photo boolean not null default false;

create or replace function public.share_scan_photo(
  p_scan_id uuid,
  p_share   boolean default true
)
returns boolean
language plpgsql security definer set search_path = ''
as $$
declare
  v_count int;
begin
  if auth.uid() is null then
    raise exception 'Harus login' using errcode = '42501';
  end if;

  update public.scan_history s
     set share_photo = p_share
   where s.id = p_scan_id
     and s.user_id = auth.uid()
     and s.image_url is not null
     and (not p_share or exists (
           select 1 from public.foods f
            where f.id = s.food_id and coalesce(f.image_url, '') = ''));

  get diagnostics v_count = row_count;
  return v_count > 0;
end;
$$;
revoke execute on function public.share_scan_photo(uuid, boolean) from public, anon;
grant execute on function public.share_scan_photo(uuid, boolean) to authenticated;

-- 3. Admin menyalin foto kandidat ---------------------------------------
drop policy if exists "storage: admin baca foto pindai" on storage.objects;
create policy "storage: admin baca foto pindai" on storage.objects
  for select to authenticated
  using (bucket_id = 'scan-images' and public.is_admin());

-- Cek: ketiga kolom harus true.
select
  (select data_type from information_schema.columns
    where table_schema = 'public' and table_name = 'scan_history'
      and column_name = 'share_photo') = 'boolean'                  as kolom_share_photo,
  (select pg_get_function_result(p.oid) from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'create_food_from_ai') = 'jsonb'
                                                                    as rpc_kembalikan_jsonb,
  exists (select 1 from pg_policies where schemaname = 'storage'
           and policyname = 'storage: admin baca foto pindai')   as policy_admin_baca;
