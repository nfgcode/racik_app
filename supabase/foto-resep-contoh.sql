-- =====================================================================
-- Racik — foto untuk 6 resep contoh dari seed.sql
--
-- Foto disimpan di Storage (bucket food-images), BUKAN di database.
-- Tabel foods hanya menyimpan URL-nya di kolom image_url.
--
-- Cara pakai:
--   1. Dashboard Supabase → Storage → food-images → Create folder "resep".
--   2. Buka folder resep → Upload → pilih semua file di supabase/gambar-resep/
--      (nama file jangan diubah).
--   3. SQL Editor → tempel file ini → ganti nilai `base` di bawah dengan
--      SUPABASE_URL dari env.json → Run.
--
-- Aman dijalankan berkali-kali. Yang diisi hanya resep yang:
--   - fotonya sudah ada di food-images/resep/, dan
--   - image_url-nya masih kosong (foto yang diunggah admin tidak ditimpa).
-- Kredit dan lisensi foto: supabase/gambar-resep/KREDIT.md
-- =====================================================================

do $$
declare
  base text := 'https://GANTI-DENGAN-PROJECT-ANDA.supabase.co';  -- SUPABASE_URL
  n int;
begin
  if base like '%GANTI-DENGAN%' then
    raise exception 'Ganti dulu nilai base dengan SUPABASE_URL dari env.json.';
  end if;

  update public.foods f
     set image_url = rtrim(base, '/') || '/storage/v1/object/public/food-images/resep/' || v.file
    from (values
      ('Nasi Goreng',        'nasi-goreng.jpg'),
      ('Gado-Gado',          'gado-gado.jpg'),
      ('Soto Ayam',          'soto-ayam.jpg'),
      ('Rendang',            'rendang.jpg'),
      ('Pisang Goreng',      'pisang-goreng.jpg'),
      ('Sayur Bening Bayam', 'sayur-bening-bayam.jpg')
    ) as v(name, file)
   where lower(f.name) = lower(v.name)
     and coalesce(f.image_url, '') = ''
     and exists (select 1 from storage.objects o
                 where o.bucket_id = 'food-images' and o.name = 'resep/' || v.file);

  get diagnostics n = row_count;
  raise notice '% resep diberi foto.', n;
end $$;

-- Cek hasil: kolom ada_foto harus true untuk resep yang fotonya sudah diunggah.
select name, image_url is not null as ada_foto, image_url
  from public.foods
 order by name;
