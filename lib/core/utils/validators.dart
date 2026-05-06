class Validators {
  const Validators._();

  static String? required(String? value, {String label = 'Field'}) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    return null;
  }

  static String? email(String? value) {
    final base = required(value, label: 'Email');
    if (base != null) return base;
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value!.trim());
    return ok ? null : 'Enter a valid email';
  }

  static String? password(String? value) {
    final base = required(value, label: 'Password');
    if (base != null) return base;
    return value!.length >= 6 ? null : 'Use at least 6 characters';
  }

  static String? phone(String? value) {
    final base = required(value, label: 'Phone');
    if (base != null) return base;
    final compact = value!.replaceAll(RegExp(r'[\s\-.]'), '');
    final ok = RegExp(r'^(?:0|\+213|00213)[567]\d{8}$').hasMatch(compact);
    return ok ? null : 'Enter a valid Algerian mobile number';
  }
}
