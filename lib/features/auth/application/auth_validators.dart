final RegExp _emailPattern = RegExp(
  r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$",
);
final RegExp _normalizedPhonePattern = RegExp(r'^\+628[1-9][0-9]{7,10}$');

String normalizeEmail(String value) => value.trim().toLowerCase();

String? validateDisplayName(String? value) {
  final displayName = value?.trim() ?? '';
  if (displayName.isEmpty) {
    return 'Nama panggilan wajib diisi.';
  }
  if (displayName.length < 2 || displayName.length > 40) {
    return 'Nama panggilan harus terdiri dari 2–40 karakter.';
  }
  return null;
}

String? validateEmail(String? value) {
  final email = normalizeEmail(value ?? '');
  if (email.isEmpty) {
    return 'Email wajib diisi.';
  }
  if (!_emailPattern.hasMatch(email)) {
    return 'Format email tidak valid.';
  }
  return null;
}

String? validatePassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Kata sandi wajib diisi.';
  }
  if (value.length < 8) {
    return 'Kata sandi minimal 8 karakter.';
  }
  return null;
}

String? validatePasswordConfirmation({
  required String? password,
  required String? confirmation,
}) {
  if (confirmation == null || confirmation.isEmpty) {
    return 'Konfirmasi kata sandi wajib diisi.';
  }
  if (confirmation != password) {
    return 'Konfirmasi kata sandi tidak sesuai.';
  }
  return null;
}

String? normalizeIndonesianPhone(String value) {
  final compact = value.trim().replaceAll(RegExp(r'[\s()\-]'), '');
  late final String subscriberNumber;

  if (compact.startsWith('+62')) {
    subscriberNumber = compact.substring(3);
  } else if (compact.startsWith('62')) {
    subscriberNumber = compact.substring(2);
  } else if (compact.startsWith('0')) {
    subscriberNumber = compact.substring(1);
  } else {
    return null;
  }

  final normalized = '+62$subscriberNumber';
  return _normalizedPhonePattern.hasMatch(normalized) ? normalized : null;
}

String? validateIndonesianPhone(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Nomor telepon wajib diisi.';
  }
  if (normalizeIndonesianPhone(value) == null) {
    return 'Masukkan nomor ponsel Indonesia yang valid.';
  }
  return null;
}
