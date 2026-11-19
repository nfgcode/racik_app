-- =====================================================================
-- Racik — patch 02: RLS tabel anak resep & scan_count yang akurat
--
-- Untuk project Supabase yang SUDAH menjalankan schema.sql versi lama
-- (setelah patch-01-perbaikan-bug.sql). Project baru cukup menjalankan
-- schema.sql terbaru; isinya sudah sama.
-- Cara pakai: SQL Editor → tempel seluruh file ini → Run. Aman dijalankan
-- lebih dari sekali.
--
-- Yang diperbaiki:
--   1. Nutrisi, langkah, dan bahan resep yang belum diverifikasi bisa dibaca
--      siapa pun lewat API (kebijakan baca memakai using (true)).
--   2. foods.scan_count hanya naik dan tidak pernah turun saat riwayat pindai
--      dihapus, sehingga statistik "paling sering dipindai" meleset.
-- =====================================================================

-- 1. Tabel anak resep hanya terbaca bila resepnya terbaca.
do $$
declare t text;
begin
  foreach t in array array['nutritions', 'steps', 'food_ingredients'] loop
    execute format('drop policy if exists "%1$s: semua boleh baca" on public.%1$I', t);
    execute format('drop policy if exists "%1$s: baca bila resep terlihat" on public.%1$I', t);
    execute format(
      'create policy "%1$s: baca bila resep terlihat" on public.%1$I
         for select to anon, authenticated
         using (exists (select 1 from public.foods f
                        where f.id = food_id and (f.is_verified or public.is_admin())))', t);
  end loop;
end $$;

-- 2. scan_count turun lagi saat riwayat dihapus.
create or replace function public.decrement_scan_count()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if old.food_id is not null then
    update public.foods
       set scan_count = greatest(coalesce(scan_count, 0) - 1, 0)
     where id = old.food_id;
  end if;
  return old;
end;
$$;

drop trigger if exists scan_history_decrement_count on public.scan_history;
create trigger scan_history_decrement_count
  after delete on public.scan_history
  for each row execute function public.decrement_scan_count();

-- Samakan scan_count dengan isi scan_history sekarang (data turunan, aman
-- dihitung ulang).
update public.foods f
   set scan_count = (select count(*) from public.scan_history s where s.food_id = f.id)
 where scan_count is distinct from (select count(*) from public.scan_history s where s.food_id = f.id);
