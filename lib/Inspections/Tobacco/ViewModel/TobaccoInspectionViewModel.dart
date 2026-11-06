import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:quincy/Inspections/Tobacco/Model/TobaccoInspectionModel.dart';
import 'package:quincy/Inspections/Tobacco/Model/TobaccoPermitModel.dart';
import 'package:quincy/Inspections/Tobacco/Model/TobaccoSectionModel.dart';
import 'package:quincy/API/TobaccoRepository.dart';
import 'package:quincy/Inspections/Tobacco/TobaccoDeps.dart';

enum TobaccoInspectionEntryMode { newInspection, resume }

enum TobaccoSignatureKind { pic, inspector }

/// One Tobacco inspection: Establishment → Inspection Form → Final Submit.
/// Everything is saved to SQLite as the inspector goes, so the inspection
/// survives closing the app and works offline.
///
/// Path: lib/Inspections/Tobacco/ViewModel/TobaccoInspectionViewModel.dart
class TobaccoInspectionViewModel extends ChangeNotifier {
  TobaccoInspectionViewModel({
    this.permit,
    this.permitId,
    this.scheduleId = 0,
    this.inspectionId,
    this.preferredInspectorId,
    this.resume = false,
    TobaccoRepository? repository,
    DBManager? db,
  })  : _repo = repository ?? TobaccoRepository(),
        _db = db ?? DBManager.instance;

  final TobaccoPermitModel? permit;
  final int? permitId;

  /// 0 = normal inspection, otherwise the schedule it was started from.
  final int scheduleId;

  /// Open this saved inspection (resume).
  final String? inspectionId;

  /// e.g. the schedule's inspector.
  final int? preferredInspectorId;

  /// true = opened from Incomplete (load everything saved for
  /// [inspectionId]); false = brand-new inspection with empty answers.
  final bool resume;

  final TobaccoRepository _repo;
  final DBManager _db;

  static const int stepEstablishment = 0;
  static const int stepForm = 1;
  static const int stepFinal = 2;

  /// 4th tab: PDF shown inside the screen.
  static const int stepEmail = 3;

  // ------------------------------------------------------------- State

  TobaccoInspectionModel? inspection;
  TobaccoPermitModel? loadedPermit;

  /// Visible sections only (status 1, with at least one visible item).
  List<TobaccoSectionModel> sections = const [];
  final Map<int, TobaccoInspectionAnswerModel> _answers = {};
  TobaccoFinalSubmitModel? finalSubmit;
  List<TobaccoInspectorOption> inspectors = const [];

  /// Final Submit dropdowns.
  List<TobaccoOperationTypeOption> operationTypes = const [];
  List<String> get purposeOptions => kTobaccoPurposeOptions;

  /// item id → number shown on the form (1, 2, … across all sections).
  final Map<int, int> numbers = {};

  int step = stepEstablishment;
  int sectionIndex = 0;

  bool loading = true;
  bool checklistLoading = false;
  String? error;
  String? checklistError;
  bool submitting = false;

  /// True once the Establishment tab was saved at least once.
  bool isSaved = false;

  String? _fileBaseDir;
  final Map<int, Timer> _textTimers = {};
  bool _disposed = false;

  /// Tab shows a check: Establishment saved / something answered /
  /// a signature on Final Submit (and it isn't the open tab).
  bool isStepDone(int s) {
    if (s == step || !isSaved) return false;
    switch (s) {
      case stepEstablishment:
        return true;
      case stepForm:
        return overallProgress.answered > 0;
      case stepFinal:
        final f = finalSubmit;
        return resolveFile(f?.inspectorSignature) != null ||
            resolveFile(f?.picSignature) != null;
      default:
        return false;
    }
  }

  TobaccoSectionModel? get currentSection =>
      sections.isEmpty ? null : sections[sectionIndex.clamp(0, sections.length - 1)];

  bool get isLastSection => sectionIndex >= sections.length - 1;

  /// Schedule id sent to the API (0 for normal inspections).
  int get submitScheduleId => inspection?.scheduleId ?? scheduleId;

  // -------------------------------------------------------------- Init

  Future<void> init() async {
    loading = true;
    error = null;
    _notify();
    try {
      _fileBaseDir = await _db.tobaccoInspectionFileBaseDir();
      final userId = await _db.getLoggedInUserId() ?? 0;
      inspectors = await _db.getTobaccoInspectorOptions();
      try {
        operationTypes = await _db.getTobaccoOperationTypeOptions();
      } catch (e) {
        debugPrint('⚠️ Tobacco operation types DB error: $e');
      }

      // New → always a fresh inspection (nothing pre-selected).
      // Incomplete → that inspection with all its saved answers.
      TobaccoInspectionModel? ins;
      if (inspectionId != null) {
        ins = await _db.getTobaccoInspectionById(inspectionId!);
      }

      final pid = ins?.permitId ?? permit?.id ?? permitId;
      loadedPermit =
          permit ?? (pid != null ? await _db.getTobaccoPermitById(pid) : null);

      if (ins != null) {
        isSaved = true;
        // Always opens on the first tab; the other tabs are tappable and
        // show what was saved.
        step = stepEstablishment;
        _answers
          ..clear()
          ..addEntries((await _db.getTobaccoAnswers(ins.inspectionId))
              .map((a) => MapEntry(a.itemId, a)));
        finalSubmit = await _db.getTobaccoFinalSubmit(ins.inspectionId);
      } else {
        // Inspection date and inspector start blank (both required).
        ins = TobaccoInspectionModel.fromPermit(
          userId: userId,
          permit: loadedPermit,
          permitId: pid,
          scheduleId: scheduleId,
        );
      }
      inspection = ins;
      finalSubmit ??= TobaccoFinalSubmitModel(
        inspectionId: ins.inspectionId,
        inspectorName: ins.inspector,
        picName: ins.personInCharge,
      );
    } catch (e) {
      error = 'Could not open the inspection: $e';
      debugPrint('⚠️ Tobacco inspection init error: $e');
    }
    loading = false;
    _notify();

    await loadChecklist();
  }

  String? _inspectorName(int? id) {
    for (final i in inspectors) {
      if (i.id == id) return i.name;
    }
    return null;
  }

  /// Saved checklist first; downloads it when nothing is saved, otherwise
  /// refreshes it quietly in the background.
  Future<void> loadChecklist({bool forceSync = false}) async {
    checklistError = null;
    try {
      final saved = await _repo.getSavedChecklist();
      if (saved.isNotEmpty) _setChecklist(saved);
    } catch (e) {
      debugPrint('⚠️ Tobacco checklist DB error: $e');
    }

    if (sections.isEmpty || forceSync) {
      checklistLoading = true;
      _notify();
      try {
        await _repo.syncChecklist();
        _setChecklist(await _repo.getSavedChecklist());
      } catch (e) {
        checklistError = e.toString();
      }
      checklistLoading = false;
      _notify();
    } else {
      _notify();
      unawaited(_repo.syncChecklist().then((_) async {
        _setChecklist(await _repo.getSavedChecklist());
        _notify();
      }).catchError((Object e) {
        debugPrint('ℹ️ Tobacco checklist refresh skipped: $e');
      }));
    }
  }

  void _setChecklist(List<TobaccoSectionModel> all) {
    sections = all
        .where((s) => s.isActive && s.activeItems.isNotEmpty)
        .toList(growable: false);
    numbers.clear();
    var n = 0;
    for (final s in sections) {
      for (final item in s.activeItems) {
        numbers[item.id] = ++n;
      }
    }
    if (sectionIndex >= sections.length) sectionIndex = 0;
  }

  // ------------------------------------------------------- Navigation

  Future<void> goToStep(int s) async {
    if (s > stepEstablishment && !isSaved) return;
    step = s.clamp(stepEstablishment, stepEmail);
    _notify();
    final ins = inspection;
    if (ins != null && isSaved) {
      inspection = ins.copyWith(currentStep: step);
      await _db.updateTobaccoInspectionStep(ins.inspectionId, step);
    }
  }

  void selectSection(int i) {
    if (i < 0 || i >= sections.length) return;
    sectionIndex = i;
    _notify();
  }

  /// Next section, or Final Submit after the last one.
  Future<void> nextSection() async {
    if (isLastSection) {
      await goToStep(stepFinal);
    } else {
      selectSection(sectionIndex + 1);
    }
  }

  /// Previous section, or Establishment before the first one.
  Future<void> previousSection() async {
    if (sectionIndex == 0) {
      await goToStep(stepEstablishment);
    } else {
      selectSection(sectionIndex - 1);
    }
  }

  // ----------------------------------------------------- Establishment

  /// Validates and saves the Establishment tab, then opens the form.
  /// Returns an error message, or null when saved.
  Future<String?> saveEstablishment(TobaccoInspectionModel updated) async {
    if (updated.businessName.trim().isEmpty) {
      return 'Type Establishment Name is required.';
    }
    if (updated.inspectionDate.trim().isEmpty) {
      return 'Inspection Date is required.';
    }
    final named = updated.copyWith(
      inspector: _inspectorName(updated.inspectorId) ?? updated.inspector,
      currentStep: stepForm,
    );
    try {
      await _db.saveTobaccoInspection(named);
    } catch (e) {
      return 'Could not save: $e';
    }
    inspection = named;
    isSaved = true;

    // Keep Final Submit names in step when they're still empty.
    final f = finalSubmit;
    if (f != null) {
      finalSubmit = f.copyWith(
        inspectorName: (f.inspectorName ?? '').isEmpty ? named.inspector : null,
        picName: (f.picName ?? '').isEmpty ? named.personInCharge : null,
      );
    }
    step = stepForm;
    _notify();
    return null;
  }

  // ---------------------------------------------------------- Answers

  TobaccoInspectionAnswerModel? answerFor(int itemId) => _answers[itemId];

  String? answerValue(int itemId) => _answers[itemId]?.answer;

  bool isOptionSelected(int parentId, int childId) =>
      _answers[parentId]?.selectedIds.contains(childId) ?? false;

  String textFor(int itemId) => _answers[itemId]?.textValue ?? '';

  TobaccoInspectionAnswerModel _blank(int itemId) =>
      TobaccoInspectionAnswerModel(
          inspectionId: inspection!.inspectionId, itemId: itemId);

  /// YES / NO / NA. Tapping the selected button again clears it.
  /// Reasons (children) only stay while the answer is NO.
  void setAnswer(TobaccoItemModel item, String value) {
    if (inspection == null) return;
    final cur = _answers[item.id] ?? _blank(item.id);
    final clear = cur.answer == value;
    var next = cur.copyWith(answer: value, clearAnswer: clear);
    if (clear || value != TobaccoInspectionAnswerModel.no) {
      next = next.copyWith(selectedIds: const [], clearText: true);
    }
    _put(next);
  }

  /// Checks / unchecks [option] of [parent].
  void toggleOption(TobaccoItemModel parent, TobaccoItemModel option) {
    if (inspection == null) return;
    final cur = _answers[parent.id] ?? _blank(parent.id);
    final ids = [...cur.selectedIds];
    final wasSelected = ids.contains(option.id);
    if (parent.isSingleChoice) {
      ids
        ..clear()
        ..addAll(wasSelected ? const <int>[] : [option.id]);
    } else if (wasSelected) {
      ids.remove(option.id);
    } else {
      ids.add(option.id);
    }

    // Drop the "Other" text when no Other option is checked any more.
    final otherIds =
        parent.activeChildren.where((c) => c.isOtherOption).map((c) => c.id);
    final keepText = ids.any(otherIds.contains);
    _put(cur.copyWith(selectedIds: ids, clearText: !keepText));
  }

  /// Text questions and "Other:" text (saved after a short pause).
  void setText(int itemId, String text) {
    if (inspection == null) return;
    final cur = _answers[itemId] ?? _blank(itemId);
    final next = cur.copyWith(textValue: text);
    _answers[itemId] = next;
    _textTimers[itemId]?.cancel();
    _textTimers[itemId] = Timer(const Duration(milliseconds: 400), () {
      _db.saveTobaccoAnswers([_answers[itemId] ?? next]);
    });
    // No notify: the TextField already shows the text.
  }

  void _put(TobaccoInspectionAnswerModel a) {
    if (a.isEmpty) {
      _answers.remove(a.itemId);
    } else {
      _answers[a.itemId] = a;
    }
    _notify();
    _db.saveTobaccoAnswers([a]).catchError((Object e) {
      debugPrint('⚠️ Tobacco answer save error: $e');
    });
  }

  // ------------------------------------------------ Voice (AI Guide)

  /// Sets YES / NO / NA without toggling (tapping twice clears; voice
  /// must not).
  void setAnswerExact(TobaccoItemModel item, String value) {
    if (answerValue(item.id) == value) return;
    setAnswer(item, value);
  }

  /// Checks / unchecks one option without toggling.
  void setOption(
      TobaccoItemModel parent, TobaccoItemModel option, bool selected) {
    if (isOptionSelected(parent.id, option.id) == selected) return;
    toggleOption(parent, option);
  }

  /// Text answer from voice: saves now and rebuilds the text field.
  void setTextNow(int itemId, String text) {
    if (inspection == null) return;
    _textTimers[itemId]?.cancel();
    final cur = _answers[itemId] ?? _blank(itemId);
    _put(cur.copyWith(textValue: text, clearText: text.trim().isEmpty));
  }

  /// Item id → (section index, item) for a number shown on the form.
  ({int sectionIndex, TobaccoItemModel item})? itemByNumber(int number) {
    for (var si = 0; si < sections.length; si++) {
      for (final item in sections[si].activeItems) {
        if (numbers[item.id] == number) return (sectionIndex: si, item: item);
      }
    }
    return null;
  }

  /// Unanswered question labels in [s] ("5", "24 B" …).
  List<String> unansweredIn(TobaccoSectionModel s) {
    final out = <String>[];
    for (final item in s.activeItems) {
      final n = numbers[item.id];
      if (item.kind == TobaccoItemKind.productGroups) {
        for (final c in item.activeChildren) {
          if (!isAnswered(c)) out.add('$n ${c.itemLabel ?? ''}'.trim());
        }
      } else if (!isAnswered(item)) {
        out.add('$n');
      }
    }
    return out;
  }

  /// Leaving the Establishment tab (tab tap, Next, voice): validates the
  /// 4 required fields (red errors on the tab) and saves.
  /// Returns null when it's OK to move on.
  Future<String?> validateAndSaveEstablishment() async {
    final save = onVoiceSaveEstablishment;
    if (save == null) return isSaved ? null : 'Fill in the Establishment tab.';
    return save();
  }

  /// Set by the Establishment tab so voice can save it / fill fields.
  Future<String?> Function()? onVoiceSaveEstablishment;
  bool Function(String field, String value)? onVoiceSetField;

  /// Is this question (or product sub-question) answered?
  bool isAnswered(TobaccoItemModel item) {
    final a = _answers[item.id];
    if (a == null) return false;
    switch (item.kind) {
      case TobaccoItemKind.yesNo:
        return (a.answer ?? '').isNotEmpty;
      case TobaccoItemKind.checkboxes:
        return a.selectedIds.isNotEmpty;
      case TobaccoItemKind.text:
        return (a.textValue ?? '').trim().isNotEmpty;
      case TobaccoItemKind.productGroups:
        return false; // counted per child
    }
  }

  /// Questions to answer in [s] (product sub-questions count one each).
  Iterable<TobaccoItemModel> _questions(TobaccoSectionModel s) sync* {
    for (final item in s.activeItems) {
      if (item.kind == TobaccoItemKind.productGroups) {
        yield* item.activeChildren;
      } else {
        yield item;
      }
    }
  }

  ({int answered, int total}) progressOf(TobaccoSectionModel s) {
    var answered = 0, total = 0;
    for (final q in _questions(s)) {
      total++;
      if (isAnswered(q)) answered++;
    }
    return (answered: answered, total: total);
  }

  ({int answered, int total}) get overallProgress {
    var answered = 0, total = 0;
    for (final s in sections) {
      final p = progressOf(s);
      answered += p.answered;
      total += p.total;
    }
    return (answered: answered, total: total);
  }

  // ------------------------------------------------------ Final Submit

  void updateFinal(TobaccoFinalSubmitModel Function(TobaccoFinalSubmitModel) f,
      {bool notify = true}) {
    final cur = finalSubmit;
    if (cur == null) return;
    finalSubmit = f(cur);
    if (notify) _notify();
    _db.saveTobaccoFinalSubmit(finalSubmit!).catchError((Object e) {
      debugPrint('⚠️ Tobacco final save error: $e');
    });
  }

  /// Absolute path of a saved file (signature) – null if missing.
  String? resolveFile(String? relative) {
    if (relative == null || relative.isEmpty || _fileBaseDir == null) {
      return null;
    }
    return p.isAbsolute(relative) ? relative : p.join(_fileBaseDir!, relative);
  }

  /// Saves a signature PNG and stores its path on the Final row.
  Future<void> saveSignature(TobaccoSignatureKind kind, Uint8List png) async {
    final ins = inspection;
    final base = _fileBaseDir;
    if (ins == null || base == null) return;
    final dir = Directory(p.join(base, ins.inspectionId));
    if (!await dir.exists()) await dir.create(recursive: true);

    // New file name each time, so Image.file never shows a cached old one.
    final name =
        '${kind == TobaccoSignatureKind.pic ? 'pic' : 'inspector'}_signature_'
        '${DateTime.now().millisecondsSinceEpoch}.png';
    await File(p.join(dir.path, name)).writeAsBytes(png, flush: true);
    final rel = p.join(ins.inspectionId, name);

    final old = kind == TobaccoSignatureKind.pic
        ? finalSubmit?.picSignature
        : finalSubmit?.inspectorSignature;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    updateFinal((f) => kind == TobaccoSignatureKind.pic
        ? f.copyWith(
            picSignature: rel,
            picSignDate: (f.picSignDate ?? '').isEmpty ? today : null)
        : f.copyWith(
            inspectorSignature: rel,
            inspectorSignDate:
                (f.inspectorSignDate ?? '').isEmpty ? today : null));
    await _deleteFile(old);
  }

  Future<void> clearSignature(TobaccoSignatureKind kind) async {
    final old = kind == TobaccoSignatureKind.pic
        ? finalSubmit?.picSignature
        : finalSubmit?.inspectorSignature;
    updateFinal((f) => kind == TobaccoSignatureKind.pic
        ? f.copyWith(clearPicSignature: true)
        : f.copyWith(clearInspectorSignature: true));
    await _deleteFile(old);
  }

  Future<void> _deleteFile(String? relative) async {
    final path = resolveFile(relative);
    if (path == null) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  // ------------------------------------------------------------ Submit

  /// Server id returned by the last successful submit.
  int? serverInspectionId;

  /// "2026-11-05" → "11-05-2026" (API date format), '' when empty.
  static String _apiDate(String? ymd) {
    if (ymd == null || ymd.trim().isEmpty) return '';
    final d = DateTime.tryParse(ymd);
    if (d == null) return ymd;
    return '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}-${d.year}';
  }

  /// "09:05" → "09:05:00" (API time format), '' when empty.
  static String _apiTime(String? hm) {
    if (hm == null || hm.trim().isEmpty) return '';
    final parts = hm.split(':');
    final h = (parts.isNotEmpty ? parts[0] : '0').padLeft(2, '0');
    final m = (parts.length > 1 ? parts[1] : '0').padLeft(2, '0');
    final sec = (parts.length > 2 ? parts[2] : '0').padLeft(2, '0');
    return '$h:$m:$sec';
  }

  /// Signature PNG as base64 ('' when there is none).
  Future<String> _signatureBase64(String? relative) async {
    final path = resolveFile(relative);
    if (path == null) return '';
    try {
      final file = File(path);
      if (!await file.exists()) return '';
      return base64Encode(await file.readAsBytes());
    } catch (_) {
      return '';
    }
  }

  /// The checklist item whose name contains [words] (e.g. "violations found").
  TobaccoItemModel? _itemNamed(String words) {
    for (final s in sections) {
      for (final i in s.activeItems) {
        if (i.name.toLowerCase().contains(words)) return i;
      }
    }
    return null;
  }

  /// "violated_provisions" / "repeat_violations".
  /// ⚠️ The Tobacco form has no OUT/R items like Food, so:
  ///   violated_provisions = number of violation actions ticked under
  ///   "What action was taken?" ("0" when "Were any violations found?"
  ///   is NO or unanswered), repeat_violations = "0".
  ///   Change here if the backend expects something else.
  ({String violated, String repeat}) _violationCounts() {
    final found = _itemNamed('violations found');
    final yes = found != null &&
        answerValue(found.id) == TobaccoInspectionAnswerModel.yes;
    if (!yes) return (violated: '0', repeat: '0');
    final action = _itemNamed('action was taken');
    final n = action == null ? 1 : (answerFor(action.id)?.selectedIds.length ?? 0);
    return (violated: '${n == 0 ? 1 : n}', repeat: '0');
  }

  /// Body of POST /tobacco/inspection.
  /// "schedule_id" is 0 for a normal inspection, the schedule id otherwise.
  Future<Map<String, dynamic>> buildSubmitBody() async {
    final ins = inspection!;
    final f = finalSubmit;
    final v = _violationCounts();
    return {
      'inspection_date': _apiDate(ins.inspectionDate),
      'est_id': ins.permitId ?? 0,
      'permit_number': ins.permitNumber ?? '',
      'schedule_id': submitScheduleId,
      'reinspection_date': _apiDate(f?.reinspectionDate),
      'time_in': _apiTime(ins.timeIn),
      'time_out': _apiTime(ins.timeOut),
      'purpose_id': tobaccoPurposeId(f?.purpose),
      'operation_type_id': f?.operationTypeId ?? 0,
      'person_in_charge': ins.personInCharge ?? '',
      'other_information': (f?.otherInformation ?? '').trim(),
      'violated_provisions': v.violated,
      'repeat_violations': v.repeat,
      'person_in_charge_discussion': (f?.discussion ?? '').trim(),
      'inspector_id': ins.inspectorId ?? 0,
      'person_in_charge_sign': await _signatureBase64(f?.picSignature),
      'inspector_sign': await _signatureBase64(f?.inspectorSignature),
      'person_in_charge_sign_date': _apiDate(f?.picSignDate),
      'inspector_sign_date': _apiDate(f?.inspectorSignDate),
    };
  }

  /// Missing things that block submit (empty list = OK).
  List<String> validateForSubmit() {
    final problems = <String>[];
    final ins = inspection;
    if (!isSaved || ins == null) {
      return ['Save the Establishment tab first.'];
    }
    if (ins.inspectionDate.isEmpty) problems.add('Inspection Date is missing.');
    if ((ins.timeIn ?? '').isEmpty) problems.add('Time In is missing.');
    if ((ins.timeOut ?? '').isEmpty) problems.add('Time Out is missing.');
    if (ins.inspectorId == null) problems.add('Inspector is missing.');
    final f = finalSubmit;
    if (tobaccoPurposeId(f?.purpose) == 0) {
      problems.add('Select the Purpose of Inspection.');
    }
    if (operationTypes.isNotEmpty && (f?.operationTypeId ?? 0) == 0) {
      problems.add('Select the Operations Type.');
    }
    if (resolveFile(f?.inspectorSignature) == null) {
      problems.add('Inspector signature is missing.');
    }
    return problems;
  }

  /// Body of POST /tobacco/inspection-details (one object per answer).
  ///
  /// * YES / NO / NA questions (and product A, B … questions):
  ///     { item_id: question id, status: "YES"|"NO"|"NA", true_false: false }
  /// * Checkbox options – one object per CHECKED option (unchecked ones
  ///   are simply not in the list), several for the same question when
  ///   several are checked:
  ///     { item_id: option id, status: "", true_false: true,
  ///       comment: "Other" text for the Other option }
  ///   Reasons under a "NO" answer are sent the same way.
  /// * Text questions: { item_id, status: "", true_false: false,
  ///   comment: text }
  List<Map<String, dynamic>> buildItemsBody(int serverInspectionId) {
    final list = <Map<String, dynamic>>[];

    Map<String, dynamic> row(int itemId,
            {String status = '', bool trueFalse = false, String comment = ''}) =>
        {
          'inspection_id': serverInspectionId,
          'item_id': itemId,
          'status': status,
          'true_false': trueFalse,
          'comment': comment,
        };

    String apiStatus(String? a) {
      switch (a) {
        case TobaccoInspectionAnswerModel.yes:
          return 'YES';
        case TobaccoInspectionAnswerModel.no:
          return 'NO';
        case TobaccoInspectionAnswerModel.na:
          return 'NA';
        default:
          return '';
      }
    }

    void options(TobaccoItemModel parent) {
      final other = textFor(parent.id).trim();
      for (final o in parent.activeChildren) {
        if (!isOptionSelected(parent.id, o.id)) continue;
        list.add(row(o.id,
            trueFalse: true, comment: o.isOtherOption ? other : ''));
      }
    }

    for (final s in sections) {
      for (final item in s.activeItems) {
        switch (item.kind) {
          case TobaccoItemKind.yesNo:
            final answer = answerValue(item.id);
            if ((answer ?? '').isNotEmpty) {
              list.add(row(item.id, status: apiStatus(answer)));
            }
            if (answer == TobaccoInspectionAnswerModel.no) options(item);
            break;
          case TobaccoItemKind.checkboxes:
            options(item);
            break;
          case TobaccoItemKind.text:
            final text = textFor(item.id).trim();
            if (text.isNotEmpty) list.add(row(item.id, comment: text));
            break;
          case TobaccoItemKind.productGroups:
            for (final c in item.activeChildren) {
              if (c.kind == TobaccoItemKind.text) {
                final childText = textFor(c.id).trim();
                if (childText.isNotEmpty) {
                  list.add(row(c.id, comment: childText));
                }
                continue;
              }
              final childAnswer = answerValue(c.id);
              if ((childAnswer ?? '').isNotEmpty) {
                list.add(row(c.id, status: apiStatus(childAnswer)));
              }
            }
            break;
        }
      }
    }
    return list;
  }

  /// 1) POST /tobacco/inspection → inspectionID
  /// 2) POST /tobacco/inspection-details with that inspection_id
  /// The server id is saved after step 1, so if step 2 fails, the next
  /// Submit only re-sends the answers (no duplicate inspection).
  /// On full success the inspection is marked completed.
  /// Returns a message for the user.
  Future<String> submit() async {
    final problems = validateForSubmit();
    if (problems.isNotEmpty) return problems.join('\n');
    if (submitting) return 'Already submitting…';
    submitting = true;
    _notify();
    try {
      await flush();
      final ins = inspection!;

      // ---- 1) inspection ----
      var serverId = ins.serverInspectionId;
      if (serverId == null) {
        final res = await _repo.submitInspection(await buildSubmitBody());
        serverId = res.inspectionId;
        if (serverId == null) {
          return 'Submit failed: the server did not return an inspectionID.';
        }
        await _db.setTobaccoServerInspectionId(ins.inspectionId, serverId);
        inspection = ins.copyWith(serverInspectionId: serverId);
      }
      serverInspectionId = serverId;

      // ---- 2) answers ----
      final items = buildItemsBody(serverId);
      if (items.isNotEmpty) {
        try {
          await _repo.submitInspectionItems(items);
        } catch (e) {
          debugPrint('⚠️ Tobacco items submit error: $e');
          return 'The inspection was sent (ID $serverId) but the answers '
              'were not: $e\nTap Submit again to send the answers.';
        }
      }

      await _db.setTobaccoInspectionStatus(
          inspection!.inspectionId, TobaccoInspectionModel.statusCompleted);
      inspection =
          inspection!.copyWith(status: TobaccoInspectionModel.statusCompleted);
      return 'Inspection submitted successfully (ID $serverId, '
          '${items.length} answers).';
    } catch (e) {
      debugPrint('⚠️ Tobacco submit error: $e');
      return 'Submit failed: $e';
    } finally {
      submitting = false;
      _notify();
    }
  }

  // ------------------------------------------------------------- Misc

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Writes pending text answers right away.
  Future<void> flush() async {
    final pending = <TobaccoInspectionAnswerModel>[];
    for (final e in _textTimers.entries) {
      if (e.value.isActive) {
        e.value.cancel();
        final a = _answers[e.key];
        if (a != null) pending.add(a);
      }
    }
    if (pending.isNotEmpty) await _db.saveTobaccoAnswers(pending);
  }

  @override
  void dispose() {
    _disposed = true;
    // Save typed text that is still waiting for its timer.
    final pending = <TobaccoInspectionAnswerModel>[];
    for (final e in _textTimers.entries) {
      if (e.value.isActive) {
        e.value.cancel();
        final a = _answers[e.key];
        if (a != null) pending.add(a);
      }
    }
    if (pending.isNotEmpty) _db.saveTobaccoAnswers(pending);
    super.dispose();
  }
}
