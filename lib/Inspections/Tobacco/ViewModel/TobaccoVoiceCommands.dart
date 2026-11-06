import 'package:quincy/Inspections/Tobacco/Model/TobaccoInspectionModel.dart';
import 'package:quincy/Inspections/Tobacco/Model/TobaccoSectionModel.dart';
import 'package:quincy/Inspections/Tobacco/ViewModel/TobaccoInspectionViewModel.dart';

/// What the screen must do after speaking the reply.
enum TobaccoVoiceAction { none, previewPdf, submit, closePanel }

class TobaccoVoiceResult {
  final String say;
  final TobaccoVoiceAction action;
  final bool keepListening;
  const TobaccoVoiceResult(this.say,
      {this.action = TobaccoVoiceAction.none, this.keepListening = true});
}

/// AI Guide commands inside a Tobacco inspection.
///
/// Path: lib/Inspections/Tobacco/ViewModel/TobaccoVoiceCommands.dart
///
/// Examples
///   question 5 yes · 5 no · number 7 n a · question 24 B yes · B no
///   question 1 routine inspection · question 2 tobacco shop
///   question 1 other walk in check · question 26 remove 50 dollar fine
///   question 27 John Smith (text question)
///   all yes (every unanswered YES/NO in this section)
///   next · previous · go to signage · final submit · establishment
///   time in now · time out now · person in charge John Smith · owner Mary
///   what's left · progress · read question 5 · preview pdf · submit · stop
class TobaccoVoiceCommands {
  TobaccoVoiceCommands(this.vm);
  final TobaccoInspectionViewModel vm;

  static const help =
      'You can say question 5 yes, 24 B no, or question 1 routine inspection. '
      'Say all yes to answer the rest of this section with yes. '
      'Say next, previous, or go to a section like signage. '
      'On the first tab say time in now, person in charge and a name, then next. '
      'Say what is left, progress, preview PDF, or submit.';

  Future<TobaccoVoiceResult> handle(String raw) async {
    final t = _normalize(raw);
    if (t.isEmpty) return const TobaccoVoiceResult("Sorry, I didn't hear that.");

    if (RegExp(r'^(help|what can i say|commands?)$').hasMatch(t)) {
      return const TobaccoVoiceResult(help);
    }
    if (RegExp(r"^(stop|close|that s all|thats all|done|goodbye|bye)$")
        .hasMatch(t)) {
      return const TobaccoVoiceResult(
          'Okay. Tap AI Guide whenever you need me.',
          action: TobaccoVoiceAction.closePanel,
          keepListening: false);
    }

    // ---- Steps ----
    if (RegExp(r'\b(final submit|final tab|signatures?)\b').hasMatch(t) &&
        !t.startsWith('question')) {
      return _toStep(TobaccoInspectionViewModel.stepFinal);
    }
    if (RegExp(r'\b(inspection form|questions|checklist)\b').hasMatch(t) &&
        !RegExp(r'\d').hasMatch(t)) {
      return _toStep(TobaccoInspectionViewModel.stepForm);
    }
    if (RegExp(r'\bestablishment\b').hasMatch(t) && !t.contains('name')) {
      return _toStep(TobaccoInspectionViewModel.stepEstablishment);
    }
    if (RegExp(r'\b(preview |open |show )?(the )?pdf\b').hasMatch(t)) {
      if (!vm.isSaved) {
        return const TobaccoVoiceResult('Save the Establishment tab first.');
      }
      return const TobaccoVoiceResult('Opening the PDF.',
          action: TobaccoVoiceAction.previewPdf, keepListening: false);
    }
    if (RegExp(r'^(submit|submit (the |my |this )?inspection|send it)$')
        .hasMatch(t)) {
      final problems = vm.validateForSubmit();
      if (problems.isNotEmpty) return TobaccoVoiceResult(problems.join(' '));
      return const TobaccoVoiceResult('Submitting the inspection.',
          action: TobaccoVoiceAction.submit, keepListening: false);
    }

    // ---- Establishment tab ----
    if (vm.step == TobaccoInspectionViewModel.stepEstablishment) {
      final r = await _establishment(t);
      if (r != null) return r;
    }

    // ---- Next / previous ----
    if (RegExp(r'^(next|next section|continue|go next|save and next)$')
        .hasMatch(t)) {
      return _next();
    }
    if (RegExp(r'^(previous|back|go back|previous section)$').hasMatch(t)) {
      return _previous();
    }

    // Nothing below works before the inspection is saved.
    if (!vm.isSaved) {
      return const TobaccoVoiceResult(
          'Fill in the Establishment tab first, then say next.');
    }

    // ---- Progress ----
    if (RegExp(r"\b(what s left|whats left|remaining|unanswered|left to answer)\b")
        .hasMatch(t)) {
      return _whatsLeft();
    }
    if (RegExp(r'\b(progress|how many)\b').hasMatch(t)) {
      final p = vm.overallProgress;
      return TobaccoVoiceResult(
          '${p.answered} of ${p.total} questions are answered.');
    }

    // ---- Read a question ----
    final read = RegExp(r'^(read|repeat|what is) (question |number )?(\d+)$')
        .firstMatch(t);
    if (read != null) return _read(int.parse(read.group(3)!));

    // ---- All yes / no / na in this section ----
    final all = RegExp(r'^(mark |answer |set )?all (yes|no|na)$').firstMatch(t);
    if (all != null) return _all(all.group(2)!);

    // ---- Section by name ----
    final sec = _sectionFromText(t);
    if (sec != null) {
      await vm.goToStep(TobaccoInspectionViewModel.stepForm);
      vm.selectSection(sec);
      return TobaccoVoiceResult('${vm.sections[sec].name} is open.');
    }

    // ---- Answers ----
    final ans = await _answer(t);
    if (ans != null) return ans;

    return const TobaccoVoiceResult(
        "Sorry, I didn't get that. Say question 5 yes, or say help.");
  }

  // ------------------------------------------------------------ steps

  Future<TobaccoVoiceResult> _toStep(int step) async {
    if (step > 0 && !vm.isSaved) {
      return const TobaccoVoiceResult(
          'Fill in the Establishment tab first, then say next.');
    }
    await vm.goToStep(step);
    const names = ['Establishment', 'Inspection Form', 'Final Submit'];
    return TobaccoVoiceResult('${names[step]} is open.');
  }

  Future<TobaccoVoiceResult> _next() async {
    switch (vm.step) {
      case TobaccoInspectionViewModel.stepEstablishment:
        final save = vm.onVoiceSaveEstablishment;
        if (save == null) return const TobaccoVoiceResult('Tap Next to save.');
        final err = await save();
        if (err != null) return TobaccoVoiceResult(err);
        return TobaccoVoiceResult(
            'Saved. ${_sectionIntro()} Say question 1 and your answer.');
      case TobaccoInspectionViewModel.stepForm:
        await vm.nextSection();
        if (vm.step == TobaccoInspectionViewModel.stepFinal) {
          return const TobaccoVoiceResult(
              'Final Submit is open. Please sign, then say submit.');
        }
        return TobaccoVoiceResult(_sectionIntro());
      default:
        return const TobaccoVoiceResult(
            'This is the last step. Say preview PDF or submit.');
    }
  }

  Future<TobaccoVoiceResult> _previous() async {
    switch (vm.step) {
      case TobaccoInspectionViewModel.stepFinal:
        await vm.goToStep(TobaccoInspectionViewModel.stepForm);
        return TobaccoVoiceResult(_sectionIntro());
      case TobaccoInspectionViewModel.stepForm:
        await vm.previousSection();
        if (vm.step == TobaccoInspectionViewModel.stepEstablishment) {
          return const TobaccoVoiceResult('Establishment is open.');
        }
        return TobaccoVoiceResult(_sectionIntro());
      default:
        return const TobaccoVoiceResult('This is the first step.');
    }
  }

  String _sectionIntro() {
    final s = vm.currentSection;
    if (s == null) return '';
    final nums = s.activeItems.map((i) => vm.numbers[i.id]).whereType<int>();
    if (nums.isEmpty) return '${s.name} is open.';
    final first = nums.first, last = nums.last;
    return first == last
        ? '${s.name}, question $first.'
        : '${s.name}, questions $first to $last.';
  }

  // ---------------------------------------------------- establishment

  Future<TobaccoVoiceResult?> _establishment(String t) async {
    final set = vm.onVoiceSetField;
    if (set == null) return null;

    if (RegExp(r'^time in( now)?$').hasMatch(t)) {
      set('time_in', '');
      return const TobaccoVoiceResult('Time in set to now.');
    }
    if (RegExp(r'^time out( now)?$').hasMatch(t)) {
      set('time_out', '');
      return const TobaccoVoiceResult('Time out set to now.');
    }
    if (RegExp(r'^(inspection )?date (is )?today$').hasMatch(t)) {
      set('date_today', '');
      return const TobaccoVoiceResult('Inspection date set to today.');
    }

    const fields = {
      'person in charge': 'person_in_charge',
      'pic': 'person_in_charge',
      'contact name': 'contact',
      'contact': 'contact',
      'owner name': 'owner',
      'owner': 'owner',
      'telephone': 'telephone',
      'phone': 'telephone',
      'address': 'address',
      'establishment name': 'business_name',
      'business name': 'business_name',
    };
    for (final e in fields.entries) {
      final m = RegExp('^${e.key} (is )?(.+)\$').firstMatch(t);
      if (m != null) {
        // Use the original casing of the spoken value when we can.
        final value = _titleCase(m.group(2)!);
        set(e.value, value);
        return TobaccoVoiceResult('${_titleCase(e.key)} set to $value.');
      }
    }
    return null;
  }

  // --------------------------------------------------------- progress

  TobaccoVoiceResult _whatsLeft() {
    final s = vm.currentSection;
    if (vm.step == TobaccoInspectionViewModel.stepForm && s != null) {
      final left = vm.unansweredIn(s);
      if (left.isEmpty) {
        return TobaccoVoiceResult(
            '${s.name} is complete. Say next for the next section.');
      }
      return TobaccoVoiceResult(
          'In ${s.name}, still open: ${_join(left.take(12))}'
          '${left.length > 12 ? ' and ${left.length - 12} more' : ''}.');
    }
    final open = <String>[];
    for (final sec in vm.sections) {
      final n = vm.unansweredIn(sec).length;
      if (n > 0) open.add('${sec.name} $n');
    }
    if (open.isEmpty) return const TobaccoVoiceResult('Everything is answered.');
    return TobaccoVoiceResult('Unanswered: ${_join(open)}.');
  }

  TobaccoVoiceResult _read(int number) {
    final hit = vm.itemByNumber(number);
    if (hit == null) return TobaccoVoiceResult('There is no question $number.');
    final item = hit.item;
    switch (item.kind) {
      case TobaccoItemKind.yesNo:
        final a = vm.answerValue(item.id);
        return TobaccoVoiceResult('Question $number. ${item.name} '
            '${a == null ? 'Not answered yet.' : 'Answer: ${_spoken(a)}.'}');
      case TobaccoItemKind.checkboxes:
        final opts = item.activeChildren.map((c) => c.name);
        return TobaccoVoiceResult(
            'Question $number. ${item.name} Options: ${_join(opts)}.');
      case TobaccoItemKind.text:
        final v = vm.textFor(item.id);
        return TobaccoVoiceResult('Question $number. ${item.name} '
            '${v.isEmpty ? 'Not answered yet.' : 'Answer: $v.'}');
      case TobaccoItemKind.productGroups:
        return TobaccoVoiceResult('Question $number. ${item.name} '
            'Say $number and a letter, for example $number A yes.');
    }
  }

  TobaccoVoiceResult _all(String value) {
    final s = vm.currentSection;
    if (vm.step != TobaccoInspectionViewModel.stepForm || s == null) {
      return const TobaccoVoiceResult('Open a section of the form first.');
    }
    var n = 0;
    void apply(TobaccoItemModel i) {
      if (i.kind != TobaccoItemKind.yesNo || vm.isAnswered(i)) return;
      if (value == TobaccoInspectionAnswerModel.na && !i.hasNa) return;
      vm.setAnswerExact(i, value);
      n++;
    }

    for (final item in s.activeItems) {
      if (item.kind == TobaccoItemKind.productGroups) {
        item.activeChildren.forEach(apply);
      } else {
        apply(item);
      }
    }
    if (n == 0) {
      return const TobaccoVoiceResult('Nothing left to answer that way here.');
    }
    return TobaccoVoiceResult(
        'Marked $n ${n == 1 ? 'question' : 'questions'} ${_spoken(value)}.');
  }

  int? _sectionFromText(String t) {
    final m = RegExp(r'^(open |go to |show )?(section )?(.+?)( section)?$')
        .firstMatch(t);
    if (m == null) return null;
    final words = m.group(3)!;
    if (RegExp(r'\d').hasMatch(words)) return null;
    for (var i = 0; i < vm.sections.length; i++) {
      final name = _normalize(vm.sections[i].name);
      final first = name.split(' ').first;
      if (words == name || (first.length >= 4 && words == first) ||
          (words.length >= 5 && name.startsWith(words))) {
        return i;
      }
    }
    return null;
  }

  // ---------------------------------------------------------- answers

  Future<TobaccoVoiceResult?> _answer(String t) async {
    // "B yes" – letter of the product question in the open section.
    final letterOnly = RegExp(r'^(?:letter |item )?([a-z]+) (yes|no|na)$')
        .firstMatch(t);
    if (letterOnly != null && vm.step == TobaccoInspectionViewModel.stepForm) {
      final product = vm.currentSection?.activeItems
          .where((i) => i.kind == TobaccoItemKind.productGroups)
          .firstOrNull;
      final letter = _letter(letterOnly.group(1)!);
      if (product != null && letter != null) {
        return _answerProduct(product, letter, letterOnly.group(2)!);
      }
    }

    final m = RegExp(r'^(?:question |number |item |q )?(\d+) ?(.*)$')
        .firstMatch(t);
    if (m == null) return null;
    final number = int.parse(m.group(1)!);
    final rest = m.group(2)!.trim();
    final hit = vm.itemByNumber(number);
    if (hit == null) return TobaccoVoiceResult('There is no question $number.');

    // Show where the answer goes.
    if (vm.step != TobaccoInspectionViewModel.stepForm) {
      await vm.goToStep(TobaccoInspectionViewModel.stepForm);
    }
    if (vm.sectionIndex != hit.sectionIndex) vm.selectSection(hit.sectionIndex);

    final item = hit.item;
    if (rest.isEmpty) return _read(number);

    switch (item.kind) {
      case TobaccoItemKind.yesNo:
        final v = _yesNo(rest);
        if (v == null) {
          return TobaccoVoiceResult(
              'For question $number say yes, no${item.hasNa ? ' or N A' : ''}.');
        }
        if (v == TobaccoInspectionAnswerModel.na && !item.hasNa) {
          return TobaccoVoiceResult('Question $number has only yes or no.');
        }
        vm.setAnswerExact(item, v);
        // "question 1 no store closed" → also tick the reason.
        var extra = '';
        if (v == TobaccoInspectionAnswerModel.no &&
            item.activeChildren.isNotEmpty) {
          final reason = _matchOption(item, _afterAnswerWord(rest));
          if (reason != null) {
            vm.setOption(item, reason, true);
            extra = ', ${reason.name}';
          } else {
            extra = '. Reasons: ${_join(item.activeChildren.map((c) => c.name))}';
          }
        }
        return TobaccoVoiceResult('Question $number, ${_spoken(v)}$extra.');

      case TobaccoItemKind.productGroups:
        final parts = rest.split(' ');
        final letter = _letter(parts.first);
        if (letter == null || parts.length < 2) {
          return TobaccoVoiceResult(
              'Say $number, a letter and yes or no. For example $number A yes.');
        }
        return _answerProduct(item, letter, parts.skip(1).join(' '),
            number: number);

      case TobaccoItemKind.checkboxes:
        final remove = RegExp(r'^(remove|uncheck|clear|untick|delete) ')
            .hasMatch(rest);
        final words = remove ? rest.replaceFirst(RegExp(r'^\w+ '), '') : rest;
        final opt = _matchOption(item, words);
        if (opt == null) {
          return TobaccoVoiceResult('Options are '
              '${_join(item.activeChildren.map((c) => c.name))}.');
        }
        vm.setOption(item, opt, !remove);
        if (!remove && opt.isOtherOption) {
          final other = _afterOther(words);
          if (other.isNotEmpty) vm.setTextNow(item.id, _sentence(other));
          return TobaccoVoiceResult(other.isEmpty
              ? 'Question $number, other checked. Say question $number other and the details.'
              : 'Question $number, other: $other.');
        }
        return TobaccoVoiceResult(
            '${remove ? 'Removed' : 'Checked'} ${opt.name} for question $number.');

      case TobaccoItemKind.text:
        final value = _titleCase(rest.replaceFirst(RegExp(r'^is '), ''));
        vm.setTextNow(item.id, value);
        return TobaccoVoiceResult('Question $number, $value.');
    }
  }

  TobaccoVoiceResult _answerProduct(
      TobaccoItemModel product, String letter, String answerWords,
      {int? number}) {
    final n = number ?? vm.numbers[product.id];
    final child = product.activeChildren
        .where((c) => (c.itemLabel ?? '').toUpperCase() == letter)
        .firstOrNull;
    if (child == null) {
      return TobaccoVoiceResult('Question $n has no letter $letter.');
    }
    final v = _yesNo(answerWords);
    if (v == null || (v == TobaccoInspectionAnswerModel.na && !child.hasNa)) {
      return TobaccoVoiceResult('For $n $letter say yes or no.');
    }
    vm.setAnswerExact(child, v);
    return TobaccoVoiceResult('$n $letter, ${child.name}, ${_spoken(v)}.');
  }

  /// Best option for the spoken words (all words must start a word of
  /// the option name; "other" matches the Other option).
  TobaccoItemModel? _matchOption(TobaccoItemModel parent, String words) {
    final w = words.trim();
    if (w.isEmpty) return null;
    final options = parent.activeChildren;
    if (RegExp(r'^other\b').hasMatch(w)) {
      return options.where((o) => o.isOtherOption).firstOrNull;
    }
    final tokens = w
        .split(' ')
        .where((x) => x.isNotEmpty && !const {'a', 'an', 'the', 'of', 'and'}.contains(x))
        .toList();
    if (tokens.isEmpty) return null;

    TobaccoItemModel? best;
    var bestScore = 0;
    for (final o in options) {
      final name = _normalize(o.name);
      if (name == w) return o;
      final nameWords = name.split(' ');
      final score = tokens
          .where((t) => nameWords.any((nw) => nw.startsWith(t) || t.startsWith(nw) && nw.length >= 3))
          .length;
      if (score > bestScore) {
        best = o;
        bestScore = score;
      }
    }
    // Need at least half the spoken words to match.
    return bestScore * 2 >= tokens.length ? best : null;
  }

  // ---------------------------------------------------------- parsing

  static String? _yesNo(String words) {
    final w = ' $words ';
    if (RegExp(r' (n a|na|n slash a|not applicable|non applicable) ').hasMatch(w)) {
      return TobaccoInspectionAnswerModel.na;
    }
    if (RegExp(r' (yes|yeah|yep|yup|yah|affirmative|correct) ').hasMatch(w)) {
      return TobaccoInspectionAnswerModel.yes;
    }
    if (RegExp(r' (no|nope|negative|not) ').hasMatch(w)) {
      return TobaccoInspectionAnswerModel.no;
    }
    return null;
  }

  static String _afterAnswerWord(String rest) =>
      rest.replaceFirst(RegExp(r'^(no|nope|negative|not)\b ?'), '').trim();

  static String _afterOther(String words) =>
      words.replaceFirst(RegExp(r'^other\b ?'), '').trim();

  /// Spoken letter → "A".."X" (speech often writes "be", "see", "are" …).
  static String? _letter(String word) {
    const sounds = {
      'a': 'A', 'eh': 'A', 'b': 'B', 'be': 'B', 'bee': 'B', 'c': 'C',
      'see': 'C', 'sea': 'C', 'd': 'D', 'dee': 'D', 'e': 'E', 'f': 'F',
      'eff': 'F', 'g': 'G', 'gee': 'G', 'h': 'H', 'i': 'I', 'eye': 'I',
      'j': 'J', 'jay': 'J', 'k': 'K', 'kay': 'K', 'l': 'L', 'el': 'L',
      'm': 'M', 'em': 'M', 'n': 'N', 'en': 'N', 'o': 'O', 'oh': 'O',
      'p': 'P', 'pee': 'P', 'q': 'Q', 'cue': 'Q', 'queue': 'Q', 'r': 'R',
      'are': 'R', 's': 'S', 'es': 'S', 't': 'T', 'tee': 'T', 'tea': 'T',
      'u': 'U', 'you': 'U', 'v': 'V', 'vee': 'V', 'w': 'W', 'x': 'X',
      'ex': 'X',
    };
    return sounds[word];
  }

  static String _spoken(String v) => v == TobaccoInspectionAnswerModel.na
      ? 'N A'
      : v == TobaccoInspectionAnswerModel.yes
          ? 'yes'
          : 'no';

  static String _join(Iterable<String> items) {
    final l = items.toList();
    if (l.length <= 1) return l.join();
    return '${l.sublist(0, l.length - 1).join(', ')} and ${l.last}';
  }

  static String _titleCase(String s) => s
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');

  static String _sentence(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static const _units = {
    'zero': 0, 'one': 1, 'two': 2, 'to': 2, 'too': 2, 'three': 3,
    'four': 4, 'for': 4, 'five': 5, 'six': 6, 'seven': 7, 'eight': 8,
    'nine': 9, 'ten': 10, 'eleven': 11, 'twelve': 12, 'thirteen': 13,
    'fourteen': 14, 'fifteen': 15, 'sixteen': 16, 'seventeen': 17,
    'eighteen': 18, 'nineteen': 19,
  };
  static const _tens = {'twenty': 20, 'thirty': 30, 'forty': 40};

  /// Lower-case, no punctuation, "24b" → "24 b", number words → digits
  /// (only right after "question" / "number" so "for" etc. stay words).
  static String _normalize(String s) {
    var t = s
        .toLowerCase()
        .replaceAll('n/a', ' na ')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAllMapped(RegExp(r'(\d)([a-z])\b'), (m) => '${m[1]} ${m[2]}')
        .replaceAll(RegExp(r'\b(please|can you|could you|the answer is|answer)\b'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // "question twenty four yes" → "question 24 yes"
    t = t.replaceAllMapped(
      RegExp(r'\b(question|number|q) ([a-z]+)(?: ([a-z]+))?'),
      (m) {
        final w1 = m[2]!, w2 = m[3];
        final tens = _tens[w1];
        if (tens != null) {
          final u = w2 == null ? null : _units[w2];
          if (u != null && u > 0 && u < 10) return '${m[1]} ${tens + u}';
          return '${m[1]} $tens${w2 == null ? '' : ' $w2'}';
        }
        final u = _units[w1];
        if (u != null) return '${m[1]} $u${w2 == null ? '' : ' $w2'}';
        return m[0]!;
      },
    );
    return t;
  }
}
