import '../data/models/pin_rules.dart';

String? validatePin(String? value) {
  if (value == null || !isFourDigitPin(value)) {
    return 'PIN harus terdiri dari 4 angka.';
  }
  if (isWeakPin(value)) {
    return 'Gunakan PIN yang tidak mudah ditebak.';
  }
  return null;
}

String? validatePinForVerification(String? value) {
  if (value == null || !isFourDigitPin(value)) {
    return 'PIN harus terdiri dari 4 angka.';
  }
  return null;
}

String? validatePinConfirmation({
  required String pin,
  required String confirmation,
}) {
  if (!isFourDigitPin(confirmation)) {
    return 'PIN harus terdiri dari 4 angka.';
  }
  if (confirmation != pin) {
    return 'Konfirmasi PIN tidak sesuai.';
  }
  return null;
}
