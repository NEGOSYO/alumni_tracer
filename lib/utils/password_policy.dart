class PasswordPolicy {
  static const int minLength = 8;

  static String? validate(String value, {String fieldLabel = 'Password'}) {
    final password = value.trim();
    if (password.isEmpty) {
      return '$fieldLabel is required.';
    }
    if (password.length < minLength) {
      return '$fieldLabel must be at least $minLength characters long.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return '$fieldLabel must include at least one uppercase letter.';
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return '$fieldLabel must include at least one lowercase letter.';
    }
    if (!RegExp(r'\d').hasMatch(password)) {
      return '$fieldLabel must include at least one number.';
    }
    return null;
  }
}
