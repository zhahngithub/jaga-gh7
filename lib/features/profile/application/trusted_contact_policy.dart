const String finalTrustedContactMessage =
    'Jaga memerlukan minimal satu kontak tepercaya. Tambahkan kontak lain sebelum menghapus kontak ini.';

bool canDeleteTrustedContact(int contactCount) => contactCount > 1;
