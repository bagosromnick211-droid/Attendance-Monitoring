// Shared formatting helpers.
// Mask an email for the sidebar.
String maskEmailAddress(String email) {
  final parts = email.trim().split('@');
  if (parts.length != 2 || parts.first.isEmpty || parts.last.isEmpty) {
    return '****';
  }
  // Keep at most the first three characters of the local part.
  final visibleLength = parts.first.length < 3 ? parts.first.length : 3;
  return '${parts.first.substring(0, visibleLength)}****@${parts.last}';
}
