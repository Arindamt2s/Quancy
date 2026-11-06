/// Voice → Inspection Form answers and comments
/// (pure Dart, no Flutter imports – easy to unit test).
///
/// The parser is forgiving: it fixes words the speech engine mis-heard,
/// understands self-corrections, remembers the last questions you talked
/// about, and checks numbers against the form.
///
/// RESULTS
///   "question 1 IN"                         → 1 IN
///   "question no 4 OUT with R"              → 4 OUT + R
///   "question 4 OUT corrected on site"      → 4 OUT + COS
///   "question 7 COS" / "question 7 R"       → OUT + COS / OUT + R
///   "question 3 not observed" / "NO"        → NO
///   "question 5 N/A" / "not applicable"     → NA
///
/// MANY QUESTIONS
///   "questions 1 2 3 4 5 6 7 8 IN"          → 1–8 IN
///   "question 12345678 IN"                  → 1–8 IN (glued digits)
///   "questions 1 to 8 IN", "1-8 IN", "1 through 8 IN"
///   "question 1 IN 2 OUT with R 3 NA"
///   "items 1 2 5 7 IN OUT NO NA"            → paired in order (1 IN, 2 OUT …)
///   "questions 1 to 10 IN except 4 and 7"   → 4 and 7 untouched
///   "questions 1 to 10 IN but 4 OUT with R" → 1–10 IN, 4 OUT + R
///   "all IN", "all questions in this section NA"
///   "remaining NA" / "rest IN" / "all unanswered NO"
///   "question 4 OUT, all others IN"
///
/// MIS-HEARD / LOOSE SPEECH (examples)
///   "kwestion 4 owt with our"               → 4 OUT + R
///   "item for out with are"                 → 4 OUT + R
///   "cushion 3 not observe"                 → 3 NO
///   "question 5 and a"                      → 5 NA
///   "question 2 cause"                      → 2 OUT + COS
///   "questions 1 to 10 IN accept 4"         → "accept" read as "except"
///   "the fourth question IN"                → 4 IN
///   "question 4 IN, sorry, OUT"             → 4 OUT  (self-correction)
///   "question 4 IN, no, OUT"                → 4 OUT
///   "question 4 sorry 5 IN"                 → 5 IN   (wrong number fixed)
///   "question forty IN" (form has 14)       → 14 IN
///   "OUT with R" right after "question 4"   → 4 OUT + R (remembers the
///                                             last questions – see
///                                             [VoiceItemMemory])
///
/// COMMENTS (text keeps the inspector's words)
///   "question 1 comment test1"
///   "item 1 set commend test1"              → "commend" read as "comment"
///   "question 1 set comment to hand sink blocked"
///   "add a comment for question 5: no soap at hand sink"
///   "question 4 OUT with R comment no thermometer"
///   "question 4 append comment owner informed"
///   "clear comment for question 4" / "question 4 remove comment"
///   "question 4 comment" … (AI asks) … "no soap" → comment for 4
///
/// QUESTIONS ABOUT AN ITEM
///   "what is question 4", "read question 4", "status of question 4"
///
/// CLEAR
///   "clear question 6", "remove R from question 4", "clear it"
library;

enum VoiceItemAction { set, clear, removeFlags }

enum VoiceCommentMode { set, append, clear }

class VoiceItemAnswer {
  /// Question / serial number spoken by the inspector.
  final int number;
  final VoiceItemAction action;

  /// IN / OUT / NO / NA (only for [VoiceItemAction.set]).
  final String? result;

  /// Corrected on site / Repeat. For [VoiceItemAction.removeFlags] these
  /// mean "remove this flag".
  final bool cos;
  final bool repeat;

  const VoiceItemAnswer({
    required this.number,
    required this.action,
    this.result,
    this.cos = false,
    this.repeat = false,
  });

  @override
  String toString() =>
      'Q$number ${action.name} $result${cos ? '+COS' : ''}${repeat ? '+R' : ''}';
}

class VoiceItemComment {
  final int number;
  final String text;
  final VoiceCommentMode mode;

  const VoiceItemComment({
    required this.number,
    required this.text,
    required this.mode,
  });

  @override
  String toString() => 'Q$number comment ${mode.name} "$text"';
}

/// What the screen knows, so the parser can understand "all", "remaining",
/// "this section", glued digits ("12345678"), follow-up answers and
/// numbers that are not on the form.
class VoiceItemContext {
  /// Every question number on the form.
  final List<int> allNumbers;

  /// Question numbers that already have IN / OUT / NO / NA.
  final Set<int> answered;

  /// Question numbers in the section that is open on screen.
  final List<int> sectionNumbers;

  /// Questions talked about in the previous command. Used when the
  /// inspector says only "OUT with R", "clear it" or "comment no soap".
  final List<int> recentNumbers;

  /// The AI just asked "What should the comment for question 4 say?" –
  /// the next sentence is taken as that comment.
  final List<int> awaitingCommentFor;

  const VoiceItemContext({
    required this.allNumbers,
    required this.answered,
    required this.sectionNumbers,
    this.recentNumbers = const [],
    this.awaitingCommentFor = const [],
  });

  int get maxNumber =>
      allNumbers.isEmpty ? 0 : allNumbers.reduce((a, b) => a > b ? a : b);
}

class VoiceItemParseResult {
  final List<VoiceItemAnswer> answers;
  final List<VoiceItemComment> comments;

  /// "what is question 4" → [4]
  final List<int> queryNumbers;

  /// Numbers spoken without IN / OUT / NO / NA and without a comment.
  final List<int> missingResult;

  /// Full sentences to say back (ends with "." or "?").
  final List<String> warnings;

  /// Questions whose comment text was asked for ("question 4 comment").
  final List<int> commentNeeded;

  /// Guesses the parser made from mis-heard words, as full sentences
  /// ('I heard "owt" as OUT.'). Worth saying back so the inspector can
  /// correct a wrong guess.
  final List<String> assumptions;

  const VoiceItemParseResult({
    required this.answers,
    required this.comments,
    required this.queryNumbers,
    required this.missingResult,
    required this.warnings,
    this.commentNeeded = const [],
    this.assumptions = const [],
  });

  bool get isEmpty =>
      answers.isEmpty &&
      comments.isEmpty &&
      queryNumbers.isEmpty &&
      missingResult.isEmpty &&
      warnings.isEmpty &&
      commentNeeded.isEmpty;

  /// Every question number this result is about.
  List<int> get touchedNumbers => {
        ...answers.map((a) => a.number),
        ...comments.map((c) => c.number),
        ...queryNumbers,
        ...missingResult,
        ...commentNeeded,
      }.toList()
        ..sort();
}

/// Keep one of these on the inspection screen so follow-ups work:
///
/// ```dart
/// final _voiceMemory = VoiceItemMemory();
///
/// final result = ItemAnswerVoiceParser.parse(
///   text,
///   context: _voiceMemory.context(
///     allNumbers: allNumbers,
///     answered: answered,
///     sectionNumbers: sectionNumbers,
///   ),
/// );
/// _voiceMemory.remember(result);
/// ```
class VoiceItemMemory {
  List<int> recent = const [];
  List<int> awaitingComment = const [];

  VoiceItemContext context({
    required List<int> allNumbers,
    Set<int> answered = const {},
    List<int> sectionNumbers = const [],
  }) =>
      VoiceItemContext(
        allNumbers: allNumbers,
        answered: answered,
        sectionNumbers: sectionNumbers,
        recentNumbers: recent,
        awaitingCommentFor: awaitingComment,
      );

  /// Call after every parse. A null result (sentence not about questions)
  /// keeps the memory as it is.
  void remember(VoiceItemParseResult? result) {
    if (result == null) return;
    final touched = result.touchedNumbers;
    if (touched.isNotEmpty) recent = List.unmodifiable(touched);
    awaitingComment = List.unmodifiable(result.commentNeeded);
  }

  /// Call when the inspection screen closes or the form changes.
  void clear() {
    recent = const [];
    awaitingComment = const [];
  }
}

enum _Scope { all, unanswered }

class ItemAnswerVoiceParser {
  ItemAnswerVoiceParser._();

  // ---------------- Vocabulary ----------------

  static const Set<String> _questionWords = {
    'question', 'questions', 'item', 'items', 'q', 'number', 'numbers',
    'serial',
  };

  static const Set<String> _rangeWords = {
    'to', 'through', 'thru', 'till', 'until', 'upto',
  };

  static const Set<String> _exceptWords = {
    'except', 'excluding', 'exclude', 'besides', 'apart', 'without',
  };

  static const Set<String> _clearWords = {
    'clear', 'remove', 'reset', 'unselect', 'deselect', 'erase', 'delete',
    'unmark', 'uncheck',
  };

  static const Set<String> _queryWords = {
    'what', 'whats', 'read', 'tell', 'status', 'check', 'show', 'which',
    'how', 'many', 'count',
  };

  /// "question 4 IN sorry OUT" – the next word replaces what came before.
  static const Set<String> _correctionWords = {
    'sorry', 'actually', 'mean', 'wait', 'correction', 'oops', 'rather',
  };

  static const Map<String, _Scope> _scopeWords = {
    'all': _Scope.all,
    'every': _Scope.all,
    'everything': _Scope.all,
    'other': _Scope.all,
    'others': _Scope.all,
    'remaining': _Scope.unanswered,
    'rest': _Scope.unanswered,
    'unanswered': _Scope.unanswered,
    'unmarked': _Scope.unanswered,
    'pending': _Scope.unanswered,
  };

  static const Map<String, String> _codeWords = {
    // IN
    'in': 'IN', 'inn': 'IN', 'incompliance': 'IN',
    // OUT
    'out': 'OUT', 'outs': 'OUT', 'outofcompliance': 'OUT',
    // NO (not observed)
    'no': 'NO', 'notobserved': 'NO',
    // NA (not applicable)
    'na': 'NA', 'nah': 'NA', 'naa': 'NA', 'notapplicable': 'NA',
    // COS (corrected on site)
    'cos': 'COS', 'coz': 'COS', 'kos': 'COS', 'corrected': 'COS',
    'correctedonsite': 'COS',
    // R (repeat). "are" / "our" are only read as R where R makes sense –
    // see _rLike.
    'r': 'R', 'repeat': 'R', 'repeated': 'R', 'repeating': 'R',
    'repeats': 'R',
  };

  // Words the speech engine produces instead of a result. Only used right
  // after a question number (or after OUT / "with" for COS and R), so
  // normal words elsewhere are not touched.
  static const Set<String> _outLike = {
    'owt', 'aut', 'outt', 'ought', 'aout', 'oud', 'owed', 'outed', 'doubt',
    'shout', 'oat', 'ott', 'auto', 'ouch', 'outa', 'outta', 'pout', 'gout',
  };
  static const Set<String> _inLike = {
    'en', 'enn', 'yin', 'ing', 'inh', 'ein', 'ian', 'inc', 'inne', 'ins',
  };
  static const Set<String> _noLike = {
    'know', 'noh', 'knoe', 'nope', 'noo', 'gno', 'knew', 'nor', 'noe',
  };
  static const Set<String> _naLike = {
    'nay', 'neigh', 'nae', 'ena', 'enay', 'inna', 'ina', 'nha', 'enna',
    'nan', 'any', 'nia',
  };
  static const Set<String> _cosLike = {
    'cause', 'because', 'cost', 'coast', 'cosh', 'koss', 'chaos', 'kaos',
    'course', 'cose', 'kose', 'cuz', 'cus', 'cs', 'coss', 'close', 'cross',
    'cos', 'coz', 'kaz', 'cas',
  };
  static const Set<String> _rLike = {
    'are', 'our', 'ar', 'arr', 'hour', 'or', 'art', 'aar', 'err', 'ah',
    'her', 'hr', 'rr', 'report', 'repeater', 'reap', 'repeal', 'hours',
    'ours', 'arh',
  };

  /// Mis-heard command words → the word that was meant.
  static const Map<String, String> _misheardWords = {
    'accept': 'except', 'expect': 'except', 'exempt': 'except',
    'excep': 'except', 'exept': 'except', 'axcept': 'except',
    'true': 'through', 'threw': 'through', 'thro': 'through',
    'ol': 'all', 'awl': 'all', 'aul': 'all', 'oll': 'all',
    'everyone': 'all', 'everybody': 'all',
    'remain': 'remaining', 'remainder': 'remaining', 'remainin': 'remaining',
    'unanswer': 'unanswered', 'unanswerd': 'unanswered',
    'sections': 'section',
  };

  /// Longer words checked by spelling distance.
  static const List<String> _fuzzyTargets = [
    'except', 'remaining', 'unanswered', 'through', 'repeat', 'corrected',
    'question', 'questions', 'section', 'everything',
  ];

  /// Harmless words: never guessed as something else.
  static const Set<String> _softWords = {
    'with', 'and', 'plus', 'also', 'then', 'the', 'a', 'an', 'it', 'its',
    'is', 'as', 'be', 'been', 'should', 'would', 'will', 'please', 'ok',
    'okay', 'set', 'mark', 'marked', 'make', 'change', 'put', 'select',
    'selected', 'tick', 'choose', 'pick', 'give', 'enter', 'from', 'of',
    'on', 'this', 'that', 'these', 'those', 'them', 'they', 'one', 'ones',
    'same', 'both', 'for', 'i', 'me', 'my', 'you', 'we', 'just', 'so',
    'yes', 'yeah', 's', 'th', 'st', 'nd', 'rd', 'answer', 'answers',
    'result', 'results', 'at', 'by', 'in', 'into', 'instead', 'now', 'go',
    'let', 'lets', 'us', 'do', 'want', 'need', 'can', 'could', 'hey',
    'quincy', 'thanks', 'thank', 'up', 'down', 'here', 'there',
  };

  static const Map<String, int> _units = {
    'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
    'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10, 'eleven': 11,
    'twelve': 12, 'thirteen': 13, 'fourteen': 14, 'fifteen': 15,
    'sixteen': 16, 'seventeen': 17, 'eighteen': 18, 'nineteen': 19,
  };

  static const Map<String, int> _tens = {
    'twenty': 20, 'thirty': 30, 'forty': 40, 'fourty': 40, 'fifty': 50,
    'sixty': 60, 'seventy': 70, 'eighty': 80, 'ninety': 90,
  };

  static const Map<String, int> _ordinals = {
    'first': 1, 'second': 2, 'third': 3, 'fourth': 4, 'forth': 4,
    'fifth': 5, 'sixth': 6, 'seventh': 7, 'eighth': 8, 'ninth': 9,
    'tenth': 10, 'eleventh': 11, 'twelfth': 12, 'thirteenth': 13,
    'fourteenth': 14, 'fifteenth': 15, 'sixteenth': 16, 'seventeenth': 17,
    'eighteenth': 18, 'nineteenth': 19, 'twentieth': 20, 'thirtieth': 30,
    'fortieth': 40, 'fiftieth': 50,
  };

  /// Speech-to-text homophones, only used right after "question"/"item"
  /// (or "… 2 and for").
  static const Map<String, int> _homophones = {
    'to': 2, 'too': 2, 'for': 4, 'fore': 4, 'won': 1, 'ate': 8, 'tree': 3,
    'free': 3, 'fife': 5, 'sicks': 6, 'nein': 9,
  };

  /// "twenty for" → 24 ("to" / "too" left out: "twenty to thirty").
  static const Map<String, int> _tensHomophones = {
    'for': 4, 'fore': 4, 'won': 1, 'ate': 8, 'tree': 3, 'free': 3,
  };

  // ---------------- Smart fix (raw text, before anything else) -----------

  static const Map<String, String> _questionMisheard = {
    'quest': 'question', 'questin': 'question', 'qestion': 'question',
    'quesion': 'question', 'quetion': 'question', 'questoin': 'question',
    'kwestion': 'question', 'kweschun': 'question', 'kwestin': 'question',
    'westion': 'question', 'cushion': 'question', 'caution': 'question',
    'quiz': 'question', 'cue': 'question', 'queue': 'question',
    'kyu': 'question', 'ques': 'question', 'qn': 'question',
    'que': 'question', 'questionnaire': 'question', 'kushan': 'question',
    'atom': 'item', 'adam': 'item', 'idem': 'item', 'itam': 'item',
    'iten': 'item', 'itme': 'item', 'itum': 'item', 'eitem': 'item',
    'aitem': 'item', 'autumn': 'item', 'idam': 'item', 'itemm': 'item',
    'atoms': 'items', 'idems': 'items',
  };

  static const Set<String> _exactQuestion = {
    'question', 'questions', 'item', 'items', 'q',
  };

  static const Set<String> _exactComment = {
    'comment', 'comments', 'note', 'notes', 'remark', 'remarks',
    'commant', 'coment', 'comnent', 'commend',
  };

  static const Set<String> _commentMisheard = {
    'commends', 'comet', 'comets', 'commit', 'commits', 'command',
    'commands', 'common', 'cement', 'comma', 'commas', 'kament', 'kommen',
    'comin', 'commen', 'commented', 'commenting', 'commentary', 'komment',
    'camment', 'cumment', 'kommand', 'commant', 'commint', 'comand',
  };

  static const Set<String> _notComment = {
    'content', 'contents', 'connect', 'connects', 'correct', 'current',
    'comply', 'compliance', 'compliant', 'commission', 'complete',
    'comment', 'compost',
  };

  static const Set<String> _commentVerbs = {
    'add', 'set', 'write', 'put', 'make', 'give', 'enter', 'type',
    'update', 'change', 'clear', 'remove', 'delete', 'erase', 'append',
    'the', 'a', 'an', 'my', 'new', 'also',
  };

  static final RegExp _wordRe = RegExp(r"[A-Za-z][A-Za-z']*");

  static final RegExp _numberAhead = RegExp(
    r'^\s*(?:no\.?\s*|number\s*|num\.?\s*|#\s*)?'
    r'(?:\d|(?:zero|one|two|three|four|five|six|seven|eight|nine|ten|eleven'
    r'|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen'
    r'|nineteen|twenty|thirty|forty|fourty|fifty|sixty|seventy|eighty'
    r'|ninety|for|fore|won|ate|tree|free|first|second|third|fourth'
    r'|forth|fifth)\b)',
    caseSensitive: false,
  );

  static final RegExp _numberNear = RegExp(
    r'\d|\b(?:questions?|items?|q|one|two|three|four|five|six|seven|eight'
    r'|nine|ten|eleven|twelve|twenty|thirty|forty)\b',
    caseSensitive: false,
  );

  static final RegExp _forQuestionAhead = RegExp(
    r'^\s*(?:for|on|to|in|of|at|from)\s+(?:questions?|items?|q)\b',
    caseSensitive: false,
  );

  static final List<MapEntry<RegExp, String>> _phraseFixes = [
    MapEntry(
      RegExp(
          r'\b(?:not|note|nod|knot|no)\s+(?:observ\w*|obse\w*|obzerv\w*'
          r'|deserved|reserved)',
          caseSensitive: false),
      'not observed',
    ),
    MapEntry(
      RegExp(r'\b(?:not|non|none|nod|knot|note)[\s-]*(?:a?pp?li\w*|aplica\w*)',
          caseSensitive: false),
      'not applicable',
    ),
    MapEntry(RegExp(r'\binapplicable\b', caseSensitive: false),
        'not applicable'),
    MapEntry(
      RegExp(
          r'\bcorrect(?:ed|ion|ive|s)?(?:\s+it)?\s+(?:on|at|in)\s*(?:the\s+)?'
          r'(?:site|sight|cite|side|spot|sit|set)\b',
          caseSensitive: false),
      'corrected on site',
    ),
    MapEntry(RegExp(r'\bcorrect(?:ed)?\s+onsite\b', caseSensitive: false),
        'corrected on site'),
    MapEntry(
      RegExp(r'\b(?:see|sea|c)[\s.]*(?:oh|o)[\s.]*(?:es|ess|s)\b\.?',
          caseSensitive: false),
      'COS',
    ),
    MapEntry(
      RegExp(
          r'\b(?:re\s+peat\w*|repit|ripit|ripeat|repeet|repete|ri\s+peat)\b',
          caseSensitive: false),
      'repeat',
    ),
  ];

  // ---------------- Comment patterns ----------------

  static const String _numWord =
      r'(?:\d+|(?:twenty|thirty|forty|fourty|fifty|sixty|seventy|eighty|ninety)'
      r'(?:[\s-]+(?:one|two|three|four|five|six|seven|eight|nine))?'
      r'|zero|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve'
      r'|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen'
      r'|won|ate)';

  static const String _qPrefix =
      r'(?:questions?|items?|q)\s*(?:no\.?\s*|number\s*|num\.?\s*|#\s*)?';

  /// Start of "question 5" – used to cut the sentence into clauses.
  static final RegExp _qMarker =
      RegExp('\\b$_qPrefix$_numWord\\b', caseSensitive: false);

  static final RegExp _commentKw = RegExp(
    r'\b(?:comments?|commant|coment|comnent|commend|notes?|remarks?)\b',
    caseSensitive: false,
  );

  /// "add a comment for question 5 …" / "clear comment from question 5"
  /// → "question 5 [clear] comment …"
  static final RegExp _commentFor = RegExp(
    r'\b(?:(clear|remove|delete|erase|reset)\s+|'
    r'(?:add|set|write|put|make|give|enter|type|update|change)\s+)?'
    r'(?:(?:a|an|the|my)\s+)?'
    r'(comments?|commant|coment|comnent|commend|notes?|remarks?)\s+'
    r'(?:for|on|to|in|of|at|from)\s+'
    '($_qPrefix$_numWord)\\b',
    caseSensitive: false,
  );

  static final RegExp _clearBefore = RegExp(
    r'\b(?:clear|remove|delete|erase|reset)\b[\s,]*(?:(?:the|a|my)\s+)?$',
    caseSensitive: false,
  );

  /// Marker word placed after each comment clause (ends a group).
  static const String _clauseBreak = 'qqclausebreak';

  static final RegExp _appendBefore =
      RegExp(r'\b(?:append|also|add more|add to)\b', caseSensitive: false);

  static final RegExp _cancelComment = RegExp(
    r'^\W*(?:no|nope|cancel|never\s*mind|nevermind|no comment|skip(?: it)?'
    r'|forget it|nothing|leave it(?: empty| blank)?|stop)\W*$',
    caseSensitive: false,
  );

  // ---------------- Public API ----------------

  /// True when the sentence talks about a question / item / comment, even
  /// if the speech engine mis-heard the word ("kwestion 4 out").
  static bool mentionsItem(String text) => RegExp(
        r'\b(?:questions?|items?|q|comments?|notes?)\b',
        caseSensitive: false,
      ).hasMatch(_smartFix(text));

  /// Returns null when the sentence is not about questions / comments,
  /// so other voice commands can handle it.
  static VoiceItemParseResult? parse(
    String text, {
    VoiceItemContext? context,
  }) {
    final max = context?.maxNumber ?? 0;
    final recent = context?.recentNumbers ?? const <int>[];
    final warnings = <String>[];
    final assumptions = <String>[];

    // 0) Fix mis-heard keywords ("kwestion" → question, "commend" → comment)
    final fixed = _smartFix(text);

    // 0.5) The AI asked for comment text – this sentence is the comment.
    final waiting = context?.awaitingCommentFor ?? const <int>[];
    if (waiting.isNotEmpty) {
      final reply = _commentReply(text, fixed, waiting, max);
      if (reply != null) return reply;
    }

    // Numbers that are not on the form
    final validSet = context?.allNumbers.toSet() ?? const <int>{};
    final badNums = <int>{};
    int? fixNum(int n) {
      if (validSet.isEmpty || validSet.contains(n)) return n;
      // "forty" vs "fourteen", "thirty" vs "thirteen" …
      if (n >= 30 && n <= 90 && n % 10 == 0) {
        final teen = n ~/ 10 + 10;
        if (validSet.contains(teen)) {
          assumptions.add('I took $n as $teen, because there is no '
              'question $n.');
          return teen;
        }
      }
      badNums.add(n);
      return null;
    }

    List<int> fixAll(Iterable<int> nums) =>
        nums.map(fixNum).whereType<int>().toList();

    List<String> allWarnings() {
      final out = <String>[];
      if (badNums.isNotEmpty) {
        final spoken = numbersSpoken(badNums);
        out.add('${spoken[0].toUpperCase()}${spoken.substring(1)} '
            '${badNums.length == 1 ? 'is' : 'are'} not on this form'
            '${max > 0 ? '. The last question is $max' : ''}.');
      }
      out.addAll(warnings);
      return out.toSet().toList();
    }

    // 1) Comments first – their text must not be read as IN / OUT / NO …
    final split = _extractComments(fixed, max, warnings, recent);
    final comments = <VoiceItemComment>[];
    for (final c in split.comments) {
      final n = fixNum(c.number);
      if (n != null) {
        comments.add(VoiceItemComment(number: n, text: c.text, mode: c.mode));
      }
    }
    final commentNeeded = fixAll(split.handledNums).toSet().toList()..sort();
    final commentNums = {
      ...comments.map((c) => c.number),
      ...commentNeeded,
    };

    // 2) Results
    final tokens = _tokens(split.remaining, max);
    bool isNum(int j) =>
        j >= 0 && j < tokens.length && int.tryParse(tokens[j]) != null;

    final groups = <_Group>[];
    final orphans = <_Group>[]; // a result with no question number
    final codeTokens = <String>[];
    var cur = _Group();
    var rangeNext = false;
    var correcting = false;
    var sawKeyword = split.comments.isNotEmpty;
    var asksQuestion = false;

    void endExcept() {
      if (cur.exceptMode && cur.exceptNums.isNotEmpty) {
        cur.excluded.addAll(cur.exceptNums);
        cur.exceptNums.clear();
        cur.exceptMode = false;
      }
    }

    void push() {
      if (cur.exceptMode) {
        cur.excluded.addAll(cur.exceptNums);
        cur.exceptNums.clear();
        cur.exceptMode = false;
      }
      if (cur.hasTarget) {
        groups.add(cur);
      } else if (cur.hasCode) {
        orphans.add(cur);
      }
      cur = _Group();
    }

    /// A word the speech engine probably got wrong → the word meant.
    String? guess(int i) {
      final w = tokens[i];
      final prev = i > 0 ? tokens[i - 1] : '';
      final next = i + 1 < tokens.length ? tokens[i + 1] : '';
      final atEnd = next.isEmpty || next == _clauseBreak;
      final afterNum = isNum(i - 1);
      final inGroup = cur.nums.isNotEmpty && !cur.exceptMode;
      final flagSpot =
          !cur.exceptMode && (cur.hasOut || prev == 'with' || prev == 'plus');

      // "question 5 and" / "question 5 not" at the very end
      if (afterNum && atEnd && !cur.hasCode) {
        if (w == 'and' || w == 'end' || w == 'an' || w == 'ann') return 'in';
        if (w == 'not') return 'no';
      }
      if (_softWords.contains(w) && !_rLike.contains(w)) return null;

      if (_rLike.contains(w) &&
          (flagSpot || (afterNum && !cur.hasCode && atEnd))) {
        return 'r';
      }
      if (_cosLike.contains(w) && (inGroup || flagSpot)) return 'cos';
      if (inGroup) {
        if (_outLike.contains(w)) return 'out';
        if (_inLike.contains(w)) return 'in';
        if (_noLike.contains(w)) return 'no';
        if (_naLike.contains(w)) return 'na';
      }

      var canon = _misheardWords[w];
      if (canon == null && w.length >= 5 && int.tryParse(w) == null) {
        var best = 99;
        for (final v in _fuzzyTargets) {
          final limit = v.length >= 8 ? 2 : 1;
          final d = _lev(w, v);
          if (d <= limit && d < best) {
            best = d;
            canon = v;
          }
        }
      }
      if (canon == null) return null;
      switch (canon) {
        case 'except':
          return cur.hasTarget ? 'except' : null;
        case 'through':
          return isNum(i - 1) && isNum(i + 1) ? 'through' : null;
        case 'question':
        case 'questions':
          return isNum(i + 1) ? 'question' : null;
        case 'repeat':
          return (flagSpot || afterNum) ? 'repeat' : null;
        case 'corrected':
          return (inGroup || flagSpot) ? 'corrected' : null;
        case 'all':
          return (_codeWords.containsKey(next) ||
                  _questionWords.contains(next) ||
                  next == 'the')
              ? 'all'
              : null;
        default:
          return canon; // remaining, unanswered, section, everything
      }
    }

    for (var i = 0; i < tokens.length; i++) {
      final w = tokens[i];
      final n = int.tryParse(w);
      final next = i + 1 < tokens.length ? tokens[i + 1] : '';

      // ---- Number ----
      if (n != null) {
        if (cur.exceptMode) {
          if (rangeNext && cur.exceptNums.isNotEmpty) {
            _addRange(cur.exceptNums, n);
          } else {
            cur.exceptNums.add(n);
          }
          rangeNext = false;
          continue;
        }
        if (rangeNext && cur.nums.isNotEmpty) {
          _addRange(cur.nums, n);
          rangeNext = false;
          continue;
        }
        rangeNext = false;
        // "question 4 sorry 5 IN" / "question 4 IN sorry 5" → 5 replaces 4
        if (correcting && cur.nums.isNotEmpty) {
          cur.nums
            ..clear()
            ..add(n);
          cur.excluded.clear();
          correcting = false;
          continue;
        }
        correcting = false;
        // Previous group is complete ("3 in | 4 out") → start a new one
        if (cur.hasCode && cur.hasTarget) push();
        cur.nums.add(n);
        continue;
      }

      // ---- "5 and a" / "5 in a" → NA ----
      if ((w == 'and' || w == 'in' || w == 'an' || w == 'n') &&
          next == 'a' &&
          isNum(i - 1) &&
          !cur.hasCode) {
        tokens[i] = 'na';
        tokens[i + 1] = 'and';
        i--;
        continue;
      }

      // ---- "1 to 8" ----
      if (_rangeWords.contains(w)) {
        final list = cur.exceptMode ? cur.exceptNums : cur.nums;
        if (list.isNotEmpty &&
            (cur.exceptMode || !cur.hasCode) &&
            (isNum(i + 1) || _questionWords.contains(next))) {
          rangeNext = true;
        }
        continue;
      }

      // ---- "except 4 and 7" / "but 4 OUT" ----
      if (_exceptWords.contains(w)) {
        if (cur.hasTarget) cur.exceptMode = true;
        continue;
      }
      if (w == 'but') {
        if (cur.hasTarget &&
            (isNum(i + 1) || next == 'not' || _questionWords.contains(next))) {
          cur.exceptMode = true;
        }
        continue;
      }

      // ---- "sorry", "actually", "I mean" ----
      if (_correctionWords.contains(w)) {
        correcting = true;
        rangeNext = false;
        continue;
      }

      // ---- "all" / "remaining" ----
      final scope = _scopeWords[w];
      if (scope != null) {
        if (cur.exceptMode) continue;
        if (cur.hasCode && cur.hasTarget) push();
        if (cur.nums.isEmpty) {
          cur.scope = scope;
          sawKeyword = true;
        }
        continue;
      }
      if (w == 'section' || w == 'sections' || w == 'tab' || w == 'page') {
        cur.sectionOnly = true;
        continue;
      }

      if (w == _clauseBreak) {
        rangeNext = false;
        correcting = false;
        push();
        continue;
      }

      if (_questionWords.contains(w)) {
        sawKeyword = true;
        endExcept(); // "… except 4, question 5 OUT"
        continue;
      }

      if (_queryWords.contains(w)) {
        asksQuestion = true;
        continue;
      }

      if (_clearWords.contains(w)) {
        if (cur.hasCode && cur.hasTarget) push();
        cur.clear = true;
        continue;
      }

      final code = _codeWords[w];
      if (code != null) {
        // "question no 4" → "no" means "number", not NO.
        // But "question 3 no" / "3 no 4 in" → NO for question 3.
        if (w == 'no' &&
            isNum(i + 1) &&
            !cur.exceptMode &&
            (cur.nums.isEmpty || cur.hasCode)) {
          sawKeyword = true;
          continue;
        }

        // "question 4 IN, no, OUT" → "no" corrects the answer
        // (but "1 2 3 IN NO NA" still pairs NO with question 2).
        if (w == 'no' &&
            cur.codes.isNotEmpty &&
            cur.codes.length >= cur.nums.length &&
            _codeWords.containsKey(next) &&
            next != 'no') {
          correcting = true;
          continue;
        }

        // "1 to 10 IN but 4 OUT" → 4 leaves this group and gets OUT
        if (cur.exceptMode) {
          if (cur.exceptNums.isNotEmpty) {
            final moved = List<int>.from(cur.exceptNums);
            cur.excluded.addAll(moved);
            cur.exceptNums.clear();
            cur.exceptMode = false;
            groups.add(cur);
            cur = _Group()..nums.addAll(moved);
          } else {
            cur.exceptMode = false;
          }
        }

        rangeNext = false;
        codeTokens.add(w);
        if (code == 'COS' || code == 'R') {
          if (correcting && cur.codes.isNotEmpty) {
            cur.codes.last
              ..cos = false
              ..repeat = false;
          }
          cur.addFlag(code);
        } else {
          if (correcting) cur.codes.clear();
          cur.addResult(code);
        }
        correcting = false;
        continue;
      }

      // ---- A word the speech engine probably got wrong ----
      final g = guess(i);
      if (g != null && g != w) {
        final meant = _codeWords[g];
        if (meant != null) {
          assumptions.add('I heard "$w" as ${_codeSpoken(meant)}.');
        }
        tokens[i] = g;
        i--; // handle the corrected word
        continue;
      }
      // anything else ("select", "mark", "with", "and", "please") is ignored
    }
    push();

    // Numbers must exist on the form ("forty" → 14 when there is no 40)
    for (final g in groups) {
      final ok = fixAll(g.nums);
      g.nums
        ..clear()
        ..addAll(ok);
    }
    groups.removeWhere((g) => !g.hasTarget);

    // ---- "OUT with R" with no number → the questions just talked about
    if (orphans.isNotEmpty) {
      // A lone "no" is usually an answer to a yes/no question, not NO.
      final onlyNo =
          codeTokens.isNotEmpty && codeTokens.every((t) => t == 'no');
      if (groups.isEmpty &&
          recent.isNotEmpty &&
          !onlyNo &&
          !asksQuestion &&
          _looksLikeCommand(tokens)) {
        for (final o in orphans) {
          o.nums.addAll(recent);
          groups.add(o);
        }
      } else if (sawKeyword && !asksQuestion) {
        for (final o in orphans) {
          final label = o.clear ? 'cleared' : _codeLabel(o.codes.last);
          warnings.add('Which question should be $label? '
              'Say, for example, question 4 $label.');
        }
      }
    }

    final anyCode = groups.any((g) => g.hasCode);

    // ---- "what is question 4" ----
    if (asksQuestion && !anyCode) {
      final q = groups.expand((g) => g.nums).toSet().toList()..sort();
      if (q.isNotEmpty || comments.isNotEmpty) {
        return VoiceItemParseResult(
          answers: const [],
          comments: comments,
          queryNumbers: q,
          missingResult: const [],
          warnings: allWarnings(),
          commentNeeded: commentNeeded,
          assumptions: assumptions.toSet().toList(),
        );
      }
    }

    if (groups.isEmpty &&
        comments.isEmpty &&
        commentNeeded.isEmpty &&
        warnings.isEmpty &&
        badNums.isEmpty) {
      return null;
    }
    if (!sawKeyword &&
        !anyCode &&
        comments.isEmpty &&
        warnings.isEmpty &&
        badNums.isEmpty) {
      return null; // just numbers, not for us
    }

    // Numbers said explicitly with a result ("question 4 OUT, all others IN")
    final explicit = <int>{
      for (final g in groups)
        if (g.hasCode && g.scope == null)
          ...g.nums.where((n) => !g.excluded.contains(n)),
    };

    final answers = <VoiceItemAnswer>[];
    final missing = <int>[];

    for (final g in groups) {
      if (!g.hasCode) {
        missing.addAll(g.nums.where((n) => !g.excluded.contains(n)));
        continue;
      }

      // ---- Which questions ----
      List<int> targets;
      if (g.scope == null) {
        targets = g.nums.where((n) => !g.excluded.contains(n)).toList();
      } else {
        if (context == null) {
          warnings.add("I can't use all or remaining here.");
          continue;
        }
        final base =
            g.sectionOnly ? context.sectionNumbers : context.allNumbers;
        targets = base
            .where((n) => !g.excluded.contains(n) && !explicit.contains(n))
            .where((n) =>
                g.scope != _Scope.unanswered || !context.answered.contains(n))
            .toList();
        if (targets.isEmpty) {
          warnings.add(g.scope == _Scope.unanswered
              ? 'There are no unanswered questions${g.sectionOnly ? ' in this section' : ''}.'
              : 'There are no questions to change.');
          continue;
        }
      }
      if (targets.isEmpty) continue;

      // ---- clear / remove ----
      if (g.clear) {
        final flagsOnly = g.codes.isNotEmpty &&
            g.codes.every((c) => c.result == null) &&
            g.codes.any((c) => c.cos || c.repeat);
        final cos = g.codes.any((c) => c.cos);
        final repeat = g.codes.any((c) => c.repeat);
        for (final n in targets) {
          answers.add(VoiceItemAnswer(
            number: n,
            action:
                flagsOnly ? VoiceItemAction.removeFlags : VoiceItemAction.clear,
            cos: flagsOnly && cos,
            repeat: flagsOnly && repeat,
          ));
        }
        continue;
      }

      // ---- "items 1 2 5 7 IN OUT NO NA" → one answer each, in order ----
      if (g.codes.length > 1 &&
          g.scope == null &&
          g.codes.length == targets.length) {
        for (var k = 0; k < targets.length; k++) {
          final r = _resolve(g.codes[k], [targets[k]], warnings);
          answers.add(VoiceItemAnswer(
            number: targets[k],
            action: VoiceItemAction.set,
            result: r.result,
            cos: r.cos,
            repeat: r.repeat,
          ));
        }
        continue;
      }

      if (g.codes.length > 1 && targets.length > 1) {
        warnings.add('I heard ${g.codes.length} answers for '
            '${targets.length} questions, so I used '
            '${_codeLabel(g.codes.last)} for all of them.');
      }

      final r = _resolve(g.codes.last, targets, warnings);
      for (final n in targets) {
        answers.add(VoiceItemAnswer(
          number: n,
          action: VoiceItemAction.set,
          result: r.result,
          cos: r.cos,
          repeat: r.repeat,
        ));
      }
    }

    // A number that only got a comment is not "missing a result"
    missing.removeWhere(commentNums.contains);

    final result = VoiceItemParseResult(
      answers: answers,
      comments: comments,
      queryNumbers: const [],
      missingResult: missing.toSet().toList()..sort(),
      warnings: allWarnings(),
      commentNeeded: commentNeeded,
      assumptions: assumptions.toSet().toList(),
    );
    return result.isEmpty ? null : result;
  }

  /// [1,2,3,4,7] → "questions 1 to 4 and 7"
  static String numbersSpoken(Iterable<int> nums) {
    final sorted = nums.toSet().toList()..sort();
    if (sorted.isEmpty) return '';
    final parts = <String>[];
    var start = sorted.first;
    var prev = start;
    void flush() {
      if (prev - start >= 2) {
        parts.add('$start to $prev');
      } else if (prev == start) {
        parts.add('$start');
      } else {
        parts
          ..add('$start')
          ..add('$prev');
      }
    }

    for (final n in sorted.skip(1)) {
      if (n == prev + 1) {
        prev = n;
        continue;
      }
      flush();
      start = n;
      prev = n;
    }
    flush();

    final label = sorted.length == 1 ? 'question' : 'questions';
    final joined = parts.length == 1
        ? parts.first
        : '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
    return '$label $joined';
  }

  // ---------------- Results helpers ----------------

  static _Resolved _resolve(
    _Code c,
    List<int> targets,
    List<String> warnings,
  ) {
    var result = c.result;
    var cos = c.cos;
    var repeat = c.repeat;

    // COS and R can't both be on → keep the one said last
    if (cos && repeat) {
      if (c.lastFlag == 'COS') {
        repeat = false;
      } else {
        cos = false;
      }
      warnings.add("COS and R can't both be selected, so I used "
          '${cos ? 'corrected on site' : 'repeat'}.');
    }

    // "question 4 COS" → OUT + COS
    if ((cos || repeat) && result == null) result = 'OUT';

    // "question 4 IN with COS" → COS / R only go with OUT
    if ((cos || repeat) && result != 'OUT') {
      warnings.add('Corrected on site and repeat only go with OUT, '
          'so I left them off for ${numbersSpoken(targets)}.');
      cos = false;
      repeat = false;
    }
    return _Resolved(result ?? 'OUT', cos, repeat);
  }

  static String _codeSpoken(String code) {
    switch (code) {
      case 'NO':
        return 'not observed';
      case 'NA':
        return 'not applicable';
      case 'COS':
        return 'corrected on site';
      case 'R':
        return 'repeat';
      default:
        return code;
    }
  }

  static String _codeLabel(_Code c) {
    final base = _codeSpoken(c.result ?? 'OUT');
    if (c.cos) return '$base, corrected on site';
    if (c.repeat) return '$base with repeat';
    return base;
  }

  /// Every word is a result / filler / number – a short command such as
  /// "OUT with R", "make it NA", "clear it".
  static bool _looksLikeCommand(List<String> tokens) {
    var hasAction = false;
    for (final t in tokens) {
      if (_codeWords.containsKey(t) ||
          _scopeWords.containsKey(t) ||
          _clearWords.contains(t)) {
        hasAction = true;
        continue;
      }
      if (_softWords.contains(t) ||
          _correctionWords.contains(t) ||
          _questionWords.contains(t) ||
          _rangeWords.contains(t) ||
          _exceptWords.contains(t) ||
          t == 'but' ||
          t == 'section' ||
          t == _clauseBreak ||
          int.tryParse(t) != null) {
        continue;
      }
      return false;
    }
    return hasAction;
  }

  // ---------------- Smart fix ----------------

  /// Fixes mis-heard keywords in the raw sentence. Comment text after a
  /// comment keyword is left as spoken.
  static String _smartFix(String raw) {
    var t = raw;
    for (final e in _phraseFixes) {
      t = t.replaceAll(e.key, e.value);
    }

    final words = _wordRe.allMatches(t).toList();
    final out = StringBuffer();
    var last = 0;
    var inBody = false;

    for (var k = 0; k < words.length; k++) {
      final m = words[k];
      final w = m[0]!.toLowerCase().replaceAll("'s", '').replaceAll("'", '');
      final numberNext = _numberAhead.hasMatch(t.substring(m.end));
      String? rep;

      if (_exactQuestion.contains(w)) {
        if (numberNext) inBody = false; // next clause starts
      } else if (numberNext && _soundsLikeQuestion(w) != null) {
        rep = _soundsLikeQuestion(w);
        inBody = false;
      } else if (!inBody) {
        if (_exactComment.contains(w)) {
          inBody = true;
        } else if (_soundsLikeComment(w) && _commentGuard(t, words, k)) {
          rep = 'comment';
          inBody = true;
        }
      }

      if (rep != null) {
        out
          ..write(t.substring(last, m.start))
          ..write(rep);
        last = m.end;
      }
    }
    out.write(t.substring(last));
    return out.toString();
  }

  static String? _soundsLikeQuestion(String w) {
    final known = _questionMisheard[w];
    if (known != null) return known;
    if (w.length >= 5 &&
        w.length <= 11 &&
        'qkcw'.contains(w[0]) &&
        (_lev(w, 'question') <= 2 || _lev(w, 'questions') <= 2)) {
      return 'question';
    }
    if (w.length >= 3 && w.length <= 6) {
      if (_lev(w, 'item') <= 1 && w != 'its') return 'item';
      if (_lev(w, 'items') <= 1) return 'items';
    }
    return null;
  }

  static bool _soundsLikeComment(String w) {
    if (_notComment.contains(w)) return false;
    if (_commentMisheard.contains(w)) return true;
    return w.length >= 5 &&
        (w[0] == 'c' || w[0] == 'k') &&
        _lev(w, 'comment') <= 2;
  }

  /// A comment-like word only counts as "comment" near a question number,
  /// after "add / set / clear …", or before "for question N".
  static bool _commentGuard(String t, List<RegExpMatch> words, int k) {
    final from = k >= 5 ? words[k - 5].start : 0;
    if (_numberNear.hasMatch(t.substring(from, words[k].start))) return true;
    final prevW = k > 0 ? words[k - 1][0]!.toLowerCase() : '';
    if (_commentVerbs.contains(prevW)) return true;
    return _forQuestionAhead.hasMatch(t.substring(words[k].end));
  }

  /// Spelling distance (number of letters to change).
  static int _lev(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    if ((a.length - b.length).abs() > 3) return 99;
    var prev = List<int>.generate(b.length + 1, (j) => j);
    for (var i = 1; i <= a.length; i++) {
      final row = List<int>.filled(b.length + 1, 0);
      row[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        var v = prev[j] + 1;
        if (row[j - 1] + 1 < v) v = row[j - 1] + 1;
        if (prev[j - 1] + cost < v) v = prev[j - 1] + cost;
        row[j] = v;
      }
      prev = row;
    }
    return prev[b.length];
  }

  // ---------------- Comments ----------------

  /// The AI asked "What should the comment for question 4 say?" and this
  /// sentence is the answer. Returns null when it is a normal command.
  static VoiceItemParseResult? _commentReply(
    String raw,
    String fixed,
    List<int> waiting,
    int max,
  ) {
    if (_qMarker.hasMatch(fixed) || _commentKw.hasMatch(fixed)) return null;
    if (_cancelComment.hasMatch(raw)) {
      return const VoiceItemParseResult(
        answers: [],
        comments: [],
        queryNumbers: [],
        missingResult: [],
        warnings: ['Okay, I did not add a comment.'],
      );
    }
    final toks = _tokens(fixed, max);
    if (toks.isEmpty || _looksLikeCommand(toks)) return null;
    final body = _cleanComment(raw);
    if (body.isEmpty) return null;
    return VoiceItemParseResult(
      answers: const [],
      comments: [
        for (final n in waiting)
          VoiceItemComment(number: n, text: body, mode: VoiceCommentMode.set),
      ],
      queryNumbers: const [],
      missingResult: const [],
      warnings: const [],
    );
  }

  static _CommentSplit _extractComments(
    String raw,
    int max,
    List<String> warnings,
    List<int> recent,
  ) {
    var text = raw;

    // "add a comment for question 5: …" → "question 5 comment …"
    text = text.replaceFirstMapped(
      _commentFor,
      (m) => ' ${m[3]} ${m[1] ?? ''} ${m[2]} ',
    );

    if (!_commentKw.hasMatch(text)) {
      return _CommentSplit(const [], text, const <int>{});
    }

    // Cut into clauses at every "question N"
    final starts = _qMarker
        .allMatches(text)
        .map((m) => m.start)
        .where((s) => s > 0)
        .toList();
    final bounds = [0, ...starts, text.length];

    final comments = <VoiceItemComment>[];
    final handled = <int>{};
    final remaining = StringBuffer();
    var lastNums = List<int>.of(recent); // "comment no soap" → last question

    for (var k = 0; k < bounds.length - 1; k++) {
      final clause = text.substring(bounds[k], bounds[k + 1]);
      final kw = _commentKw.firstMatch(clause);

      if (kw == null) {
        remaining.write(' $clause');
        final n = _numbersIn(clause, max);
        if (n.isNotEmpty) lastNums = n;
        continue;
      }

      var before = clause.substring(0, kw.start);
      final after = clause.substring(kw.end);

      var mode = VoiceCommentMode.set;
      final clearM = _clearBefore.firstMatch(before);
      if (clearM != null) {
        mode = VoiceCommentMode.clear;
        before = before.substring(0, clearM.start);
      } else if (_appendBefore.hasMatch(before)) {
        mode = VoiceCommentMode.append;
        before = before.replaceAll(_appendBefore, ' ');
      }

      var nums = _numbersIn(before, max);
      if (nums.isEmpty) {
        nums = lastNums; // "question 4 OUT. Comment no soap"
      } else {
        lastNums = nums;
      }

      // Results said before the comment ("question 4 OUT with R comment …"),
      // then a break so these numbers don't join the next clause.
      remaining.write(' $before $_clauseBreak ');

      // "clear comment" may be followed by nothing or "for question 4"
      final body = mode == VoiceCommentMode.clear ? '' : _cleanComment(after);

      if (nums.isEmpty) {
        warnings.add('Which question is that comment for? '
            'Say, for example, question 4 comment followed by your text.');
        continue;
      }
      if (mode != VoiceCommentMode.clear && body.isEmpty) {
        handled.addAll(nums);
        warnings.add('What should the comment for ${numbersSpoken(nums)} say?');
        continue;
      }
      for (final n in nums) {
        comments.add(VoiceItemComment(number: n, text: body, mode: mode));
      }
    }

    return _CommentSplit(comments, remaining.toString(), handled);
  }

  /// "is hand sink blocked, please." → "Hand sink blocked"
  static String _cleanComment(String s) {
    var t = s.trim();
    t = t.replaceFirst(RegExp(r'^[\s:;,=\-–—]+'), '');
    final lead = RegExp(
      r'^(?:is|as|was|says|saying|that|reads|should be|to be|set to|to|'
      r'equals?|with|of|for it)\b[\s:;,\-–—]*',
      caseSensitive: false,
    );
    for (var k = 0; k < 2; k++) {
      t = t.replaceFirst(lead, '');
    }
    t = t.replaceFirst(
      RegExp(r'[\s,;:.]*\b(?:please|thank you|thanks)\W*$',
          caseSensitive: false),
      '',
    );
    t = t.replaceFirst(RegExp(r'[\s,;:.]+$'), '').trim();
    if (t.isEmpty) return t;
    return t[0].toUpperCase() + t.substring(1);
  }

  /// Numbers (with ranges) in a piece of text.
  static List<int> _numbersIn(String text, int max) {
    final out = <int>[];
    var range = false;
    for (final w in _tokens(text, max)) {
      final n = int.tryParse(w);
      if (n != null) {
        if (range && out.isNotEmpty) {
          _addRange(out, n);
        } else {
          out.add(n);
        }
        range = false;
      } else if (_rangeWords.contains(w) && out.isNotEmpty) {
        range = true;
      }
    }
    return out;
  }

  static void _addRange(List<int> list, int to) {
    final from = list.last;
    if (to > from && to - from <= 100) {
      for (var k = from + 1; k <= to; k++) {
        list.add(k);
      }
    } else {
      list.add(to);
    }
  }

  // ---------------- Tokens ----------------

  static List<String> _tokens(String text, int max) {
    final words =
        _normalize(text).split(' ').where((w) => w.isNotEmpty).toList();
    final digits = _numbersToDigits(words);
    if (max <= 0) return digits;

    // "12345678" (speech engine glued "1 2 3 … 8") → 1 2 3 … 8
    final out = <String>[];
    for (final t in digits) {
      final n = int.tryParse(t);
      if (n != null && t.length >= 2 && n > max) {
        final parts = _splitRun(t, max);
        if (parts != null) {
          out.addAll(parts.map((e) => '$e'));
          continue;
        }
      }
      out.add(t);
    }
    return out;
  }

  /// Splits glued digits into question numbers that exist on the form:
  ///   "12345678" → 1..8, "891011" → 8, 9, 10, 11, "12" → 1, 2,
  ///   "135" → 1, 3, 5.
  static List<int>? _splitRun(String s, int max) {
    // 1. Counting up by one ("891011")
    for (var firstLen = 1; firstLen <= 2 && firstLen < s.length; firstLen++) {
      final first = int.parse(s.substring(0, firstLen));
      if (first < 1) continue;
      final seq = [first];
      var rest = s.substring(firstLen);
      while (rest.isNotEmpty) {
        final next = '${seq.last + 1}';
        if (!rest.startsWith(next)) break;
        seq.add(seq.last + 1);
        rest = rest.substring(next.length);
      }
      if (rest.isEmpty && seq.length > 1 && seq.last <= max) return seq;
    }
    // 2. Single digits ("135"). Not for two digits: "25" on a 20-question
    //    form is more likely a wrong number than "2 5".
    if (s.length >= 3 && !s.contains('0')) {
      final d = s.split('').map(int.parse).toList();
      if (d.every((x) => x <= max)) return d;
    }
    return null;
  }

  static String _normalize(String text) {
    var t = ' ${text.toLowerCase()} ';

    // "1-8" / "1 – 8" → "1 to 8"
    t = t.replaceAllMapped(
      RegExp(r'(\d+)\s*[-–—]\s*(\d+)'),
      (m) => ' ${m[1]} to ${m[2]} ',
    );

    // Written forms the speech engine may produce
    t = t.replaceAll(RegExp(r'\bn\s*/\s*a\b'), ' na ');
    t = t.replaceAll(RegExp(r'\bn\.\s*a\b\.?'), ' na ');
    t = t.replaceAll(RegExp(r'\bc\.\s*o\.\s*s\b\.?'), ' cos ');

    // "question no. 4", "question number 4", "item # 4" → "question 4"
    t = t.replaceAllMapped(
      RegExp(r'\b(questions?|items?|q)\s*(numbers?|num|nos?)\b\.?'),
      (m) => ' ${m[1]} ',
    );
    t = t.replaceAll('#', ' ');

    // Punctuation → spaces, then split "q1" / "4th" / "1in"
    t = t.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    t = t.replaceAllMapped(RegExp(r'([a-z])(\d)'), (m) => '${m[1]} ${m[2]}');
    t = t.replaceAllMapped(RegExp(r'(\d)([a-z])'), (m) => '${m[1]} ${m[2]}');

    // Phrases → single unambiguous tokens
    t = t.replaceAll(
        RegExp(r'\b(not|non) (applicable|applied)\b'), ' notapplicable ');
    t = t.replaceAll(RegExp(r'\bn a\b'), ' na ');
    t = t.replaceAll(RegExp(r'\bc o s\b'), ' cos ');
    t = t.replaceAll(RegExp(r'\bnot observed?\b'), ' notobserved ');
    t = t.replaceAll(
      RegExp(r'\b(not in compliance|out of compliance|non compliant|'
          r'noncompliant|not compliant)\b'),
      ' outofcompliance ',
    );
    t = t.replaceAll(RegExp(r'\b(in compliance|compliant)\b'), ' incompliance ');
    t = t.replaceAll(
      RegExp(r'\bcorrect(ed|ion|ive)? (it )?(on |at |in )?(the )?'
          r'(site|sight|cite|side|spot|onsite)\b'),
      ' correctedonsite ',
    );
    t = t.replaceAll(RegExp(r'\brepeat(ed)? violations?\b'), ' repeat ');
    t = t.replaceAll(RegExp(r'\bup to\b'), ' upto ');
    t = t.replaceAll(RegExp(r'\bapart from\b'), ' apart ');
    t = t.replaceAll(RegExp(r'\bother than\b'), ' except ');

    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// "twenty one" → "21", "four" → "4", "question for" → "question 4",
  /// "the fourth question" → "the 4 question".
  static List<String> _numbersToDigits(List<String> words) {
    final out = <String>[];
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      final next = i + 1 < words.length ? words[i + 1] : '';

      final tens = _tens[w];
      if (tens != null) {
        var v = tens;
        final u = _units[next] ?? _ordinals[next] ?? _tensHomophones[next];
        if (u != null && u > 0 && u < 10) {
          v += u;
          i++;
        }
        out.add('$v');
        continue;
      }

      final unit = _units[w];
      if (unit != null) {
        out.add('$unit');
        continue;
      }

      final ord = _ordinals[w];
      if (ord != null &&
          !(out.isNotEmpty && out.last == 'a') && // "wait a second"
          ((out.isNotEmpty && _questionWords.contains(out.last)) ||
              _questionWords.contains(next))) {
        out.add('$ord');
        continue;
      }

      final h = _homophones[w];
      if (h != null && out.isNotEmpty) {
        final afterQuestion = _questionWords.contains(out.last);
        final afterAnd = out.last == 'and' &&
            out.length >= 2 &&
            int.tryParse(out[out.length - 2]) != null &&
            w != 'to' &&
            w != 'too';
        if (afterQuestion || afterAnd) {
          out.add('$h');
          continue;
        }
      }

      out.add(w);
    }
    return out;
  }
}

class _Code {
  String? result;
  bool cos = false;
  bool repeat = false;
  String? lastFlag;
}

class _Resolved {
  final String result;
  final bool cos;
  final bool repeat;
  const _Resolved(this.result, this.cos, this.repeat);
}

class _Group {
  final List<int> nums = [];
  final Set<int> excluded = {};
  final List<int> exceptNums = [];
  bool exceptMode = false;

  _Scope? scope;
  bool sectionOnly = false;

  /// Results in the order spoken ("IN OUT NO NA"); COS / R attach to the
  /// result they follow.
  final List<_Code> codes = [];
  bool clear = false;

  void addResult(String r) {
    if (codes.isNotEmpty && codes.last.result == null) {
      codes.last.result = r; // "question 4 R OUT"
    } else {
      codes.add(_Code()..result = r);
    }
  }

  void addFlag(String f) {
    if (codes.isEmpty) codes.add(_Code());
    final c = codes.last;
    if (f == 'COS') {
      c.cos = true;
    } else {
      c.repeat = true;
    }
    c.lastFlag = f;
  }

  bool get hasOut => codes.any((c) => c.result == 'OUT');
  bool get hasCode => codes.isNotEmpty || clear;
  bool get hasTarget => nums.isNotEmpty || scope != null;
}

class _CommentSplit {
  final List<VoiceItemComment> comments;
  final String remaining;

  /// Numbers whose comment text is still being asked for.
  final Set<int> handledNums;

  const _CommentSplit(this.comments, this.remaining, this.handledNums);
}