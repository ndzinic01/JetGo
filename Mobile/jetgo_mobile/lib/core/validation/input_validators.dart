abstract final class InputValidators {
  static final RegExp _emailPattern = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );
  static final RegExp _phonePattern = RegExp(r'^\+?[0-9]{8,15}$');
  static final RegExp _personNamePattern = RegExp(
    r'^[A-Za-zČĆŽŠĐčćžšđ]+(?: [A-Za-zČĆŽŠĐčćžšđ]+)*$',
  );
  static final RegExp _bosniaLocalPhonePattern = RegExp(r'^[1-9][0-9]{7,8}$');
  static final RegExp _usernamePattern = RegExp(r'^[A-Za-z0-9._-]+$');

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
    if (trimmed.length > 200) {
      return 'Email adresa moze sadrzavati maksimalno 200 karaktera.';
    }
    if (!_emailPattern.hasMatch(trimmed)) {
      return 'Email adresa mora biti u formatu korisnik@domena.com.';
    }
    return null;
  }

  static String? personName(String? value, {required String fieldName}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return '$fieldName je obavezno.';
    }
    if (trimmed.length > 100) {
      return '$fieldName moze sadrzavati maksimalno 100 karaktera.';
    }
    if (!_personNamePattern.hasMatch(trimmed)) {
      return '$fieldName smije sadrzavati samo slova i razmake.';
    }
    return null;
  }

  static String? phone(String? value, {bool required = false}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return required ? 'Broj telefona je obavezan.' : null;
    }
    if (trimmed.length > 30) {
      return 'Broj telefona moze sadrzavati maksimalno 30 karaktera.';
    }
    if (!_phonePattern.hasMatch(trimmed)) {
      return 'Broj telefona mora imati 8 do 15 cifara i smije imati samo + na pocetku, npr. +38761123456.';
    }
    return null;
  }

  static String? bosniaLocalPhone(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Telefon je obavezno polje.';
    }
    if (!_bosniaLocalPhonePattern.hasMatch(trimmed)) {
      return 'Telefon unesite bez pocetne nule, sa 8 ili 9 cifara nakon +387.';
    }
    return null;
  }

  static String? username(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Korisnicko ime je obavezno.';
    }
    if (trimmed.length < 3) {
      return 'Korisnicko ime mora imati najmanje 3 karaktera.';
    }
    if (trimmed.length > 50) {
      return 'Korisnicko ime moze sadrzavati maksimalno 50 karaktera.';
    }
    if (!_usernamePattern.hasMatch(trimmed)) {
      return 'Korisnicko ime smije sadrzavati slova, brojeve, tacku, donju crtu i crticu.';
    }
    return null;
  }

  static String? password(
    String? value, {
    String fieldName = 'Lozinka',
    int minLength = 4,
  }) {
    if (value == null || value.isEmpty) {
      return '$fieldName je obavezna.';
    }
    if (value.length < minLength) {
      return '$fieldName mora imati najmanje $minLength karaktera.';
    }
    return null;
  }
}
