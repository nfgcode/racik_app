-- =====================================================================
-- Racik — fitur HAPUS AKUN (wajib untuk Google Play bila ada fitur daftar akun)
--
-- Jalankan sekali di Supabase → SQL Editor. Aman dijalankan ulang.
-- Sudah termasuk juga di bagian akhir schema.sql untuk proyek baru.
-- =====================================================================

-- Pengguna perlu bisa melihat isi foldernya sendiri di Storage supaya
-- aplikasi dapat menghapus semua foto miliknya sebelum akun dihapus.
drop policy if exists "storage: lihat file sendiri" on storage.objects;
create policy "storage: lihat file sendiri" on storage.objects
  for select to authenticated
  using (
    bucket_id in ('scan-images', 'avatars')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Menghapus akun yang sedang login. Baris di public.users, scan_history,
-- dan favorites ikut terhapus lewat ON DELETE CASCADE.
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if auth.uid() is null then
    raise exception 'Harus masuk untuk menghapus akun';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
