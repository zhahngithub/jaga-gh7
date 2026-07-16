String mapFirebaseAuthError(String? code) {
  switch (code) {
    case 'invalid-email':
      return 'Format email tidak valid.';
    case 'email-already-in-use':
      return 'Email ini sudah digunakan. Silakan masuk atau gunakan email lain.';
    case 'weak-password':
      return 'Kata sandi terlalu lemah. Gunakan minimal 8 karakter.';
    case 'user-disabled':
      return 'Akun ini dinonaktifkan. Hubungi dukungan Jaga.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'Email atau kata sandi tidak sesuai.';
    case 'network-request-failed':
      return 'Koneksi internet bermasalah. Periksa jaringan lalu coba lagi.';
    case 'too-many-requests':
      return 'Terlalu banyak percobaan. Tunggu sebentar lalu coba lagi.';
    case 'operation-not-allowed':
      return 'Metode autentikasi ini belum tersedia.';
    default:
      return 'Terjadi kendala saat memproses permintaan. Silakan coba lagi.';
  }
}
