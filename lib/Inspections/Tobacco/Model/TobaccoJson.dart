/// Small, forgiving JSON readers for the Tobacco APIs.
///
/// The API sends "" for empty values and mixes int / String for ids
/// (e.g. "sub_section_id": "" or 1, "parent_id": "" or 47).
library;

int? tbInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is bool) return v ? 1 : 0;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return int.tryParse(s) ?? double.tryParse(s)?.toInt();
}

/// Trimmed string, or null when empty.
String? tbStr(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

/// "2026-07-23" for a DateTime.
String tbDateOnly(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

const tbMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "2026-07-23" / "2026-07-23T10:00:00Z" → "Jul 23, 2026"
String tbFormatDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '';
  final d = DateTime.tryParse(raw);
  if (d == null) return raw;
  return '${tbMonths[d.month - 1]} ${d.day.toString().padLeft(2, '0')}, ${d.year}';
}

/// "2026-07-23" → "07-23-2026" (same as the web form).
String tbFormatDateUs(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '';
  final d = DateTime.tryParse(raw);
  if (d == null) return raw;
  return '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}-${d.year}';
}
