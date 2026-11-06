import 'dart:math' as math;

// TODO: use the same DBManager import path as your other files.
import 'package:quincy/Database/DBManager.dart';
import 'package:quincy/Inspections/MobileFood/Model/MobileFoodInspectionModel.dart';
import 'package:quincy/Inspections/MobileFood/Model/MobileFoodPermitModel.dart';

// =====================================================================
//  VoiceAssistantBrain
//
//  A small conversation manager for the AI Guide. It understands
//  requests even with wrong spelling / pronunciation (fuzzy + phonetic
//  matching), remembers what it asked, and asks follow-up questions
//  until it has everything it needs:
//
//   • "open incomplete"            → Which section? → opens the list
//   • "open Rolling Bites"         → New or Incomplete? (if in both)
//   • "how many OUT / IN / NO / NA / COS / R"
//                                  → section → business → exact counts
//   • "open the PDF"               → section → business → Email tab
//   • "submit"                     → section → business → API not ready
//   • "how many incomplete" / "list incomplete"
//   • "cancel", "say again", "help"
//
//  Returns null when the request is not one of these, so the dashboard
//  can fall back to its normal menu commands.
// =====================================================================

class BrainReply {
  final String text;

  /// Keep the microphone open for the answer to a question
  final bool keepListening;

  /// Runs after the reply is spoken (navigation etc.)
  final Future<void> Function()? afterSpeak;

  const BrainReply(this.text, {this.keepListening = true, this.afterSpeak});
}

class VoiceAssistantBrain {
  VoiceAssistantBrain({
    required this.permits,
    required this.userId,
    required this.menuTitles,
    required this.openPermitList,
    required this.openIncompleteList,
    required this.openInspection,
    DBManager? db,
  }) : _db = db ?? DBManager.instance;

  /// Current Mobile Food permits (New inspections are started from these)
  final List<MobileFoodPermitModel> Function() permits;

  /// Logged-in user (incomplete inspections are per user)
  final int? Function() userId;

  /// Dashboard menu titles – used to recognise other sections
  final List<String> Function() menuTitles;

  final Future<void> Function({String? query, int? permitId}) openPermitList;
  final Future<void> Function() openIncompleteList;

  /// Opens a saved inspection at a tab (0 = Establishment … 4 = Email/PDF)
  final Future<void> Function(String inspectionId, int step) openInspection;

  final DBManager _db;

  static const String _mobileFood = 'Mobile Food';
  static const int _stepFinalSubmit = 3;
  static const int _stepEmail = 4;

  _Pending? _pending;
  String _lastSaid = '';

  // ------------------------------------------------------------------
  //  Entry point
  // ------------------------------------------------------------------

  Future<BrainReply?> handle(String raw) async {
    final text = _norm(raw);
    if (text.isEmpty) return null;
    final tokens = text.split(' ');

    // Questions expire after 2 minutes
    final p = _pending;
    if (p != null &&
        DateTime.now().difference(p.askedAt) > const Duration(minutes: 2)) {
      _pending = null;
    }

    // ---- Always available ----
    if (_hasAny(text, tokens, _sayAgainWords) && _lastSaid.isNotEmpty) {
      return BrainReply(_lastSaid, keepListening: _pending != null);
    }
    if (_hasAny(text, tokens, _helpWords) &&
        _detectIntent(text, tokens) == null) {
      return _say(_helpText, keepListening: _pending != null);
    }
    if (_pending != null && _hasAny(text, tokens, _cancelWords)) {
      _pending = null;
      return _say('Okay, cancelled. What would you like to do next?');
    }

    final fresh = _detectIntent(text, tokens);

    // ---- Answer to a question I asked ----
    if (_pending != null) {
      final pending = _pending!;
      // "how many OUT for Rolling Bites" while I was asking → keep the codes
      if (fresh != null &&
          fresh.intent == pending.intent &&
          fresh.codes.isNotEmpty) {
        pending.codes = fresh.codes;
      }
      final reply = await _answer(pending, text, tokens);
      if (reply != null) return reply;

      // Not an answer, but a new clear request → start over with it
      if (fresh != null) {
        _pending = null;
        return _start(fresh, text, tokens);
      }
      return _reask(pending);
    }

    // ---- New request ----
    if (fresh != null) return _start(fresh, text, tokens);
    return _businessOnly(text, tokens);
  }

  // ------------------------------------------------------------------
  //  Intent detection
  // ------------------------------------------------------------------

  _Detected? _detectIntent(String text, List<String> t) {
    final codes = _codesIn(text);
    final incomplete = _hasAny(text, t, _incompleteWords);
    final asking = _hasAny(text, t, _askWords);

    if (_hasAny(text, t, _submitWords)) return _Detected(_Intent.submit);
    if (_hasAny(text, t, _pdfWords)) return _Detected(_Intent.openPdf);

    if (codes.isNotEmpty ||
        (asking && _hasAny(text, t, _resultWords))) {
      return _Detected(_Intent.counts, codes);
    }
    if (incomplete && (asking || _hasAny(text, t, _listWords))) {
      return _Detected(_Intent.listIncomplete);
    }
    if (incomplete) return _Detected(_Intent.openIncomplete);
    if (_mentionsNew(text, t)) return _Detected(_Intent.openNew);
    return null;
  }

  // ------------------------------------------------------------------
  //  Start a request
  // ------------------------------------------------------------------

  Future<BrainReply> _start(
      _Detected d, String text, List<String> tokens) async {
    final p = _Pending(d.intent)..codes = d.codes;

    // Business name said in the same sentence?
    final pool = await _poolFor(p.intent);
    if (pool.isNotEmpty) {
      final m = _bestMatch(pool, text, tokens);
      if (m.accepted != null) {
        p.business = m.accepted;
      } else if (m.suggested != null) {
        p
          ..suggested = m.suggested
          ..choices = m.choices;
      }
    }

    if (_mentionsMobileFood(text, tokens)) {
      p.section = _mobileFood;
    } else if (p.business == null) {
      // "open pool incomplete" → another dashboard section
      final other = _otherSection(text, tokens);
      if (other != null) return _onlyMobileFood(other);
    }
    return _advance(p);
  }

  /// Plain business name with no other request ("Rolling Bites").
  Future<BrainReply?> _businessOnly(String text, List<String> tokens) async {
    // "open food inspection", "pool" … are menu commands, not businesses
    if (_otherSection(text, tokens) != null) return null;

    final pool = [...await _incompletePool(), ..._newPool()];
    if (pool.isEmpty) return null;

    final m = _bestMatch(pool, text, tokens, strict: true);
    if (m.accepted == null && m.suggested == null) return null;

    final p = _Pending(_Intent.openBusiness)..section = _mobileFood;
    if (m.accepted != null) {
      p.business = m.accepted;
    } else {
      p
        ..suggested = m.suggested
        ..choices = m.choices;
    }
    return _advance(p);
  }

  // ------------------------------------------------------------------
  //  Ask for what is missing, then act
  // ------------------------------------------------------------------

  Future<BrainReply> _advance(_Pending p) async {
    // 1) Section
    if (p.section == null) {
      return _ask(p, _Slot.section, 'Which section? Mobile Food?');
    }

    switch (p.intent) {
      case _Intent.openNew:
        _pending = null;
        final b = p.business;
        return _say(
          b == null
              ? 'Opening Mobile Food permits. Pick a business to start.'
              : 'Opening ${b.name} in Mobile Food permits.',
          keepListening: false,
          afterSpeak: () => openPermitList(query: b?.name, permitId: b?.permitId),
        );

      case _Intent.openIncomplete:
        final b = p.business ?? p.suggested;
        if (b == null) {
          _pending = null;
          return _say(
            'Opening your incomplete Mobile Food inspections.',
            keepListening: false,
            afterSpeak: openIncompleteList,
          );
        }
        if (p.business == null) return _confirm(p);
        return _openIncompleteInspection(b, 0);

      case _Intent.listIncomplete:
        return _listIncomplete();

      case _Intent.openBusiness:
        if (p.business == null) {
          if (p.suggested != null) return _confirm(p);
          return _askBusiness(p, [...await _incompletePool(), ..._newPool()]);
        }
        return _openBusiness(p);

      case _Intent.counts:
      case _Intent.openPdf:
      case _Intent.submit:
        final pool = await _incompletePool();
        if (pool.isEmpty) {
          _pending = null;
          return _say('You have no incomplete Mobile Food inspections.',
              keepListening: false);
        }
        if (p.business == null) {
          if (p.suggested != null) return _confirm(p);
          return _askBusiness(p, pool);
        }
        if (p.intent == _Intent.counts) return _counts(p);
        if (p.intent == _Intent.openPdf) return _openPdf(p.business!);
        return _submit(p.business!);
    }
  }

  BrainReply _ask(_Pending p, _Slot slot, String question,
      {List<_Candidate> options = const []}) {
    p
      ..awaiting = slot
      ..options = options
      ..question = question
      ..askedAt = DateTime.now();
    _pending = p;
    return _say(question);
  }

  BrainReply _askBusiness(_Pending p, List<_Candidate> pool) {
    final names = _uniqueNames(pool);
    String q;
    if (names.length == 1) {
      q = 'Which business name? You have ${names.first}.';
    } else if (names.length <= 4) {
      q = 'Which business name? ${_joinOr(names)}?';
    } else {
      q = 'Which business name?';
    }
    return _ask(p, _Slot.business, q, options: pool);
  }

  BrainReply _confirm(_Pending p) {
    if (p.choices.length > 1) {
      final options = p.choices;
      p.choices = const [];
      return _ask(
        p,
        _Slot.business,
        'Which one, ${_joinOr(_uniqueNames(options))}?',
        options: options,
      );
    }
    return _ask(p, _Slot.confirm, 'Did you mean ${p.suggested!.name}?');
  }

  BrainReply _reask(_Pending p) {
    p.retries++;
    if (p.retries > 2) {
      _pending = null;
      return _say("Sorry, I couldn't get that. Let's start again. "
          'What would you like to do?');
    }
    final hint = switch (p.awaiting) {
      _Slot.section => 'Please say Mobile Food, or say cancel.',
      _Slot.business =>
        'I could not find that business. Please say the business name again, '
            'or say cancel.',
      _Slot.target => 'Please say New or Incomplete.',
      _Slot.confirm || _Slot.offerPdf => 'Please say yes or no.',
      null => '',
    };
    p.askedAt = DateTime.now();
    return _say('Sorry. $hint');
  }

  BrainReply _onlyMobileFood(String section) => _say(
        'Right now I can do that only for Mobile Food, not $section.',
      );

  // ------------------------------------------------------------------
  //  Answers to my questions
  // ------------------------------------------------------------------

  Future<BrainReply?> _answer(
      _Pending p, String text, List<String> t) async {
    switch (p.awaiting) {
      case _Slot.section:
        if (_mentionsMobileFood(text, t) || _isYes(t)) {
          p.section = _mobileFood;
          // "Mobile Food, Rolling Bites" → take the name too
          if (p.business == null && p.suggested == null) {
            final pool = await _poolFor(p.intent);
            if (pool.isNotEmpty) {
              final m = _bestMatch(pool, text, t);
              if (m.accepted != null) p.business = m.accepted;
            }
          }
          return _advance(p);
        }
        final other = _otherSection(text, t);
        if (other != null) {
          p.askedAt = DateTime.now();
          return _say('Right now I can do that only for Mobile Food. '
              'Say Mobile Food, or say cancel.');
        }
        return null;

      case _Slot.target:
        if (_hasAny(text, t, _incompleteWords)) {
          p.target = _Kind.incomplete;
          return _openBusiness(p);
        }
        if (_mentionsNew(text, t)) {
          p.target = _Kind.permit;
          return _openBusiness(p);
        }
        return null;

      case _Slot.business:
        final picked = _pickOption(p.options, text, t);
        if (picked.accepted != null) {
          p.business = picked.accepted;
          return _advance(p);
        }
        if (picked.suggested != null) {
          p
            ..suggested = picked.suggested
            ..choices = picked.choices;
          return _confirm(p);
        }
        return null;

      case _Slot.confirm:
        if (_isYes(t)) {
          p.business = p.suggested;
          p.suggested = null;
          return _advance(p);
        }
        if (_isNo(t)) {
          p.suggested = null;
          final pool = p.intent == _Intent.openBusiness
              ? [...await _incompletePool(), ..._newPool()]
              : await _incompletePool();
          return _askBusiness(p, pool);
        }
        // They may have said the right name directly
        final pool = p.intent == _Intent.openBusiness
            ? [...await _incompletePool(), ..._newPool()]
            : await _incompletePool();
        final m = _bestMatch(pool, text, t);
        if (m.accepted != null) {
          p.business = m.accepted;
          p.suggested = null;
          return _advance(p);
        }
        return null;

      case _Slot.offerPdf:
        if (_isYes(t)) {
          _pending = null;
          return _openPdf(p.business!);
        }
        if (_isNo(t)) {
          _pending = null;
          return _say('Okay. Anything else?');
        }
        return null;

      case null:
        return null;
    }
  }

  // ------------------------------------------------------------------
  //  Actions
  // ------------------------------------------------------------------

  Future<BrainReply> _openBusiness(_Pending p) async {
    final b = p.business!;
    final key = _norm(b.name);
    final newMatch = _firstWithName(_newPool(), key);
    final incMatch = _firstWithName(await _incompletePool(), key);

    var target = p.target;
    if (target == null) {
      if (newMatch != null && incMatch != null) {
        return _ask(
          p,
          _Slot.target,
          '${b.name} is in both New and Incomplete. '
          'Where should I open it, New or Incomplete?',
        );
      }
      target = incMatch != null ? _Kind.incomplete : _Kind.permit;
    }

    if (target == _Kind.incomplete) {
      if (incMatch == null) {
        _pending = null;
        return _say('${b.name} has no incomplete inspection. '
            'Say "open ${b.name} new" to start one.');
      }
      return _openIncompleteInspection(incMatch, 0);
    }

    _pending = null;
    final permit = newMatch ?? b;
    return _say(
      'Opening ${permit.name} in Mobile Food permits.',
      keepListening: false,
      afterSpeak: () =>
          openPermitList(query: permit.name, permitId: permit.permitId),
    );
  }

  Future<BrainReply> _openIncompleteInspection(_Candidate c, int step) async {
    _pending = null;
    final count = (await _incompletePool())
        .where((x) => _norm(x.name) == _norm(c.name))
        .length;
    final extra =
        count > 1 ? ' You have $count for this business; I opened the latest.' : '';
    return _say(
      'Opening the incomplete inspection for ${c.name}.$extra',
      keepListening: false,
      afterSpeak: () => openInspection(c.inspectionId!, step),
    );
  }

  Future<BrainReply> _listIncomplete() async {
    final names = _uniqueNames(await _incompletePool());
    if (names.isEmpty) {
      _pending = null;
      return _say('You have no incomplete Mobile Food inspections.');
    }
    final pool = await _incompletePool();
    final p = _Pending(_Intent.openIncomplete)..section = _mobileFood;
    final list = names.length <= 6
        ? ': ${_joinAnd(names)}'
        : '. The latest are ${_joinAnd(names.take(5).toList())}';
    return _ask(
      p,
      _Slot.business,
      'You have ${names.length} incomplete Mobile Food '
      '${names.length == 1 ? 'inspection' : 'inspections'}$list. '
      'Say a business name to open one.',
      options: pool,
    );
  }

  Future<BrainReply> _counts(_Pending p) async {
    _pending = null;
    final b = p.business!;
    final answers = await _db.getMobileFoodAnswers(b.inspectionId!);
    final tree = await _db.getMobileFoodChecklistTree();

    // itemId → serial number, in checklist order
    final serials = <int, String>{};
    var total = 0;
    for (final s in tree) {
      for (final part in s.parts) {
        for (final i in part.items) {
          serials[i.id] = '${i.serialNumber}';
          total++;
        }
      }
    }

    final byCode = <String, List<String>>{
      for (final c in _codeOrder) c: <String>[],
    };
    var answered = 0;
    for (final a in answers) {
      final serial = serials[a.itemId];
      if (serial == null) continue; // item no longer in checklist
      final r = a.result;
      if (r != null) {
        answered++;
        byCode[r]?.add(serial);
      }
      if (a.cos) byCode['COS']!.add(serial);
      if (a.repeat) byCode['R']!.add(serial);
    }
    for (final list in byCode.values) {
      list.sort((x, y) =>
          (int.tryParse(x) ?? 0).compareTo(int.tryParse(y) ?? 0));
    }

    if (p.codes.isEmpty) {
      String n(String c) => '${byCode[c]!.length} ${_codeSpoken[c]}';
      return _say(
        'For ${b.name}: ${n('IN')}, ${n('OUT')}, ${n('NO')}, ${n('NA')}, '
        '${n('COS')}, and ${n('R')}. '
        '$answered of $total items are answered.',
        keepListening: false,
      );
    }

    final parts = <String>[];
    for (final c in _codeOrder.where(p.codes.contains)) {
      final list = byCode[c]!;
      if (list.isEmpty) {
        parts.add('No items are marked ${_codeSpoken[c]}.');
      } else {
        final shown = list.length > 10
            ? '${list.take(10).join(', ')} and ${list.length - 10} more'
            : _joinAnd(list);
        parts.add('${list.length} '
            '${list.length == 1 ? 'item is' : 'items are'} marked '
            '${_codeSpoken[c]}: item${list.length == 1 ? '' : 's'} $shown.');
      }
    }
    return _say('For ${b.name}: ${parts.join(' ')}', keepListening: false);
  }

  Future<BrainReply> _openPdf(_Candidate b) async {
    _pending = null;
    final f = await _db.getMobileFoodFinalSubmit(b.inspectionId!);
    final ready = f != null &&
        (f.picSignDate ?? '').isNotEmpty &&
        f.picName.trim().isNotEmpty &&
        (f.inspectorSignDate ?? '').isNotEmpty &&
        f.inspectorName.trim().isNotEmpty;

    if (!ready) {
      return _say(
        '${b.name} still needs the Final Submit dates and names before the '
        'PDF can be made. Opening Final Submit.',
        keepListening: false,
        afterSpeak: () => openInspection(b.inspectionId!, _stepFinalSubmit),
      );
    }
    return _say(
      'Opening the PDF for ${b.name}.',
      keepListening: false,
      afterSpeak: () => openInspection(b.inspectionId!, _stepEmail),
    );
  }

  BrainReply _submit(_Candidate b) {
    final p = _Pending(_Intent.openPdf)
      ..section = _mobileFood
      ..business = b;
    return _ask(
      p,
      _Slot.offerPdf,
      'Submitting to the server is not connected yet, so I cannot submit '
      '${b.name} right now. Its data is saved on this device. '
      'Would you like me to open its PDF instead?',
    );
  }

  // ------------------------------------------------------------------
  //  Data pools
  // ------------------------------------------------------------------

  Future<List<_Candidate>> _poolFor(_Intent i) async {
    switch (i) {
      case _Intent.openNew:
        return _newPool();
      case _Intent.openBusiness:
        return [...await _incompletePool(), ..._newPool()];
      case _Intent.listIncomplete:
        return const [];
      default:
        return _incompletePool();
    }
  }

  List<_Candidate> _newPool() => [
        for (final p in permits())
          if (p.businessName.trim().isNotEmpty)
            _Candidate(p.businessName.trim(), _Kind.permit, permitId: p.id),
      ];

  /// Newest first (the DB orders by updated_at DESC)
  Future<List<_Candidate>> _incompletePool() async {
    final id = userId();
    if (id == null) return const [];
    final List<MobileFoodInspectionModel> list =
        await _db.getIncompleteMobileFoodInspections(id);
    return [
      for (final i in list)
        if (i.businessName.trim().isNotEmpty)
          _Candidate(i.businessName.trim(), _Kind.incomplete,
              inspectionId: i.inspectionId),
    ];
  }

  _Candidate? _firstWithName(List<_Candidate> pool, String normName) {
    for (final c in pool) {
      if (_norm(c.name) == normName) return c;
    }
    return null;
  }

  List<String> _uniqueNames(List<_Candidate> pool) {
    final seen = <String>{};
    final out = <String>[];
    for (final c in pool) {
      if (seen.add(_norm(c.name))) out.add(c.name);
    }
    return out;
  }

  // ------------------------------------------------------------------
  //  Fuzzy business matching
  // ------------------------------------------------------------------

  static const double _accept = 0.78;
  static const double _maybe = 0.6;

  _Match _bestMatch(List<_Candidate> pool, String text, List<String> tokens,
      {bool strict = false}) {
    final stop = {..._stopWords, if (strict) ..._menuWords()};
    final said = tokens.where((w) => w.isNotEmpty && !stop.contains(w)).toList();
    if (said.isEmpty) return const _Match();

    // Best score per unique business name
    final best = <String, _Scored>{};
    for (final c in pool) {
      final key = _norm(c.name);
      final s = _nameScore(text, said, key);
      final cur = best[key];
      if (cur == null || s > cur.score) best[key] = _Scored(c, s);
    }
    final ranked = best.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    if (ranked.isEmpty) return const _Match();

    final top = ranked.first;
    final second = ranked.length > 1 ? ranked[1] : null;
    final close = top.score < 1 &&
        second != null &&
        second.score >= _maybe &&
        top.score - second.score < 0.06;

    if (top.score >= _accept && !close) return _Match(accepted: top.c);
    if (top.score >= _maybe) {
      return _Match(
        suggested: top.c,
        choices: close
            ? ranked
                .where((x) => x.score >= _maybe && top.score - x.score < 0.06)
                .take(3)
                .map((x) => x.c)
                .toList()
            : const [],
      );
    }
    return const _Match();
  }

  /// Answer to "Which business?" – a name, or "first / second …".
  _Match _pickOption(List<_Candidate> options, String text, List<String> t) {
    if (options.isEmpty) return const _Match();
    final names = _uniqueNames(options);
    const ordinals = {
      'first': 0, 'one': 0, '1': 0, '1st': 0,
      'second': 1, 'two': 1, '2': 1, '2nd': 1,
      'third': 2, 'three': 2, '3': 2, '3rd': 2,
      'fourth': 3, 'four': 3, '4': 3, '4th': 3,
    };
    if (t.length <= 3) {
      for (final w in t) {
        final i = w == 'last' ? names.length - 1 : ordinals[w];
        if (i != null && i < names.length) {
          return _Match(accepted: _firstWithName(options, _norm(names[i])));
        }
      }
    }
    return _bestMatch(options, text, t);
  }

  /// 0..1 – how well the spoken words match a business name.
  double _nameScore(String text, List<String> said, String name) {
    if (name.isEmpty) return 0;
    // Whole name said → certain; the longer name wins
    // ("Rolling Bites Express" beats "Rolling Bites").
    if (' $text '.contains(' $name ')) return 1 + name.length / 1000;

    final nameTokens = name
        .split(' ')
        .where((w) => w.isNotEmpty && !_nameNoise.contains(w))
        .toList();
    if (nameTokens.isEmpty) return 0;

    // Precision: spoken words found in the name
    var matchedSum = 0.0;
    var matched = 0;
    var unmatched = 0;
    for (final w in said) {
      var b = 0.0;
      for (var i = 0; i < nameTokens.length; i++) {
        b = math.max(b, _tokenSim(w, nameTokens[i]));
        if (i + 1 < nameTokens.length) {
          b = math.max(b, _tokenSim(w, nameTokens[i] + nameTokens[i + 1]));
        }
      }
      if (b >= 0.75) {
        matched++;
        matchedSum += b;
      } else {
        unmatched++;
      }
    }
    if (matched == 0) return 0;
    final precision = matchedSum / (matched + 0.35 * unmatched);

    // Coverage: name words that were said
    var cover = 0.0;
    for (final n in nameTokens) {
      var b = 0.0;
      for (var i = 0; i < said.length; i++) {
        b = math.max(b, _tokenSim(said[i], n));
        if (i + 1 < said.length) {
          b = math.max(b, _tokenSim(said[i] + said[i + 1], n));
        }
      }
      if (b >= 0.75) cover += b;
    }
    final coverage = cover / nameTokens.length;

    return precision * (0.7 + 0.3 * coverage);
  }

  // ------------------------------------------------------------------
  //  Concepts (fuzzy keyword sets)
  // ------------------------------------------------------------------

  static const _incompleteWords = [
    'incomplete', 'in complete', 'uncomplete', 'not complete',
    'incompleted', 'incomplete inspection', 'unfinished', 'pending',
    'draft', 'drafts', 'saved inspection', 'saved inspections',
  ];
  static const _mobileFoodWords = [
    'mobile food', 'mobile foods', 'food truck', 'food trucks',
    'mobile', 'mobil food', 'noble food', 'mobile foot', 'mobile fruit',
  ];
  static const _submitWords = [
    'submit', 'submission', 'submitted', 'summit', 'sub mit',
    'send to server', 'upload',
  ];
  static const _pdfWords = [
    'pdf', 'p d f', 'pdf report', 'report', 'email', 'e mail',
    'inspection report',
  ];
  static const _askWords = [
    'how many', 'how much', 'number of', 'count', 'total', 'tell me',
    'what is', 'what are', 'status', 'summary', 'details', 'result',
    'results', 'list', 'show me', 'give me',
  ];
  static const _resultWords = [
    'selected', 'marked', 'items', 'item', 'answers', 'answered',
    'results', 'result', 'status', 'summary', 'compliance', 'violations',
    'violation', 'checked',
  ];
  static const _listWords = ['list', 'which', 'what are', 'all', 'names'];
  static const _newWords = [
    'new inspection', 'start inspection', 'start a new', 'start new',
    'begin inspection', 'create inspection', 'new one',
  ];
  static const _cancelWords = [
    'cancel', 'never mind', 'nevermind', 'forget it', 'leave it',
    'skip it', 'no thanks', 'no thank you',
  ];
  static const _helpWords = [
    'help', 'what can you do', 'what can i say', 'commands',
    'how do i use',
  ];
  static const _sayAgainWords = [
    'say again', 'say that again', 'repeat that', 'what did you say',
    'pardon', 'come again', 'one more time',
  ];
  static const _yesWords = {
    'yes', 'yeah', 'yep', 'yup', 'sure', 'correct', 'right', 'ok',
    'okay', 'please', 'exactly', 'affirmative', 'ya', 'yah', 'yes please',
  };
  static const _noWords = {'no', 'nope', 'nah', 'not', 'wrong', 'negative'};

  static const _helpText =
      'You can say: open incomplete, open new, or a business name. '
      'Ask how many IN, OUT, not observed, not applicable, corrected on '
      'site or repeat items an inspection has. Say open the PDF, submit, '
      'or list incomplete inspections. Say cancel to stop a question.';

  /// Words ignored when matching business names
  static const _stopWords = {
    'open', 'start', 'show', 'find', 'search', 'select', 'pick', 'choose',
    'go', 'to', 'the', 'a', 'an', 'and', 'of', 'for', 'with', 'at', 'me',
    'my', 'please', 'can', 'could', 'would', 'you', 'i', 'want', 'need',
    'know', 'tell', 'how', 'many', 'much', 'number', 'count', 'total',
    'items', 'item', 'selected', 'marked', 'pdf', 'p', 'd', 'f', 'report',
    'email', 'e', 'mail', 'submit', 'mobile', 'food', 'section', 'business',
    'name', 'new', 'incomplete', 'inspection', 'inspections', 'permit',
    'permits', 'list', 'is', 'are', 'was', 'were', 'it', 'this', 'that',
    'from', 'about', 'status', 'view', 'see', 'check', 'give', 'what',
    'which', 'there', 'does', 'do', 'have', 'has', 'did', 'in', 'out', 'no',
    'na', 'n', 'o', 'cos', 'c', 's', 'r', 'repeat', 'compliance', 'not',
    'observed', 'applicable', 'corrected', 'on', 'site', 'okay', 'ok', 'yes',
    'hey', 'quincy', 'results', 'result', 'summary', 'details', 'data',
    'info', 'information', 'answers', 'answered', 'one', 'now', 'just', 'get',
    'let', 'lets', 'us', 'up', 'its', 'all', 'violations', 'violation',
    'saved', 'pending', 'draft', 'complete', 'into', 'under', 'then', 'also',
    'again',
  };

  /// Common words inside business names that carry no meaning
  static const _nameNoise = {
    'the', 'and', 'of', 'llc', 'inc', 'co', 'corp', 'ltd',
  };

  Set<String> _menuWords() {
    final out = <String>{};
    for (final t in menuTitles()) {
      out.addAll(_norm(t).split(' ').where((w) => w.length > 2));
    }
    return out;
  }

  bool _mentionsMobileFood(String text, List<String> t) =>
      _hasAny(text, t, _mobileFoodWords);

  bool _mentionsNew(String text, List<String> t) =>
      t.contains('new') || _hasAny(text, t, _newWords);

  /// Another dashboard section was named (e.g. "Pool", "Tobacco").
  String? _otherSection(String text, List<String> t) {
    for (final title in menuTitles()) {
      final n = _norm(title);
      if (n.isEmpty || n.contains('mobile')) continue;
      if (_hasAny(text, t, [n])) return title;
    }
    return null;
  }

  bool _isYes(List<String> t) => t.any(_yesWords.contains) && !_isNo(t);
  bool _isNo(List<String> t) => t.isNotEmpty && _noWords.contains(t.first);

  // ---- Result codes ("how many OUT", "COS count" …) ----

  static const _codeOrder = ['IN', 'OUT', 'NO', 'NA', 'COS', 'R'];

  static const _codeSpoken = {
    'IN': 'in compliance',
    'OUT': 'out of compliance',
    'NO': 'not observed',
    'NA': 'not applicable',
    'COS': 'corrected on site',
    'R': 'repeat',
  };

  static const _codePatterns = {
    'OUT': r'out of compliance|outs|out',
    'IN': r'in compliance|ins|in(?=\s*(?:$|and\b|or\b|items?\b|count\b|'
        r'selected\b|marked\b|for\b|answers\b))',
    'NO': r'not observed|n o s|n o|nos|no',
    'NA': r'not applicable|n a s|n a|nas|na',
    'COS': r'corrected on site|corrected|c o s|cos|coss|cost|course|cause',
    'R': r'repeat violations|repeat violation|repeats|repeat|r',
  };

  Set<String> _codesIn(String text) {
    const lead = r'(?:how many|number of|count of|count|total|and|or|also|plus)'
        r'\s+(?:items?\s+)?(?:are\s+|were\s+|is\s+)?'
        r'(?:marked\s+|selected\s+(?:as\s+)?|set\s+(?:to\s+)?)?';
    final found = <String>{};
    _codePatterns.forEach((code, alts) {
      final before = RegExp('\\b$lead(?:$alts)\\b');
      final after = RegExp('\\b(?:$alts)\\s+'
          '(?:count|items|item|selected|marked|answers|total)\\b');
      if (before.hasMatch(text) || after.hasMatch(text)) found.add(code);
    });
    return found;
  }

  // ------------------------------------------------------------------
  //  Text helpers
  // ------------------------------------------------------------------

  BrainReply _say(String text,
      {bool keepListening = true, Future<void> Function()? afterSpeak}) {
    _lastSaid = text;
    return BrainReply(text,
        keepListening: keepListening, afterSpeak: afterSpeak);
  }

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll('&', ' and ')
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  String _joinAnd(List<String> l) => _join(l, 'and');
  String _joinOr(List<String> l) => _join(l, 'or');

  String _join(List<String> l, String word) {
    if (l.isEmpty) return '';
    if (l.length == 1) return l.first;
    return '${l.sublist(0, l.length - 1).join(', ')} $word ${l.last}';
  }

  /// True when the utterance contains one of [variants] – exactly,
  /// or close enough (spelling / pronunciation / split words).
  bool _hasAny(String text, List<String> tokens, Iterable<String> variants) {
    final padded = ' $text ';
    for (final v in variants) {
      if (padded.contains(' $v ')) return true;

      final vt = v.split(' ');
      final joined = v.replaceAll(' ', '');
      // Short words must be exact (in, no, pdf, new …)
      if (joined.length <= 4) continue;

      for (final size in {vt.length - 1, vt.length, vt.length + 1}) {
        if (size < 1 || size > tokens.length) continue;
        for (var i = 0; i + size <= tokens.length; i++) {
          final window = tokens.sublist(i, i + size).join();
          if (_similarWord(window, joined)) return true;
        }
      }
    }
    return false;
  }

  bool _similarWord(String a, String b) {
    if (a == b) return true;
    if (math.min(a.length, b.length) < 5) return false;
    final r = _ratio(a, b);
    if (r >= 0.82) return true;
    return r >= 0.65 && _phonetic(a) == _phonetic(b);
  }

  double _tokenSim(String a, String b) {
    if (a == b) return 1;
    if (a.length <= 2 || b.length <= 2) return 0;
    // Partial word ("roll" for "rolling") or plural ("bite" / "bites")
    if (a.length >= 3 && b.startsWith(a)) return 0.86;
    if (b.length >= 3 && a.startsWith(b)) return 0.86;
    final r = _ratio(a, b);
    if (_phonetic(a) == _phonetic(b)) return math.max(r, 0.88);
    return r;
  }

  double _ratio(String a, String b) {
    final m = math.max(a.length, b.length);
    if (m == 0) return 1;
    return 1 - _levenshtein(a, b) / m;
  }

  int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    var cur = List<int>.filled(b.length + 1, 0);
    for (var i = 1; i <= a.length; i++) {
      cur[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        cur[j] = math.min(
          math.min(cur[j - 1] + 1, prev[j] + 1),
          prev[j - 1] + cost,
        );
      }
      final t = prev;
      prev = cur;
      cur = t;
    }
    return prev[b.length];
  }

  /// Sound-alike key: "Tako" = "Taco", "Fil" = "Phil", "Kwik" = "Quick".
  String _phonetic(String word) {
    var s = word.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (s.isEmpty) return '';
    s = s
        .replaceAll(RegExp(r'ing$'), 'in') // "rolin" = "rolling"
        .replaceAll('ph', 'f')
        .replaceAll('ck', 'k')
        .replaceAll('kn', 'n')
        .replaceAll('wr', 'r')
        .replaceAll('wh', 'w')
        .replaceAll('gh', 'g')
        .replaceAll('sch', 'sk')
        .replaceAll('tch', 'X')
        .replaceAll('sh', 'X')
        .replaceAll('ch', 'X')
        .replaceAll('th', '0')
        .replaceAll('dg', 'j')
        .replaceAll(RegExp(r'c(?=[eiy])'), 's')
        .replaceAll('c', 'k')
        .replaceAll('q', 'k')
        .replaceAll('x', 'ks')
        .replaceAll('z', 's')
        .replaceAll('v', 'f')
        .replaceAll('d', 't');
    final first = s[0];
    var rest = s.substring(1).replaceAll(RegExp(r'[aeiouyhw]'), '');
    final out = StringBuffer(first);
    var last = first;
    for (final ch in rest.split('')) {
      if (ch != last) out.write(ch);
      last = ch;
    }
    return out.toString();
  }
}

// ---------------------------------------------------------------------

enum _Intent {
  openIncomplete,
  openNew,
  openBusiness,
  listIncomplete,
  counts,
  openPdf,
  submit,
}

enum _Slot { section, business, target, confirm, offerPdf }

enum _Kind { permit, incomplete }

class _Detected {
  final _Intent intent;
  final Set<String> codes;
  _Detected(this.intent, [this.codes = const {}]);
}

class _Candidate {
  final String name;
  final _Kind kind;
  final int? permitId;
  final String? inspectionId;

  _Candidate(this.name, this.kind, {this.permitId, this.inspectionId});
}

class _Scored {
  final _Candidate c;
  final double score;
  _Scored(this.c, this.score);
}

class _Match {
  final _Candidate? accepted;
  final _Candidate? suggested;

  /// Several names sound alike → ask "Which one, A or B?"
  final List<_Candidate> choices;

  const _Match({this.accepted, this.suggested, this.choices = const []});
}

class _Pending {
  final _Intent intent;
  String? section;
  _Candidate? business;
  _Candidate? suggested;
  List<_Candidate> choices = const [];
  _Kind? target;
  Set<String> codes = const {};

  _Slot? awaiting;
  List<_Candidate> options = const [];
  String question = '';
  int retries = 0;
  DateTime askedAt = DateTime.now();

  _Pending(this.intent);
}