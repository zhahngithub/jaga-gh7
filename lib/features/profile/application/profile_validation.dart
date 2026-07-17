import '../../auth/application/auth_validators.dart';

String? validateProfileDisplayName(String? value) => validateDisplayName(value);

String? validateProfilePhone(String? value) => validateIndonesianPhone(value);

String? normalizeProfilePhone(String value) => normalizeIndonesianPhone(value);

String? validateTrustedContactName(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Nama kontak wajib diisi.';
  }
  return null;
}
