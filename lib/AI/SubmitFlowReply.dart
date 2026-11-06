// lib/Dashboard/Voice/VoiceSubmitFlow.dart
//
// AI Guide conversation: "submit my inspection"
//
//   User: "Submit my inspection"
//   AI:   "Which inspection do you want to submit? Mobile Food?"
//   User: "Mobile Food"
//   AI:   "Which business?"
//   User: "Mobile Test 200"
//   (one incomplete inspection)  → submits it
//   (more than one)              → "Mobile Test 200 has 2 incomplete
//                                   inspections: 1, October 13 at 10:46 AM;
//                                   2, October 20 at 12:20 PM.
//                                   Which date and time?"
//   User: "October 20 at 12:20"  (or "the second one")
//   AI:   "Submitting Mobile Test 200 from October 20 at 12:20 PM."
//         → returns the inspection id; the Dashboard opens it and
//           FoodMobileDetailsScreen(autoSubmit: true) sends it to the server.
//
// Steps are skipped when the user already said them:
//   "submit mobile food Mobile Test 200 October 13 at 10:46 AM"
//
// Incomplete inspections are read from the MobileFoodInspection table.

import 'package:flutter/foundation.dart';
import 'package:quincy/Database/DBManager.dart';

// ---------------------------------------------------------------------------
// Result
// ---------------------------------------------------------------------------

class SubmitFlowReply {
  /// What the AI says.
  final String text;

  /// Keep the microphone open for the answer.
  final bool keepListening;

  /// Set when the inspection is chosen → the Dashboard submits this one.
  final String? inspectionId;

  const SubmitFlowReply(
    this.text, {
    this.keepListening = true,
    this.inspectionId,
  });
}

// ---------------------------------------------------------------------------
// One incomplete inspection (row of MobileFoodInspection)
// ---------------------------------------------------------------------------

class IncompleteInspectionRef {
  final String inspectionId;
  final String businessName;
  final String permitNumber;
  final DateTime? date;
  final int? hourIn;
  final int? minuteIn;
  final int? hourOut;
  final int? minuteOut;

  const IncompleteInspectionRef({
    required this.inspectionId,
    required this.businessName,
    required this.permitNumber,
    this.date,
    this.hourIn,
    this.minuteIn,
    this.hourOut,
    this.minuteOut,
  });

  factory IncompleteInspectionRef.fromRow(Map<String, Object?> r) {
    (int?, int?) hm(Object? v) {
      final parts = (v?.toString() ?? '').split(':');
      if (parts.length < 2) return (null, null);
      return (int.tryParse(parts[0]), int.tryParse(parts[1]));
    }

    final (hi, mi) = hm(r['time_in']);
    final (ho, mo) = hm(r['time_out']);
    return IncompleteInspectionRef(
      inspectionId: r['inspection_id'].toString(),
      businessName: r['business_name']?.toString() ?? '',
      permitNumber: r['permit_number']?.toString() ?? '',
      date: DateTime.tryParse(r['inspection_date']?.toString() ?? ''),
      hourIn: hi,
      minuteIn: mi,
      hourOut: ho,
      minuteOut: mo,
    );
  }

  /// "October 13"
  String get spokenDate =>
      date == null ? 'no date' : '${_kMonths[date!.month - 1]} ${date!.day}';

  /// "10:46 AM"
  String get spokenTime {
    if (hourIn == null || minuteIn == null) return '';
    final h12 = hourIn! % 12 == 0 ? 12 : hourIn! % 12;
    final ap = hourIn! < 12 ? 'AM' : 'PM';
    return '$h12:${minuteIn!.toString().padLeft(2, '0')} $ap';
  }

  /// "October 13 at 10:46 AM"
  String get spokenWhen =>
      spokenTime.isEmpty ? spokenDate : '$spokenDate at $spokenTime';
}

// ---------------------------------------------------------------------------
// Conversation
// ---------------------------------------------------------------------------

const _kMonths = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July',
  'August', 'September', 'October', 'November', 'December',
];

const _kMonthShort = [
  'jan', 'feb', 'mar', 'apr', 'may', 'jun',
  'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
];

enum _Stage { idle, askType, askBusiness, askWhich }

class VoiceSubmitFlow {
  VoiceSubmitFlow({required this.userId});

  /// Logged-in user (only their inspections are offered).
  final int? Function() userId;

  _Stage _stage = _Stage.idle;
  List<IncompleteInspectionRef> _all = [];
  List<IncompleteInspectionRef> _choices = [];

  /// True while the AI is waiting for an answer of this conversation.
  bool get isActive => _stage != _Stage.idle;

  void reset() {
    _stage = _Stage.idle;
    _all = [];
    _choices = [];
  }

  // ---- Phrases ----
  static final _submitIntent =
      RegExp(r'\b(submit|upload|send in|send off)\b');
  static final _cancel = RegExp(
      r'\b(cancel|never ?mind|forget it|stop|no thanks|not now)\b');
  static final _otherCommand =
      RegExp(r'\b(open|logout|log out|help|close|show)\b');
  static final _mobileFood = RegExp(r'\bmobile\b|\bfood truck');
  static final _otherType = RegExp(
      r'\b(restaurant|tobacco|nursing|pool|complaint|temporary|retail|'
      r'food inspection|food establishment)\b');
  static final _yes =
      RegExp(r'\b(yes|yeah|yep|sure|ok|okay|correct|right|that one)\b');

  /// Words that are never part of a business name.
  static const _stop = {
    'submit', 'upload', 'send', 'in', 'off', 'my', 'the', 'a', 'an',
    'inspection', 'inspections', 'for', 'of', 'please', 'mobile', 'food',
    'truck', 'business', 'name', 'is', 'it', 'on', 'at', 'to', 'and',
    'called', 'incomplete', 'yes', 'okay', 'ok', 'that', 'this', 'from',
    'am', 'pm', 'today', 'yesterday', 'number', 'option', 'first', 'second',
    'third', 'fourth', 'fifth', 'last', 'latest', 'oldest', 'can', 'you',
    'i', 'want', 'would', 'like', 'one', 'with', 'date', 'time', 'hey',
    'quincy', 'now', 'just', 'go', 'ahead', 'which', 'st', 'nd', 'rd', 'th',
  };

  // ---------------- Entry point ----------------

  /// Returns a reply when this conversation handles [raw],
  /// or null to let the other voice commands handle it.
  Future<SubmitFlowReply?> handle(String raw) async {
    final t = _norm(raw);
    if (t.isEmpty) return null;

    // ---- Start: "submit my inspection" ----
    if (!isActive) {
      if (!_submitIntent.hasMatch(t)) return null;
      try {
        _all = await _loadIncomplete();
      } catch (e) {
        debugPrint('❌ Voice submit: load incomplete error: $e');
        reset();
        return const SubmitFlowReply(
          "Sorry, I couldn't read your saved inspections.",
          keepListening: false,
        );
      }
      if (_all.isEmpty) {
        reset();
        return const SubmitFlowReply(
          "You don't have any incomplete inspections to submit.",
          keepListening: false,
        );
      }
      return _onType(t, firstTurn: true);
    }

    // ---- In the middle of the conversation ----
    if (_cancel.hasMatch(t)) {
      reset();
      return const SubmitFlowReply('Okay, I cancelled the submission.');
    }
    // A different command ("open incomplete", "logout") ends this flow
    if (_otherCommand.hasMatch(t) && !_submitIntent.hasMatch(t)) {
      reset();
      return null;
    }

    switch (_stage) {
      case _Stage.askType:
        return _onType(t, firstTurn: false);
      case _Stage.askBusiness:
        return _onBusiness(t);
      case _Stage.askWhich:
        return _onWhich(t);
      case _Stage.idle:
        return null;
    }
  }

  // ---------------- Step 1: inspection type ----------------

  SubmitFlowReply _onType(String t, {required bool firstTurn}) {
    var mobile = _mobileFood.hasMatch(t);

    if (!mobile && _otherType.hasMatch(t)) {
      _stage = _Stage.askType;
      return const SubmitFlowReply(
        'Right now I can only submit Mobile Food inspections. '
        'Say Mobile Food, or say cancel.',
      );
    }

    if (!mobile) {
      // "submit Rolling Bites" → business already said, type is implied
      if (firstTurn) {
        final names = _matchNames(t);
        if (names != null && names.isNotEmpty) return _onBusiness(t);
      }
      if (!firstTurn && _yes.hasMatch(t)) mobile = true;
    }

    if (!mobile) {
      _stage = _Stage.askType;
      return const SubmitFlowReply(
        'Which inspection do you want to submit? Mobile Food?',
      );
    }

    // Mobile Food chosen → business (maybe already in the same sentence)
    _stage = _Stage.askBusiness;
    final names = _matchNames(t);
    if (names == null) {
      return SubmitFlowReply(
        'Mobile Food. Which business? '
        'You have incomplete inspections for ${_businessList()}.',
      );
    }
    return _onBusiness(t);
  }

  // ---------------- Step 2: business name ----------------

  SubmitFlowReply _onBusiness(String t) {
    _stage = _Stage.askBusiness;
    final names = _matchNames(t);

    if (names == null) {
      return SubmitFlowReply(
          'Which business? You have ${_businessList()}.');
    }
    if (names.isEmpty) {
      return SubmitFlowReply(
        "I couldn't find an incomplete inspection for that business. "
        'You have ${_businessList()}. Which one?',
      );
    }
    if (names.length > 1) {
      return SubmitFlowReply(
        'I found ${_join(names, 'or')}. Which business?',
      );
    }

    final name = names.first;
    final list = _all
        .where((r) => _norm(r.businessName) == _norm(name))
        .toList();
    return _resolve(name, list, t);
  }

  /// One inspection → submit. Several → use the date / time if already
  /// said, otherwise ask for it.
  SubmitFlowReply _resolve(
      String name, List<IncompleteInspectionRef> list, String t) {
    if (list.length == 1) return _go(list.first);

    final best = _bestByDateTime(t, list);
    if (best.length == 1) return _go(best.first);

    _choices = best.isNotEmpty ? best : list;
    _stage = _Stage.askWhich;
    return SubmitFlowReply(
      '$name has ${_choices.length} incomplete inspections: '
      '${_options(_choices)}. Which date and time?',
    );
  }

  // ---------------- Step 3: date and time ----------------

  SubmitFlowReply _onWhich(String t) {
    final byOrdinal = _byOrdinal(t, _choices);
    if (byOrdinal != null) return _go(byOrdinal);

    final best = _bestByDateTime(t, _choices);
    if (best.length == 1) return _go(best.first);

    if (best.length > 1) {
      _choices = best;
      return SubmitFlowReply(
        'Still ${best.length} match: ${_options(best)}. '
        'Please say the time too.',
      );
    }
    return SubmitFlowReply(
      "I couldn't match that. ${_options(_choices)}. "
      'Say the date and time, like ${_choices.first.spokenWhen}, '
      'or say first or second.',
    );
  }

  SubmitFlowReply _go(IncompleteInspectionRef r) {
    reset();
    return SubmitFlowReply(
      'Submitting ${r.businessName} from ${r.spokenWhen}. One moment.',
      keepListening: false,
      inspectionId: r.inspectionId,
    );
  }

  // ---------------- Database ----------------

  Future<List<IncompleteInspectionRef>> _loadIncomplete() async {
    final db = await DBManager.instance.database;
    final uid = userId();
    final rows = await db.query(
      'MobileFoodInspection',
      columns: [
        'inspection_id',
        'business_name',
        'permit_number',
        'inspection_date',
        'time_in',
        'time_out',
      ],
      where: uid == null ? null : 'user_id = ?',
      whereArgs: uid == null ? null : [uid],
      orderBy: 'inspection_date DESC, time_in DESC',
    );
    return rows.map(IncompleteInspectionRef.fromRow).toList();
  }

  // ---------------- Business name matching ----------------

  /// null  → no name words spoken
  /// []    → words spoken but nothing matches
  /// [..]  → best matching distinct business names
  List<String>? _matchNames(String t) {
    final tokens = t
        .split(' ')
        .where((w) =>
            w.isNotEmpty &&
            !w.contains(':') &&
            !_stop.contains(w) &&
            !_kMonthShort.any((m) => w.startsWith(m) && w.length <= 9))
        .toList();

    // Distinct names (case-insensitive)
    final names = <String, String>{};
    for (final r in _all) {
      names.putIfAbsent(_norm(r.businessName), () => r.businessName);
    }

    // 1. Full business name inside the sentence
    final full = names.keys
        .where((n) => n.length >= 3 && RegExp('\\b${RegExp.escape(n)}\\b').hasMatch(t))
        .toList();
    if (full.isNotEmpty) {
      final longest =
          full.map((n) => n.length).reduce((a, b) => a > b ? a : b);
      return full
          .where((n) => n.length == longest)
          .map((n) => names[n]!)
          .toList();
    }

    if (tokens.isEmpty) return null;

    // 2. Most spoken words found in the name (fuzzy)
    var best = 0;
    final out = <String>[];
    names.forEach((norm, original) {
      final words = norm.split(' ');
      final c = tokens.where((tk) => words.any((w) => _wordMatch(tk, w))).length;
      if (c > best) {
        best = c;
        out
          ..clear()
          ..add(original);
      } else if (c == best && c > 0) {
        out.add(original);
      }
    });
    return best == 0 ? [] : out;
  }

  bool _wordMatch(String t, String w) {
    if (t == w) return true;
    if (t.length >= 3 && w.startsWith(t)) return true;
    if (t.length >= 4 && w.length >= 4) {
      return _lev(t, w) <= (w.length >= 7 ? 2 : 1);
    }
    return false;
  }

  int _lev(String a, String b) {
    var prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        cur[j] = [cur[j - 1] + 1, prev[j] + 1, prev[j - 1] + cost]
            .reduce((x, y) => x < y ? x : y);
      }
      prev = cur;
    }
    return prev[b.length];
  }

  // ---------------- Date / time matching ----------------

  static final _timeColon =
      RegExp(r'\b(\d{1,2}):(\d{2})\s*(a ?m|p ?m)?\b');
  static final _timeAmPm =
      RegExp(r'\b(\d{1,2})(?: (\d{2}))?\s*(a ?m|p ?m)\b');
  static final _timeAt = RegExp(r'\bat (\d{1,2})(?: (\d{2}))?\b');
  static final _dateNumeric =
      RegExp(r'\b(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?\b');
  static final _dateIso = RegExp(r'\b(\d{4}) (\d{1,2}) (\d{1,2})\b');
  static final _dayNumber = RegExp(r'\b(\d{1,2})(?:st|nd|rd|th)?\b');

  /// Inspections with the highest date/time score (score > 0).
  List<IncompleteInspectionRef> _bestByDateTime(
      String t, List<IncompleteInspectionRef> list) {
    var best = 0;
    final out = <IncompleteInspectionRef>[];
    for (final r in list) {
      final s = _score(t, r);
      if (s > best) {
        best = s;
        out
          ..clear()
          ..add(r);
      } else if (s == best && s > 0) {
        out.add(r);
      }
    }
    return out;
  }

  int _score(String t, IncompleteInspectionRef r) {
    var score = 0;
    var rest = t;

    // ---- Time ("10:46", "10:46 am", "10 am", "12 20 pm", "at 10 46") ----
    for (final re in [_timeColon, _timeAmPm, _timeAt]) {
      for (final m in re.allMatches(rest)) {
        final h = int.tryParse(m.group(1)!);
        final min = m.group(2) == null ? null : int.tryParse(m.group(2)!);
        final ap = re == _timeAt ? null : m.group(3)?.replaceAll(' ', '');
        if (h == null || h > 23) continue;
        score += _timeScore(h, min, ap, r.hourIn, r.minuteIn);
        score += _timeScore(h, min, ap, r.hourOut, r.minuteOut) ~/ 2;
      }
      rest = rest.replaceAll(re, ' ');
    }

    final d = r.date;
    if (d == null) return score;

    // ---- today / yesterday ----
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    if (RegExp(r'\btoday\b').hasMatch(rest)) {
      score += day == today ? 4 : -4;
    }
    if (RegExp(r'\byesterday\b').hasMatch(rest)) {
      score += day == today.subtract(const Duration(days: 1)) ? 4 : -4;
    }

    // ---- 2026 10 13 (from "2026-10-13") ----
    for (final m in _dateIso.allMatches(rest)) {
      final mo = int.parse(m.group(2)!), da = int.parse(m.group(3)!);
      score += (mo == d.month && da == d.day) ? 5 : -3;
    }
    rest = rest.replaceAll(_dateIso, ' ');

    // ---- 10/13 or 10/13/2026 ----
    for (final m in _dateNumeric.allMatches(rest)) {
      final mo = int.parse(m.group(1)!), da = int.parse(m.group(2)!);
      score += (mo == d.month && da == d.day) ? 5 : -3;
    }
    rest = rest.replaceAll(_dateNumeric, ' ');

    // ---- Month name ("october", "oct") ----
    for (final w in rest.split(' ')) {
      final i = _kMonthShort.indexWhere(
          (m) => w.length >= 3 && w.startsWith(m) && w.length <= 9);
      if (i >= 0) score += (i + 1 == d.month) ? 2 : -3;
    }

    // ---- Day of month ("13", "13th") ----
    for (final m in _dayNumber.allMatches(rest)) {
      final n = int.parse(m.group(1)!);
      if (n >= 1 && n <= 31 && n == d.day) score += 2;
    }

    return score;
  }

  int _timeScore(int h, int? min, String? ap, int? rh, int? rm) {
    if (rh == null) return 0;
    var hour = h;
    if (ap == 'pm' && hour < 12) hour += 12;
    if (ap == 'am' && hour == 12) hour = 0;
    final hourOk = ap != null ? hour == rh : (hour == rh || hour + 12 == rh);
    if (!hourOk) return 0;
    if (min == null) return 2;
    return min == rm ? 4 : 0;
  }

  /// "first", "the second one", "number 2", "last", "latest", "oldest"
  IncompleteInspectionRef? _byOrdinal(
      String t, List<IncompleteInspectionRef> list) {
    const words = {
      'first': 0, 'second': 1, 'third': 2, 'fourth': 3, 'fifth': 4,
    };
    for (final e in words.entries) {
      if (RegExp('\\b${e.key}\\b').hasMatch(t) && e.value < list.length) {
        return list[e.value];
      }
    }
    final num = RegExp(r'\b(?:number|option) (\d)\b').firstMatch(t);
    if (num != null) {
      final i = int.parse(num.group(1)!) - 1;
      if (i >= 0 && i < list.length) return list[i];
    }
    if (RegExp(r'\b(last|latest|newest|most recent)\b').hasMatch(t)) {
      return list.first; // sorted newest first
    }
    if (RegExp(r'\b(oldest|earliest)\b').hasMatch(t)) return list.last;
    return null;
  }

  // ---------------- Text helpers ----------------

  /// lower case, keep letters, digits, ':' and '/'; "a.m." → "a m"
  String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9:/ ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  String _options(List<IncompleteInspectionRef> list) {
    final shown = list.take(4).toList();
    final parts = [
      for (var i = 0; i < shown.length; i++) '${i + 1}, ${shown[i].spokenWhen}',
    ];
    final more = list.length > shown.length
        ? '; and ${list.length - shown.length} more'
        : '';
    return parts.join('; ') + more;
  }

  String _businessList() {
    final names = <String, String>{};
    for (final r in _all) {
      names.putIfAbsent(_norm(r.businessName), () => r.businessName);
    }
    final list = names.values.toList();
    if (list.length > 5) {
      return '${_join(list.take(5).toList(), 'and')} and ${list.length - 5} more';
    }
    return _join(list, 'and');
  }

  String _join(List<String> items, String word) {
    if (items.length <= 1) return items.join();
    return '${items.sublist(0, items.length - 1).join(', ')} $word ${items.last}';
  }
}