abstract final class InputValidators {
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _phonePattern = RegExp(r'^\+?[0-9]{8,15}$');

  static String? requiredText(
    String? value, {
    required String fieldName,
    int? maxLength,
  }) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return '$fieldName je obavezno.';
    }
    if (maxLength != null && trimmed.length > maxLength) {
      return '$fieldName moze sadrzavati maksimalno $maxLength karaktera.';
    }
    return null;
  }

  static String? email(String? value, {bool required = true}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return required ? 'Email adresa je obavezna.' : null;
    }
    if (!_emailPattern.hasMatch(trimmed)) {
      return 'Email adresa mora biti u formatu korisnik@domena.com.';
    }
    return null;
  }

  static String? phone(String? value, {bool required = false}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return required ? 'Broj telefona je obavezan.' : null;
    }
    if (!_phonePattern.hasMatch(trimmed)) {
      return 'Broj telefona mora imati 8 do 15 cifara i smije imati samo + na pocetku, npr. +38761123456.';
    }
    return null;
  }
}
