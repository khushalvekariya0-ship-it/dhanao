/// Small formatting helpers (no intl dependency).
class Fmt {
  Fmt._();

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  /// $4,850 or $4,850.50
  static String money(num v, {bool cents = false, String symbol = r'$'}) {
    final neg = v < 0;
    final fixed = v.abs().toStringAsFixed(cents ? 2 : 0);
    final parts = fixed.split('.');
    final whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    final out = cents ? '$whole.${parts[1]}' : whole;
    return '${neg ? '-' : ''}$symbol$out';
  }

  /// 1,240.5 g
  static String grams(num v, {int digits = 1}) {
    final fixed = v.toStringAsFixed(digits);
    final parts = fixed.split('.');
    final whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    return digits == 0 ? '$whole g' : '$whole.${parts[1]} g';
  }

  /// Aug 24
  static String date(DateTime d) => '${_months[d.month - 1]} ${d.day}';

  /// Aug 24, 2026
  static String dateLong(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

  /// 09:15 AM
  static String time(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '${h.toString().padLeft(2, '0')}:$m ${d.hour < 12 ? 'AM' : 'PM'}';
  }

  /// Oct 14, 09:15
  static String dateTime(DateTime d) =>
      '${date(d)}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// "Today, 10:42 AM" / "Yesterday" / "Aug 12, 05:00 PM"
  static String relativeDay(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'Today, ${time(d)}';
    if (diff == -1) return 'Yesterday, ${time(d)}';
    if (diff == 1) return 'Tomorrow, ${time(d)}';
    return '${date(d)}, ${time(d)}';
  }

  /// "10 mins ago", "2 hrs ago", "3 days ago"
  static String ago(DateTime d) {
    final s = DateTime.now().difference(d);
    if (s.inMinutes < 1) return 'just now';
    if (s.inMinutes < 60) return '${s.inMinutes} min${s.inMinutes == 1 ? '' : 's'} ago';
    if (s.inHours < 24) return '${s.inHours} hr${s.inHours == 1 ? '' : 's'} ago';
    return '${s.inDays} day${s.inDays == 1 ? '' : 's'} ago';
  }

  /// "DUE TODAY", "DUE TMRW", "DUE IN 5D", "OVERDUE 2D"
  static String dueTag(int daysUntilDue) {
    if (daysUntilDue < 0) return 'OVERDUE ${-daysUntilDue}D';
    if (daysUntilDue == 0) return 'DUE TODAY';
    if (daysUntilDue == 1) return 'DUE TMRW';
    return 'DUE IN ${daysUntilDue}D';
  }

  /// 00:45
  static String duration(Duration d) =>
      '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
}
