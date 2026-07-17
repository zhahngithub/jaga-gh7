import '../data/models/pin_models.dart';

enum PinOperation { setup, verification, status }

String mapPinFailure(
  PinFailure failure, {
  required PinOperation operation,
  DateTime Function()? now,
}) {
  switch (failure.code) {
    case PinErrorCode.noAuthenticatedUid:
      return 'Sesi kamu telah berakhir. Silakan masuk kembali.';
    case PinErrorCode.pinNotConfigured:
      return 'PIN belum dikonfigurasi di perangkat ini.';
    case PinErrorCode.invalidPin:
      return 'PIN harus terdiri dari 4 angka.';
    case PinErrorCode.weakPin:
      return 'Gunakan PIN yang tidak mudah ditebak.';
    case PinErrorCode.incorrectPin:
      return 'PIN yang kamu masukkan salah.';
    case PinErrorCode.temporaryLockout:
      final lockoutUntil = failure.lockoutUntil;
      if (lockoutUntil == null) {
        return 'Terlalu banyak percobaan. Coba lagi dalam beberapa saat.';
      }
      final remaining = lockoutUntil.difference((now ?? DateTime.now)());
      final seconds = (remaining.inMilliseconds / 1000).ceil();
      if (seconds <= 0) {
        return 'Kamu dapat mencoba PIN kembali.';
      }
      return 'Terlalu banyak percobaan. Coba lagi dalam $seconds detik.';
    case PinErrorCode.storageReadFailure:
    case PinErrorCode.storageWriteFailure:
      return 'Penyimpanan aman perangkat tidak tersedia.';
    case PinErrorCode.alreadyConfigured:
      return 'PIN sudah tersimpan di perangkat ini.';
    case PinErrorCode.cryptographyFailure:
    case PinErrorCode.unknown:
      return switch (operation) {
        PinOperation.setup => 'PIN belum dapat disimpan. Coba lagi.',
        PinOperation.verification => 'PIN belum dapat diverifikasi. Coba lagi.',
        PinOperation.status =>
          'Status PIN perangkat belum dapat diperiksa. Coba lagi.',
      };
  }
}
