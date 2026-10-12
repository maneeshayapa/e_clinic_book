const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';

bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

String? requiredField(String? v, [String label = 'This field']) =>
    (v == null || v.trim().isEmpty) ? '$label is required' : null;

String? validateEmail(String? v) {
  if (v == null || v.trim().isEmpty) return 'Email is required';
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()) ? null : 'Enter a valid email';
}

String? validatePassword(String? v) {
  if (v == null || v.isEmpty) return 'Password is required';
  return v.length < 6 ? 'At least 6 characters' : null;
}

String? validateNumber(String? v, String label, {bool optional = false}) {
  if (v == null || v.trim().isEmpty) return optional ? null : '$label is required';
  return double.tryParse(v.trim()) == null ? 'Enter a valid number' : null;
}
