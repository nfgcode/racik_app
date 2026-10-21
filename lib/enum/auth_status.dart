/// Aktor pada diagram use case + satu status sebelum sesi login terbaca.
enum AuthStatus {
  unknown, // sesi tersimpan di HP belum selesai dibaca
  guest, // belum login
  signedIn, // sudah login → aktor Pengguna
}
