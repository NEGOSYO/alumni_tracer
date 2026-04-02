class EmailValidator {
  static final RegExp _pattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? validate(String value) {
    final email = value.trim();
    if (email.isEmpty) {
      return 'Email is required.';
    }
    if (!_pattern.hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }
}
