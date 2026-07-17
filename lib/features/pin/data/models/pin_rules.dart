const weakPins = <String>{
  '0000',
  '1111',
  '2222',
  '3333',
  '4444',
  '5555',
  '6666',
  '7777',
  '8888',
  '9999',
  '1234',
  '4321',
};

final RegExp _fourDigitPinPattern = RegExp(r'^\d{4}$');

bool isFourDigitPin(String value) => _fourDigitPinPattern.hasMatch(value);

bool isWeakPin(String value) => weakPins.contains(value);
