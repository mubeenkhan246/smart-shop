String? validateStrongPassword(String password) {
  if (password.length < 8) return 'Password must be at least 8 characters.';
  if (!RegExp(r'[A-Za-z]').hasMatch(password)) {
    return 'Password must include at least one alphabet.';
  }
  if (!RegExp(r'\d').hasMatch(password)) {
    return 'Password must include at least one number.';
  }
  if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
    return 'Password must include at least one special character.';
  }
  return null;
}
