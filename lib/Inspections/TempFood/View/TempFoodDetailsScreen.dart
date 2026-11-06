import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart' show Database;

import 'package:quincy/AI/ItemAnswerVoiceParser.dart';
import 'package:quincy/API/TempFoodAnswerRepository.dart';
import 'package:quincy/API/TempFoodInspectionSubmitRepository.dart';
import 'package:quincy/API/TempFoodItemSubmitRepository.dart';
import 'package:quincy/API/TempFoodTemperatureSubmitRepository.dart';

// Temp Food submit APIs (API 1 uses TempFoodInspectionRequest)

import 'package:quincy/Dashboard/View/AIGuidePanel.dart';
import 'package:quincy/Dashboard/ViewModel/VoiceAssistantViewModel.dart';
import 'package:quincy/Database/DBManager.dart';
import 'package:quincy/HTTPS/apiConstants.dart';


import 'package:quincy/Inspections/TempFood/Model/TempFoodInspectionModel.dart';
import 'package:quincy/Inspections/TempFood/Model/TempFoodInspectionRequest.dart';
import 'package:quincy/Inspections/TempFood/Model/TempFoodPermitModel.dart';
import 'package:quincy/Inspections/TempFood/Model/TempFoodSectionModel.dart';

import 'package:quincy/Inspections/TempFood/ViewModel/TempFoodChecklistViewModel.dart';
import 'package:quincy/Inspections/TempFood/ViewModel/TempFoodInspectionViewModel.dart';

// Row models shared with Mobile Food (same table shape)
import 'package:quincy/Inspections/MobileFood/Model/MobileFoodFinalSubmitModel.dart';
import 'package:quincy/Inspections/MobileFood/Model/MobileFoodInspectionAnswerModel.dart';
import 'package:quincy/Inspections/MobileFood/Model/MobileFoodOperationTypeModel.dart';
import 'package:quincy/Inspections/MobileFood/Model/MobileFoodSectionModel.dart';
import 'package:quincy/Inspections/MobileFood/Model/MobileFoodTemperatureModel.dart';
import 'package:quincy/Inspections/MobileFood/Model/MobileFoodTemperatureSubmitModel.dart';
import 'package:quincy/Inspections/MobileFood/Submit/Model/MobileFoodInspectionItemsModel.dart';
import 'package:quincy/Inspections/MobileFood/Submit/Model/mobileFoodInspectionModel.dart';

import 'package:quincy/Inspector/Model/InspectorModel.dart';
import 'package:quincy/Inspector/ViewModel/InspectorViewModel.dart';
import 'package:quincy/Login/ViewModel/LoginViewModel.dart';

import 'package:quincy/PDF/MobileFoodReportPdf.dart';
import 'package:quincy/Utilities/signPad.dart';

// ---------------- Theme ----------------
const _kPrimary = Color(0xFF1565C0);
const _kPrimaryLight = Color(0xFF1E88E5);
const _kStepInactive = Color(0xFFDCEAFB);
const _kBackground = Color(0xFFF5F7FA);
const _kTextDark = Color(0xFF1A2B3C);
const _kTextMuted = Color(0xFF6B7A90);
const _kBorder = Color(0xFFDCE3EC);
const _kReadOnlyFill = Color(0xFFEFF2F6);
const _kError = Color(0xFFD32F2F);
const _kSuccess = Color(0xFF2E7D32);
const _kGreyBtn = Color(0xFF546E7A);
const _kNoBlue = Color(0xFF1E88E5); // NO selected
const _kNaYellow = Color(0xFFFFC107); // NA selected

/// Result buttons on each item (same order as the web form)
const _kResults = ['OUT', 'COS', 'R', 'IN', 'NO', 'NA'];

/// Photos allowed per item
const _kPhotoSlots = MobileFoodInspectionAnswerModel.photoSlots;

// ---------------- Image upload settings ----------------
// The database keeps the original file paths.
// Only the copy sent to the server is compressed + base64 encoded.

/// Item photos: longest side (px) and JPEG quality sent to the server.
const _kUploadPhotoMaxSide = 1024;
const _kUploadPhotoQuality = 55;

/// Signatures: kept as PNG (sharp lines), canvas shrunk to this size.
const _kUploadSignWidth = 600;
const _kUploadSignHeight = 300;

// ---------------- Submit payload logging (debug builds only) ----------------

/// true → print the full base64 of photos / signatures (very long!).
/// false → print "<base64 12345 chars>" instead.
const _kLogFullBase64 = false;

/// Where the inspection was started from.
enum TempFoodInspectionEntryMode { newInspection, incomplete }

class TempFoodDetailsScreen extends StatefulWidget {
  final TempFoodInspectionEntryMode mode;

  /// Permit to pre-fill from (for [TempFoodInspectionEntryMode.newInspection]).
  /// Pass [permit] directly (from the permit list) or just its [permitId].
  final TempFoodPermitModel? permit;
  final int? permitId;

  /// Schedule this inspection was started from (Temp Food schedules list).
  /// Sent as "schedule_id"; null / 0 → not from a schedule (sends 0).
  final int? scheduleId;

  /// Saved inspection to resume (required for [TempFoodInspectionEntryMode.incomplete]).
  final String? inspectionId;

  /// Tab to open after loading (0 = Establishment … 4 = Email / PDF).
  /// Used by the AI Guide ("open the PDF for Rolling Bites").
  final int initialStep;

  /// AI Guide "submit my inspection": open the Final Submit tab and run
  /// Submit automatically (same checks and APIs as tapping the button).
  /// If something is missing (e.g. a signature) the tab stays open
  /// showing what to fill.
  final bool autoSubmit;

  /// Shows the AI Guide on this screen, so the inspector can answer
  /// questions by voice ("question 4 OUT with R").
  final bool enableVoice;

  const TempFoodDetailsScreen({
    super.key,
    required this.mode,
    this.permit,
    this.permitId,
    this.scheduleId,
    this.inspectionId,
    this.initialStep = 0,
    this.autoSubmit = false,
    this.enableVoice = true,
  });

  @override
  State<TempFoodDetailsScreen> createState() =>
      _TempFoodDetailsScreenState();
}

class _TempFoodDetailsScreenState extends State<TempFoodDetailsScreen> {
  static const _steps = [
    'Establishment',
    'Inspection Form',
    'Temperature Observations',
    'Final Submit',
    'Email',
  ];

  // TODO: match these with the web form's Purpose of Inspection options.
  static const List<String> _kPurposes = [
    'Routine',
    'Re-inspection',
    'Complaint',
    'Pre-operational',
    'Follow-up',
    'Other',
  ];

  static const Map<String, int> _kPurposeIds = {
    'Routine': 1,
    'Re-inspection': 2,
    'Complaint': 3,
    'Pre-operational': 4,
    'Follow-up': 5,
    'Other': 6,
  };

  final _establishmentFormKey = GlobalKey<FormState>();
  final ScrollController _stepScrollCtrl = ScrollController();

  int _currentStep = 0;
  int _maxReachedStep = 0;
  bool _isLoading = true;
  bool _showErrors = false;

  // ---- Establishment fields ----
  final _businessNameCtrl = TextEditingController();
  final _applicantNameCtrl = TextEditingController();
  final _permitNumberCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _telephoneCtrl = TextEditingController();
  final _ownerCtrl = TextEditingController();
  final _personInChargeCtrl = TextEditingController();
  final _inspectionDateCtrl = TextEditingController();
  final _timeInCtrl = TextEditingController();
  final _timeOutCtrl = TextEditingController();

  DateTime? _inspectionDate;
  TimeOfDay? _timeIn;
  TimeOfDay? _timeOut;

  /// Inspectors from the inspectors table (synced on the Dashboard).
  /// Dropdowns show the name, the API gets the id.
  /// Establishment tab and Final Submit tab share ONE selection.
  List<InspectorModel> _inspectorList = [];
  int? _selectedInspectorId;

  InspectorModel? get _selectedInspector {
    for (final i in _inspectorList) {
      if (i.id == _selectedInspectorId) return i;
    }
    return null;
  }

  String get _selectedInspectorName => _selectedInspector?.fullName ?? '';

  TempFoodPermitModel? _permit;

  /// Generated on first save, then reused for every later save.
  String? _inspectionId;
  int? _userId;
  int? _permitId;

  /// schedule_id for /temp-food/inspection (0 when not from a schedule).
  int? _scheduleId;
  bool _isSaving = false;

  // ---- ViewModels (MVVM) ----
  final TempFoodInspectionViewModel _inspectionVM = TempFoodInspectionViewModel();

  // ---- Submit (Temp Food APIs) ----
  final TempFoodInspectionApiRepository _apiRepo = TempFoodInspectionApiRepository();
  final TempFoodInspectionItemRepository _itemRepo =
      TempFoodInspectionItemRepository();
  final TempFoodTemperatureSubmitRepository _tempRepo =
      TempFoodTemperatureSubmitRepository();
  bool _isSubmitting = false;

  /// Progress of the 3 APIs – on retry, steps that already succeeded are skipped.
  int? _serverInspectionId; // API 1: /temp-food/inspection
  bool _itemsSubmitted = false; // API 2: /temp-food/inspection-item

  /// True once everything is submitted and the local rows are deleted.
  /// Stops dispose() / timers from writing the inspection back to the DB.
  bool _completed = false;

  // ---- Inspection Form (step 2) ----
  /// Section → Parts → Items from the database (one JOIN query)
  List<TempFoodChecklistSectionNode> _checklist = [];
  int _sectionIndex = 0;

  /// Section parts that are expanded in the list (phone layout)
  final Set<int> _expandedParts = {};

  /// itemId → what the inspector selected / typed / photographed
  final Map<int, _ItemAnswer> _answers = {};
  final Map<int, TextEditingController> _commentCtrls = {};

  /// Debounced comment saves (one timer per item)
  final Map<int, Timer> _commentTimers = {};

  final ScrollController _itemsScrollCtrl = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final TempFoodAnswerRepository _answerRepo = TempFoodAnswerRepository();

  // ---- Voice (AI Guide) ----
  final VoiceAssistantViewModel _voiceVM = VoiceAssistantViewModel();

  /// itemId → key, so voice can scroll to the item card
  final Map<int, GlobalKey> _itemKeys = {};

  // ---- Temperature Observations (step 3) ----
  final List<_TempRow> _tempRows = [];
  int _tempRowSeq = 0;
  Timer? _tempSaveTimer;

  // ---- Final Submit (step 4) ----
  DateTime? _reinspectionDate;
  final _reinspectionDateCtrl = TextEditingController();
  String? _purpose;
  int? _operationTypeId;
  List<MobileFoodOperationTypeModel> _operationTypes = [];
  final _discussionCtrl = TextEditingController();
  final _otherInfoCtrl = TextEditingController();

  /// Signature PNG files (absolute paths) and sign dates (yyyy-MM-dd)
  String? _picSignaturePath;
  String? _picSignDate;
  String? _inspectorSignaturePath;
  String? _inspectorSignDate;
  Timer? _finalSaveTimer;

  /// Sign dates (shown MM-DD-YYYY) and names – editable, required
  final _picSignDateCtrl = TextEditingController();
  final _picNameCtrl = TextEditingController();
  final _inspectorSignDateCtrl = TextEditingController();
  final _inspectorNameCtrl = TextEditingController();

  /// Show 'required' errors after Submit was tapped
  bool _finalShowErrors = false;

  // ---- Email (step 5): generated inspection report PDF ----
  Future<Uint8List>? _reportFuture;

  bool get _isNew => widget.mode == TempFoodInspectionEntryMode.newInspection;

  /// Fields that came from a permit record stay read-only.
  bool get _lockPermitFields => _permitId != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    // Flush any pending saves (values are read before controllers are disposed).
    _saveAllAnswers();
    _saveTemperatures();
    _saveFinal();
    for (final r in _tempRows) {
      r.dispose();
    }

    for (final c in [
      _reinspectionDateCtrl,
      _discussionCtrl,
      _otherInfoCtrl,
      _picSignDateCtrl,
      _picNameCtrl,
      _inspectorSignDateCtrl,
      _inspectorNameCtrl,
      _businessNameCtrl,
      _applicantNameCtrl,
      _permitNumberCtrl,
      _addressCtrl,
      _telephoneCtrl,
      _ownerCtrl,
      _personInChargeCtrl,
      _inspectionDateCtrl,
      _timeInCtrl,
      _timeOutCtrl,
    ]) {
      c.dispose();
    }
    for (final c in _commentCtrls.values) {
      c.dispose();
    }
    _itemsScrollCtrl.dispose();
    _stepScrollCtrl.dispose();
    _voiceVM.dispose();
    _inspectionVM.dispose();
    super.dispose();
  }

  // ---------------- Data ----------------

  Future<void> _loadData() async {
    final inspectionVM = _inspectionVM;

    // Logged-in user (provider first, saved user from the DB as fallback)
    LoginViewModel? loginVM;
    try {
      loginVM = Provider.of<LoginViewModel>(context, listen: false);
    } on ProviderNotFoundException {
      loginVM = null;
    }
    final user = loginVM?.user ?? await DBManager.instance.getLoggedInUser();
    if (!mounted) return;
    _userId = user?.id ?? await inspectionVM.getLoggedInUserId();

    // Inspector list – nothing is selected for a new inspection
    // (the inspector must be chosen; it is a required field).
    await _loadInspectors(
      userId: _userId,
      firstName: user?.firstName ?? '',
      lastName: user?.lastName ?? '',
    );
    if (!mounted) return;

    // Started from a schedule → keep its id for "schedule_id"
    final fromSchedule = widget.scheduleId;
    if (_isNew && fromSchedule != null && fromSchedule > 0) {
      _scheduleId = fromSchedule;
    }

    if (_isNew && (widget.permit != null || widget.permitId != null)) {
      // ---- New inspection: pre-fill from the permit table ----
      final permit = widget.permit ??
          await inspectionVM.getPermitById(widget.permitId!);
      if (!mounted) return;

      if (permit != null) _applyPermit(permit);
    } else if (!_isNew && widget.inspectionId != null) {
      // ---- Incomplete inspection: load from TempFoodInspection table ----
      final saved = await inspectionVM.getById(widget.inspectionId!);
      if (!mounted) return;

      if (saved != null) {
        _inspectionId = saved.inspectionId;
        _permitId = saved.permitId;
        _businessNameCtrl.text = saved.businessName;
        _applicantNameCtrl.text = saved.applicantName;
        _permitNumberCtrl.text = saved.permitNumber;
        _addressCtrl.text = saved.address;
        _telephoneCtrl.text = saved.telephone;
        _ownerCtrl.text = saved.owner;
        _personInChargeCtrl.text = saved.personInCharge;

        _inspectionDate = DateTime.tryParse(saved.inspectionDate);
        if (_inspectionDate != null) {
          _inspectionDateCtrl.text = _formatDate(_inspectionDate!);
        }
        _timeIn = _parseTime(saved.timeIn);
        if (_timeIn != null) _timeInCtrl.text = _formatTime(_timeIn!);
        _timeOut = _parseTime(saved.timeOut);
        if (_timeOut != null) _timeOutCtrl.text = _formatTime(_timeOut!);

        // Saved inspector: id first (exact), then name.
        // Nothing saved → stays blank until the inspector picks one.
        int? savedInspectorId;
        try {
          savedInspectorId = await DBManager.instance
              .getTempFoodInspectionInspectorId(saved.inspectionId);
        } catch (e) {
          debugPrint('❌ Load inspector id error: $e');
        }
        if (!mounted) return;
        _restoreInspector(id: savedInspectorId, name: saved.inspector);

        // Schedule it was started from (saved with the inspection)
        _scheduleId = await _loadScheduleId(saved.inspectionId);
        if (!mounted) return;

        // Steps already reached are marked done in the header
        _maxReachedStep = saved.currentStep.clamp(0, _steps.length - 1);
      }
    }

    // ---- Inspection Form: Section → Parts → Items from the database ----
    _checklist = await _loadChecklist();
    _expandFirstPart();

    // ---- Saved answers (results, comments, photos) of this inspection ----
    if (_inspectionId != null) {
      try {
        final saved = await _answerRepo.loadAnswers(_inspectionId!);
        _answers
          ..clear()
          ..addAll(saved.map(
              (itemId, m) => MapEntry(itemId, _ItemAnswer.fromModel(m))));
      } catch (e) {
        debugPrint('❌ Load answers error: $e');
      }

      // ---- Saved temperature rows ----
      try {
        final temps = await _answerRepo.loadTemperatures(_inspectionId!);
        for (final t in temps) {
          _addTempRow(
            itemLocation: t.itemLocation,
            temperature: t.temperature?.toString() ?? '',
          );
        }
      } catch (e) {
        debugPrint('❌ Load temperatures error: $e');
      }
    }

    // Always start with at least one row
    if (_tempRows.isEmpty) _addTempRow();

    // ---- Final Submit: operation types (synced on the Dashboard) ----
    try {
      _operationTypes = await _answerRepo.loadOperationTypes();
    } catch (e) {
      debugPrint('❌ Load operation types error: $e');
    }

    // ---- Final Submit: saved values of this inspection ----
    if (_inspectionId != null) {
      try {
        final f = await _answerRepo.loadFinalSubmit(_inspectionId!);
        if (f != null) _applyFinal(f);
      } catch (e) {
        debugPrint('❌ Load final submit error: $e');
      }
    }

    // Final Submit "Inspector Name" = the selected inspector
    // (a saved incomplete inspection may only have the name there)
    if (!_isNew &&
        _selectedInspector == null &&
        _inspectorNameCtrl.text.trim().isNotEmpty) {
      _selectInspectorByName(_inspectorNameCtrl.text);
    }
    _inspectorNameCtrl.text = _selectedInspectorName; // blank if none

    _discussionCtrl.addListener(_scheduleFinalSave);
    _otherInfoCtrl.addListener(_scheduleFinalSave);
    _picNameCtrl.addListener(_scheduleFinalSave);
    _inspectorNameCtrl.addListener(_scheduleFinalSave);

    if (mounted) setState(() => _isLoading = false);

    // AI Guide on this screen: "question 4 OUT with R" …
    if (widget.enableVoice && !widget.autoSubmit && mounted) {
      _voiceVM.onCommand = _handleVoiceCommand;
      try {
        await _voiceVM.init();
      } catch (e) {
        debugPrint('❌ Voice init error: $e');
      }
      if (!mounted) return;
    }

    // AI Guide "submit" → Final Submit tab, then Submit.
    if (widget.autoSubmit) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _goToStep(3); // checks the Establishment tab on the way
        if (!mounted || _currentStep != 3) return;
        await _onSubmit(); // on success: deletes local rows → Dashboard
      });
      return;
    }

    // AI Guide asked for a specific tab → go there once the form is built.
    // Each tab before it is checked, so missing fields stop on that tab.
    if (widget.initialStep > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _goToStep(widget.initialStep.clamp(0, _steps.length - 1));
      });
    }
  }

  Future<List<TempFoodChecklistSectionNode>> _loadChecklist() async {
    TempFoodChecklistViewModel vm;
    try {
      vm = Provider.of<TempFoodChecklistViewModel>(context, listen: false);
    } on ProviderNotFoundException {
      vm = TempFoodChecklistViewModel(); // provider missing in main.dart
    }
    try {
      var tree = await vm.loadTree();
      // Nothing saved yet → try to download it now (needs internet).
      if (tree.isEmpty && await vm.sync()) tree = vm.tree;
      return tree;
    } catch (e) {
      debugPrint('❌ Load Temp Food checklist error: $e');
      return [];
    }
  }

  /// Fills the Establishment tab from a Temp Food permit
  /// (same fields as the web Temporary Food inspection form):
  ///   Type Establishment Name ← organization_applying
  ///   Contact/Owner Name      ← contact_person (else organization_applying)
  ///   Permit Number           ← permit_number
  ///   Address                 ← address
  ///   Telephone               ← phone
  ///   Owner                   ← contact_person (else organization_applying)
  ///   Person-in-charge        ← entered by the inspector
  void _applyPermit(TempFoodPermitModel permit) {
    final organization = permit.organizationApplying ?? '';
    final contact = permit.contactPerson ?? organization;

    _permit = permit;
    _permitId = permit.id;
    _businessNameCtrl.text = organization;
    _applicantNameCtrl.text = contact;
    _permitNumberCtrl.text = permit.permitNumber ?? '';
    _addressCtrl.text = permit.address ?? '';
    _telephoneCtrl.text = permit.phone ?? '';
    _ownerCtrl.text = contact;
    _personInChargeCtrl.text = '';
  }

  // ---------------- Save ----------------

  String _toDbDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _toDbTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  TimeOfDay? _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  /// Saves the Establishment tab to the TempFoodInspection table.
  /// Creates a new inspection id the first time, updates it afterwards.
  Future<bool> _saveEstablishment({required int nextStep}) async {
    if (_userId == null) {
      _showSnack('No logged-in user found. Please log in again.',
          isError: true);
      return false;
    }

    _inspectionId ??= TempFoodInspectionModel.generateId(_userId!);
    final step = nextStep > _maxReachedStep ? nextStep : _maxReachedStep;

    final inspection = TempFoodInspectionModel(
      inspectionId: _inspectionId!,
      userId: _userId!,
      permitId: _permitId,
      businessName: _businessNameCtrl.text.trim(),
      applicantName: _applicantNameCtrl.text.trim(),
      permitNumber: _permitNumberCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      telephone: _telephoneCtrl.text.trim(),
      owner: _ownerCtrl.text.trim(),
      personInCharge: _personInChargeCtrl.text.trim(),
      inspectionDate: _toDbDate(_inspectionDate!),
      timeIn: _toDbTime(_timeIn!),
      timeOut: _toDbTime(_timeOut!),
      inspector: _selectedInspectorName,
      currentStep: step,
    );

    setState(() => _isSaving = true);
    try {
      await _inspectionVM.saveEstablishment(inspection);
      // Name AND id are kept, so the id is never lost later.
      await DBManager.instance
          .setTempFoodInspectionInspectorId(_inspectionId!, _realInspectorId);
      debugPrint('👤 Saved inspector: $_selectedInspectorName '
          '(id $_realInspectorId)');
      await _saveScheduleId(_inspectionId!);
      return true;
    } catch (e) {
      debugPrint('❌ Save inspection error: $e');
      if (mounted) {
        _showSnack('Could not save establishment details.', isError: true);
      }
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Saves one item's answer (result, COS/R, comment, photo paths).
  Future<void> _persistAnswer(int itemId) async {
    if (_completed) return;
    final id = _inspectionId;
    final a = _answers[itemId];
    if (id == null || a == null) return;
    try {
      await _answerRepo.saveAnswer(a.toModel(id, itemId));
    } catch (e) {
      debugPrint('❌ Save answer error: $e');
    }
  }

  /// Saves every answer in memory (used when leaving the tab / screen).
  Future<void> _saveAllAnswers() async {
    for (final t in _commentTimers.values) {
      t.cancel();
    }
    _commentTimers.clear();

    final id = _inspectionId;
    if (_completed || id == null || _answers.isEmpty) return;
    try {
      await _answerRepo.saveAnswers(
        _answers.entries.map((e) => e.value.toModel(id, e.key)).toList(),
      );
    } catch (e) {
      debugPrint('❌ Save answers error: $e');
    }
  }

  /// Saves all Temperature Observations rows (replaces the saved ones).
  /// The rows are read synchronously, so this is safe to call from dispose.
  Future<void> _saveTemperatures() async {
    _tempSaveTimer?.cancel();
    _tempSaveTimer = null;

    final id = _inspectionId;
    if (_completed || id == null) return;

    final rows = <MobileFoodTemperatureModel>[
      for (var i = 0; i < _tempRows.length; i++)
        MobileFoodTemperatureModel(
          inspectionId: id,
          sortOrder: i,
          itemLocation: _tempRows[i].itemCtrl.text.trim(),
          temperature: int.tryParse(_tempRows[i].tempCtrl.text.trim()),
        ),
    ];
    try {
      await _answerRepo.saveTemperatures(id, rows);
    } catch (e) {
      debugPrint('❌ Save temperatures error: $e');
    }
  }

  /// Save shortly after the user stops typing.
  void _scheduleTempSave() {
    _tempSaveTimer?.cancel();
    _tempSaveTimer =
        Timer(const Duration(milliseconds: 600), _saveTemperatures);
  }

  /// Puts saved Final Submit values back on screen.
  void _applyFinal(MobileFoodFinalSubmitModel f) {
    _reinspectionDate = f.reinspectionDate == null
        ? null
        : DateTime.tryParse(f.reinspectionDate!);
    if (_reinspectionDate != null) {
      _reinspectionDateCtrl.text = _formatDate(_reinspectionDate!);
    }
    if (f.purpose != null && _kPurposes.contains(f.purpose)) {
      _purpose = f.purpose;
    }
    // Only keep the id if it is still in the dropdown list
    _operationTypeId = _operationTypes.any((t) => t.id == f.operationTypeId)
        ? f.operationTypeId
        : null;
    _discussionCtrl.text = f.discussion;
    _otherInfoCtrl.text = f.otherInformation;

    String? existing(String? p) =>
        (p != null && File(p).existsSync()) ? p : null;
    _picSignaturePath = existing(f.picSignature);
    _inspectorSignaturePath = existing(f.inspectorSignature);

    _picSignDate = f.picSignDate;
    _inspectorSignDate = f.inspectorSignDate;
    _picSignDateCtrl.text = _displayDate(_picSignDate);
    _inspectorSignDateCtrl.text = _displayDate(_inspectorSignDate);
    _picNameCtrl.text = f.picName;
    _inspectorNameCtrl.text = f.inspectorName;
  }

  /// Current Final Submit values (read synchronously – safe in dispose).
  /// Signatures are stored as FILE PATHS in the database.
  MobileFoodFinalSubmitModel? _finalSnapshot() {
    final id = _inspectionId;
    if (id == null) return null;
    String? opName;
    for (final t in _operationTypes) {
      if (t.id == _operationTypeId) opName = t.name;
    }
    return MobileFoodFinalSubmitModel(
      inspectionId: id,
      reinspectionDate:
          _reinspectionDate == null ? null : _toDbDate(_reinspectionDate!),
      purpose: _purpose,
      operationTypeId: _operationTypeId,
      operationTypeName: opName,
      discussion: _discussionCtrl.text.trim(),
      otherInformation: _otherInfoCtrl.text.trim(),
      picSignature: _picSignaturePath,
      picSignDate: _picSignDate,
      picName: _picNameCtrl.text.trim(),
      inspectorSignature: _inspectorSignaturePath,
      inspectorSignDate: _inspectorSignDate,
      inspectorName: _inspectorNameCtrl.text.trim(),
    );
  }

  /// Saves the Final Submit tab to the TempFoodInspectionFinal table.
  Future<void> _saveFinal() async {
    _finalSaveTimer?.cancel();
    _finalSaveTimer = null;
    if (_completed) return;
    final data = _finalSnapshot();
    if (data == null) return;
    try {
      await _answerRepo.saveFinalSubmit(data);
    } catch (e) {
      debugPrint('❌ Save final submit error: $e');
    }
  }

  void _scheduleFinalSave() {
    _finalSaveTimer?.cancel();
    _finalSaveTimer = Timer(const Duration(milliseconds: 600), _saveFinal);
  }

  // ---------------- Pickers ----------------

  String _formatDate(DateTime d) => '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}-${d.year}';

  String _formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '${h.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} $period';
  }

  int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  ThemeData _pickerTheme(BuildContext ctx) => Theme.of(ctx).copyWith(
        colorScheme: Theme.of(ctx).colorScheme.copyWith(
              primary: _kPrimary,
              onPrimary: Colors.white,
            ),
      );

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _inspectionDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
      builder: (ctx, child) => Theme(data: _pickerTheme(ctx), child: child!),
    );
    if (picked == null) return;
    setState(() {
      _inspectionDate = picked;
      _inspectionDateCtrl.text = _formatDate(picked);
    });
    _revalidate();
  }

  Future<void> _pickTime({required bool isTimeIn}) async {
    FocusScope.of(context).unfocus();
    final current = isTimeIn ? _timeIn : _timeOut;
    final picked = await showTimePicker(
      context: context,
      initialTime: current ?? TimeOfDay.now(),
      builder: (ctx, child) => Theme(data: _pickerTheme(ctx), child: child!),
    );
    if (picked == null) return;
    setState(() {
      if (isTimeIn) {
        _timeIn = picked;
        _timeInCtrl.text = _formatTime(picked);
      } else {
        _timeOut = picked;
        _timeOutCtrl.text = _formatTime(picked);
      }
    });
    _revalidate();
  }

  void _revalidate() {
    if (_showErrors) _establishmentFormKey.currentState?.validate();
  }

  // ---------------- Validation ----------------

  String? _required(String? v, String label) =>
      (v == null || v.trim().isEmpty) ? '$label is required' : null;

  String? _validateTimeOut(String? v) {
    final req = _required(v, 'Time Out');
    if (req != null) return req;
    if (_timeIn != null &&
        _timeOut != null &&
        _minutes(_timeOut!) <= _minutes(_timeIn!)) {
      return 'Time Out must be after Time In';
    }
    return null;
  }

  bool _validateStep(int step) {
    switch (step) {
      case 0:
        setState(() => _showErrors = true);
        final formOk =
            _establishmentFormKey.currentState?.validate() ?? false;
        final inspectorOk = _realInspectorId != null;
        if (!formOk || !inspectorOk) {
          _showSnack(
            inspectorOk
                ? 'Please fill Inspection Date, Time In and Time Out to continue.'
                : 'Please fill Inspection Date, Time In, Time Out and '
                    'select the Inspector to continue.',
            isError: true,
          );
        }
        return formOk && inspectorOk;
      case 3:
        final missing = _missingFinalFields();
        if (missing.isNotEmpty) {
          setState(() => _finalShowErrors = true);
          _showSnack('Please fill: ${missing.join(', ')}.', isError: true);
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  // ---------------- Step navigation ----------------

  Future<void> _goToStep(int target) async {
    if (target == _currentStep || _isSaving) return;

    // Moving forward: every step before the target must be valid.
    if (target > _currentStep) {
      for (var s = _currentStep; s < target; s++) {
        if (!_validateStep(s)) {
          if (s != _currentStep) await _goToStep(s);
          return;
        }
      }
    }

    FocusScope.of(context).unfocus();

    // Leaving the Inspection Form tab → flush every answer to the DB
    if (_currentStep == 1) {
      await _saveAllAnswers();
      if (!mounted) return;
    }

    // Leaving the Temperature Observations tab → save the rows
    if (_currentStep == 2) {
      await _saveTemperatures();
      if (!mounted) return;
    }

    // Leaving the Final Submit tab → save it
    if (_currentStep == 3) {
      await _saveFinal();
      if (!mounted) return;
    }

    // Leaving the Establishment tab → save it to the TempFoodInspection table
    if (_currentStep == 0) {
      final saved = await _saveEstablishment(nextStep: target);
      if (!saved || !mounted) return;
    } else if (_inspectionId != null && target > _maxReachedStep) {
      await _inspectionVM.updateStep(_inspectionId!, target);
      if (!mounted) return;
    }

    // Opening the Email tab → build the report from the saved data
    if (target == 4) _reportFuture = _generateReport();

    setState(() {
      _currentStep = target;
      if (target > _maxReachedStep) _maxReachedStep = target;
    });
    _scrollStepIntoView(target);
  }

  void _scrollStepIntoView(int step) {
    if (!_stepScrollCtrl.hasClients) return;
    final max = _stepScrollCtrl.position.maxScrollExtent;
    final target = (max / (_steps.length - 1)) * step;
    _stepScrollCtrl.animateTo(
      target.clamp(0, max),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? _kError : _kPrimary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
  }

  Future<bool> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Leave inspection?'),
        content: Text(
          _inspectionId != null
              ? 'Saved details and checklist answers stay in Incomplete '
                  'inspections. Unsaved changes on the Establishment tab '
                  'will be lost.'
              : 'Any information you entered will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: _kError),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    return leave == true;
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (!await _confirmLeave() || !mounted) return;
        await _voiceVM.closePanel();
        await _saveAllAnswers();
        await _saveTemperatures();
        await _saveFinal();
        if (mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: _kBackground,
        appBar: _buildAppBar(),
        floatingActionButton: (_isLoading || !widget.enableVoice)
            ? null
            : ListenableBuilder(
                listenable: _voiceVM,
                builder: (context, _) => _voiceVM.isPanelOpen
                    ? const SizedBox.shrink()
                    : FloatingActionButton.extended(
                        onPressed: _voiceVM.openPanel,
                        icon: const Icon(Icons.support_agent),
                        label: const Text('AI Guide'),
                      ),
              ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _kPrimary))
            : Stack(
                children: [
                  Column(
                    children: [
                      _buildStepper(),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: KeyedSubtree(
                            key: ValueKey(_currentStep),
                            child: _buildStepContent(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (widget.enableVoice)
                    ListenableBuilder(
                      listenable: _voiceVM,
                      builder: (context, _) => _voiceVM.isPanelOpen
                          ? Positioned(
                              left: 12,
                              right: 12,
                              bottom: 12,
                              child: AIGuidePanel(vm: _voiceVM),
                            )
                          : const SizedBox.shrink(),
                    ),
                ],
              ),
        bottomNavigationBar: _isLoading ? null : _buildBottomBar(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      foregroundColor: Colors.white,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_kPrimaryLight, _kPrimary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Temporary Food Inspection',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            _inspectionId != null
                ? '${_isNew ? 'New' : 'Incomplete'} • $_inspectionId'
                : ((_permit?.permitNumber ?? '').isNotEmpty
                    ? 'New inspection • ${_permit!.permitNumber}'
                    : 'New inspection'),
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  // ---------- Step header ----------

  Widget _buildStepper() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        controller: _stepScrollCtrl,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: List.generate(_steps.length, (i) {
            final isActive = i == _currentStep;
            final isDone = !isActive && i < _maxReachedStep;

            return Padding(
              padding: EdgeInsets.only(right: i == _steps.length - 1 ? 0 : 8),
              child: Material(
                color: isActive ? _kPrimary : _kStepInactive,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _goToStep(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    constraints: const BoxConstraints(minWidth: 150),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isActive
                                ? Colors.white
                                : (isDone ? _kPrimaryLight : Colors.white),
                          ),
                          child: isDone && !isActive
                              ? const Icon(Icons.check,
                                  size: 16, color: Colors.white)
                              : Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isActive ? _kPrimary : _kPrimaryLight,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _steps[i],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                isActive ? FontWeight.w700 : FontWeight.w600,
                            color: isActive ? Colors.white : _kPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildEstablishmentStep();
      case 1:
        return _buildInspectionFormStep();
      case 2:
        return _buildTemperatureStep();
      case 3:
        return _buildFinalSubmitStep();
      case 4:
        return _buildEmailStep();
      default:
        return _buildPlaceholderStep(_steps[_currentStep]);
    }
  }

  // ---------- Step 1: Establishment ----------

  Widget _buildEstablishmentStep() {
    return Form(
      key: _establishmentFormKey,
      autovalidateMode: _showErrors
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _SectionCard(
            title: 'Establishment Details',
            icon: Icons.storefront_outlined,
            subtitle: _lockPermitFields
                ? 'Pre-filled from the permit record'
                : 'Enter the establishment details',
            children: [
              _ResponsiveRow(flex: const [5, 5, 2], children: [
                _field(
                  label: 'Type Establishment Name',
                  controller: _businessNameCtrl,
                  required: true,
                  readOnly: _lockPermitFields,
                  validator: (v) => _required(v, 'Type Establishment Name'),
                ),
                _field(
                  label: 'Contact/Owner Name',
                  controller: _applicantNameCtrl,
                  readOnly: _lockPermitFields,
                ),
                _field(
                  label: 'Permit Number',
                  controller: _permitNumberCtrl,
                  readOnly: _lockPermitFields,
                ),
              ]),
              _ResponsiveRow(flex: const [2, 1], children: [
                _field(
                  label: 'Address',
                  controller: _addressCtrl,
                  readOnly: _lockPermitFields,
                ),
                _field(
                  label: 'Telephone',
                  controller: _telephoneCtrl,
                  readOnly: _lockPermitFields,
                  keyboardType: TextInputType.phone,
                ),
              ]),
              _ResponsiveRow(flex: const [1, 1], children: [
                _field(
                  label: 'Owner',
                  controller: _ownerCtrl,
                  readOnly: _lockPermitFields,
                ),
                _field(
                  label: 'Person-in-charge',
                  controller: _personInChargeCtrl,
                  hint: 'Enter person in charge',
                ),
              ]),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Inspection Visit',
            icon: Icons.event_available_outlined,
            subtitle: 'Required before you can continue',
            children: [
              _ResponsiveRow(flex: const [1, 1, 1], children: [
                _field(
                  label: 'Inspection Date',
                  controller: _inspectionDateCtrl,
                  required: true,
                  hint: 'MM-DD-YYYY',
                  prefixIcon: Icons.calendar_month_outlined,
                  onTap: _pickDate,
                  validator: (v) => _required(v, 'Inspection Date'),
                ),
                _field(
                  label: 'Time In',
                  controller: _timeInCtrl,
                  required: true,
                  hint: '--:-- --',
                  prefixIcon: Icons.login_rounded,
                  onTap: () => _pickTime(isTimeIn: true),
                  validator: (v) => _required(v, 'Time In'),
                ),
                _field(
                  label: 'Time Out',
                  controller: _timeOutCtrl,
                  required: true,
                  hint: '--:-- --',
                  prefixIcon: Icons.logout_rounded,
                  onTap: () => _pickTime(isTimeIn: false),
                  validator: _validateTimeOut,
                ),
              ]),
              _ResponsiveRow(flex: const [1], children: [
                _inspectorDropdown(),
              ]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    bool required = false,
    bool readOnly = false,
    String? hint,
    IconData? prefixIcon,
    VoidCallback? onTap,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final isPicker = onTap != null;
    final locked = readOnly && !isPicker;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label, required: required, locked: locked),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          readOnly: readOnly || isPicker,
          onTap: onTap,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(
            fontSize: 14,
            color: locked ? _kTextMuted : _kTextDark,
            fontWeight: FontWeight.w500,
          ),
          decoration: _inputDecoration(
            hint: hint,
            locked: locked,
            prefixIcon: prefixIcon,
            suffixIcon: isPicker ? Icons.arrow_drop_down : null,
          ),
        ),
      ],
    );
  }

  // ---------------- Inspector (shared by Establishment + Final Submit) ----

  String _norm(String? s) =>
      (s ?? '').toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Finds an inspector in the list by email, id or name.
  InspectorModel? _matchInspector({int? id, String? email, String? name}) {
    final e = _norm(email);
    if (e.isNotEmpty) {
      for (final i in _inspectorList) {
        if (_norm(i.email) == e) return i;
      }
    }
    if (id != null) {
      for (final i in _inspectorList) {
        if (i.id == id) return i;
      }
    }
    final n = _norm(name);
    if (n.isNotEmpty) {
      for (final i in _inspectorList) {
        if (_norm(i.fullName) == n || _norm(i.nickName) == n) return i;
      }
    }
    return null;
  }

  /// Loads the inspector list (InspectorViewModel → inspectors table).
  /// Nothing is pre-selected: the inspector must be chosen.
  /// If nothing is synced yet, the logged-in user is offered so the
  /// inspection can still be done offline.
  Future<void> _loadInspectors({
    required int? userId,
    required String firstName,
    required String lastName,
  }) async {
    var list = <InspectorModel>[];
    try {
      InspectorViewModel? vm;
      try {
        vm = Provider.of<InspectorViewModel>(context, listen: false);
      } on ProviderNotFoundException {
        vm = null;
      }
      if (vm != null) {
        if (!vm.hasData) await vm.loadFromDb();
        list = vm.inspectors.toList();
      }
      if (list.isEmpty) list = await DBManager.instance.getInspectors();
    } catch (e) {
      debugPrint('❌ Load inspectors error: $e');
    }

    if (list.isEmpty && userId != null) {
      final name = '$firstName $lastName'.trim();
      if (name.isNotEmpty) {
        list = [
          InspectorModel(id: userId, firstName: firstName, lastName: lastName),
        ];
      }
    }

    _inspectorList = list;
    _selectedInspectorId = null; // blank until the inspector picks one
  }

  /// The selected inspector's real id (placeholders have negative ids).
  int? get _realInspectorId {
    final id = _selectedInspectorId;
    return (id != null && id > 0) ? id : null;
  }

  /// Re-selects the inspector saved with an incomplete inspection.
  /// A saved id wins; if that inspector is not in the synced list yet it
  /// is added with its REAL id, so the API still gets it.
  void _restoreInspector({int? id, String name = ''}) {
    if (id != null && id > 0) {
      if (!_inspectorList.any((i) => i.id == id)) {
        final n = name.trim();
        _inspectorList = [
          ..._inspectorList,
          InspectorModel(
            id: id,
            firstName: n.isEmpty ? 'Inspector #$id' : n,
            lastName: '',
          ),
        ];
      }
      _selectedInspectorId = id;
      return;
    }
    if (name.trim().isNotEmpty) _selectInspectorByName(name);
  }

  /// Selects the inspector whose name was saved in the database.
  /// A name that is no longer in the list stays selectable (negative id;
  /// a real id is resolved for the API in [_inspectorIdForApi]).
  void _selectInspectorByName(String name) {
    if (_norm(name).isEmpty) return;
    final match = _matchInspector(name: name);
    if (match != null) {
      _selectedInspectorId = match.id;
      return;
    }
    final placeholder = InspectorModel(
      id: -(_inspectorList.length + 1),
      firstName: name.trim(),
      lastName: '',
    );
    _inspectorList = [..._inspectorList, placeholder];
    _selectedInspectorId = placeholder.id;
  }

  /// One selection for both tabs: also fills the Final Submit inspector name.
  void _onInspectorChanged(int? id) {
    if (id == null || id == _selectedInspectorId) return;
    setState(() {
      _selectedInspectorId = id;
      _inspectorNameCtrl.text = _selectedInspectorName; // → Final table
    });
    _revalidate(); // clears the "Inspector is required" error

    // Changed on another tab → keep the TempFoodInspection row in step
    // (the Establishment tab saves itself when you leave it).
    if (_currentStep != 0 &&
        _inspectionId != null &&
        _inspectionDate != null &&
        _timeIn != null &&
        _timeOut != null) {
      _saveEstablishment(nextStep: _currentStep);
    }
  }

  /// inspector_id for /temp-food/inspection: the selected inspector
  /// (required, so it is always set by the time Submit runs);
  /// the id saved in the DB is a safety fallback.
  Future<int?> _inspectorIdForApi(TempFoodInspectionModel inspection) async {
    final id = _realInspectorId;
    if (id != null) return id;
    try {
      final savedId = await DBManager.instance
          .getTempFoodInspectionInspectorId(inspection.inspectionId);
      if (savedId != null && savedId > 0) return savedId;
    } catch (e) {
      debugPrint('❌ Read inspector id error: $e');
    }
    return null;
  }

  /// Dropdown: shows the name, value is the inspector id.
  /// Required: a placeholder (old saved name without an id) does not count.
  Widget _inspectorSelect({String? errorText}) {
    final value = _inspectorList.any((i) => i.id == _selectedInspectorId)
        ? _selectedInspectorId
        : null;
    return DropdownButtonFormField<int>(
      key: ValueKey('inspector_${value ?? 'none'}'),
      value: value,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down, color: _kPrimary),
      validator: (v) {
        if (v == null) return 'Inspector is required';
        if (v <= 0) return 'Please select the inspector again';
        return null;
      },
      // Show the error right away once Next / Submit was tapped
      autovalidateMode: (_showErrors || _finalShowErrors)
          ? AutovalidateMode.always
          : AutovalidateMode.disabled,
      decoration: _inputDecoration(
        hint: _inspectorList.isEmpty
            ? 'No inspectors – sync on the Dashboard'
            : 'Select inspector',
        prefixIcon: Icons.badge_outlined,
      ).copyWith(errorText: errorText),
      items: _inspectorList
          .map((i) => DropdownMenuItem<int>(
                value: i.id,
                child: Text(
                  i.fullName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14),
                ),
              ))
          .toList(),
      onChanged: _onInspectorChanged,
    );
  }

  Widget _inspectorDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel(label: 'Inspector', required: true),
        const SizedBox(height: 6),
        _inspectorSelect(),
      ],
    );
  }

  InputDecoration _inputDecoration({
    String? hint,
    bool locked = false,
    IconData? prefixIcon,
    IconData? suffixIcon,
  }) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c, width: w),
        );

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFA0AABB), fontSize: 14),
      isDense: true,
      filled: true,
      fillColor: locked ? _kReadOnlyFill : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      prefixIcon: prefixIcon == null
          ? null
          : Icon(prefixIcon, size: 20, color: _kPrimaryLight),
      suffixIcon: locked
          ? const Icon(Icons.lock_outline, size: 16, color: Color(0xFFA0AABB))
          : (suffixIcon == null ? null : Icon(suffixIcon, color: _kTextMuted)),
      border: border(_kBorder),
      enabledBorder: border(_kBorder),
      focusedBorder: border(locked ? _kBorder : _kPrimary, locked ? 1 : 1.6),
      errorBorder: border(_kError),
      focusedErrorBorder: border(_kError, 1.6),
      errorStyle: const TextStyle(fontSize: 12),
    );
  }

  // ---------- Step 2: Inspection Form ----------

  _ItemAnswer _answerFor(int itemId) =>
      _answers.putIfAbsent(itemId, () => _ItemAnswer());

  TextEditingController _commentFor(int itemId) =>
      _commentCtrls.putIfAbsent(itemId, () {
        final c = TextEditingController(text: _answers[itemId]?.comment ?? '');
        c.addListener(() {
          final a = _answerFor(itemId);
          if (a.comment == c.text) return; // cursor/selection change only
          a.comment = c.text;
          // Save to DB shortly after the user stops typing
          _commentTimers[itemId]?.cancel();
          _commentTimers[itemId] = Timer(
            const Duration(milliseconds: 600),
            () => _persistAnswer(itemId),
          );
        });
        return c;
      });

  int _answeredIn(Iterable<TempFoodItemModel> items) =>
      items.where((i) => _answers[i.id]?.result != null).length;

  void _selectSection(int i) {
    if (i == _sectionIndex) return;
    setState(() {
      _sectionIndex = i;
      _expandFirstPart();
    });
    _scrollItemsToTop();
  }

  /// Opens the first sub-category of the current section.
  void _expandFirstPart() {
    _expandedParts.clear();
    if (_checklist.isEmpty) return;
    final parts =
        _checklist[_sectionIndex.clamp(0, _checklist.length - 1)].parts;
    if (parts.isNotEmpty) _expandedParts.add(parts.first.part.id);
  }

  void _togglePart(int partId) {
    setState(() {
      if (!_expandedParts.remove(partId)) _expandedParts.add(partId);
    });
  }

  void _scrollItemsToTop() {
    if (_itemsScrollCtrl.hasClients) _itemsScrollCtrl.jumpTo(0);
  }

  /// Selection rules:
  /// * OUT / IN / NO / NA are one choice (tap again to clear).
  /// * COS and R can only be selected when OUT is selected.
  /// * COS and R can't both be on: OUT+COS → tap R → OUT+R (COS cleared),
  ///   and the other way round.
  /// * Choosing IN / NO / NA (or clearing OUT) clears COS and R.
  void _onResultTap(int itemId, String code) {
    final a = _answerFor(itemId);

    if ((code == 'COS' || code == 'R') && a.result != 'OUT') {
      _showSnack('Select OUT first to mark $code.');
      return;
    }

    setState(() {
      switch (code) {
        case 'COS':
          a.cos = !a.cos;
          if (a.cos) a.repeat = false;
          break;
        case 'R':
          a.repeat = !a.repeat;
          if (a.repeat) a.cos = false;
          break;
        default:
          a.result = a.result == code ? null : code;
          if (a.result != 'OUT') {
            a.cos = false;
            a.repeat = false;
          }
      }
    });
    _persistAnswer(itemId);
  }

  bool _isSelected(_ItemAnswer? a, String code) {
    if (a == null) return false;
    switch (code) {
      case 'COS':
        return a.cos;
      case 'R':
        return a.repeat;
      default:
        return a.result == code;
    }
  }

  // ---------------- Voice: answer questions ----------------

  static const _voiceHelp =
      'You can say: question 1 IN, question 4 OUT with R, '
      'questions 1 to 8 IN, all remaining NA, '
      'question 1 comment followed by your text, '
      'what is question 4, how many are left, or undo.';

  /// Answers as they were before the last voice change (for "undo").
  Map<int, _ItemAnswer>? _voiceUndo;
  List<int> _voiceUndoNumbers = [];

  int? _serialOf(TempFoodItemModel i) =>
      int.tryParse('${i.serialNumber}'.replaceAll(RegExp(r'[^0-9]'), ''));

  /// What the parser needs to understand "all", "remaining", "this section"
  /// and digits the speech engine glued together ("12345678").
  VoiceItemContext _voiceContext() {
    final all = <int>[];
    final answered = <int>{};
    final section = <int>[];
    for (var s = 0; s < _checklist.length; s++) {
      for (final p in _checklist[s].parts) {
        for (final item in p.items) {
          final n = _serialOf(item);
          if (n == null) continue;
          all.add(n);
          if (_answers[item.id]?.result != null) answered.add(n);
          if (s == _sectionIndex) section.add(n);
        }
      }
    }
    return VoiceItemContext(
      allNumbers: all,
      answered: answered,
      sectionNumbers: section,
    );
  }

  Future<VoiceReply> _handleVoiceCommand(String text) async {
    if (!mounted || _isLoading) return const VoiceReply('');

    final lower = text.toLowerCase();
    final hasDigit = RegExp(r'\d').hasMatch(lower);

    if (!hasDigit &&
        RegExp(r'\b(stop|close|cancel|bye|goodbye)\b').hasMatch(lower)) {
      return VoiceReply(
        'Okay. Tap AI Guide whenever you need me.',
        keepListening: false,
        afterSpeak: _voiceVM.closePanel,
      );
    }
    if (RegExp(r'\bhelp\b').hasMatch(lower)) {
      return const VoiceReply(_voiceHelp);
    }

    // "undo", "undo that"
    if (!hasDigit && RegExp(r'\b(undo|revert)\b').hasMatch(lower)) {
      final reply = await _undoVoiceChange();
      if (!mounted) return const VoiceReply('');
      return VoiceReply(reply);
    }

    // "how many are left", "progress", "which questions are left"
    if (!hasDigit &&
        RegExp(r'\b(how many|progress|summary|which|what)\b').hasMatch(lower) &&
        RegExp(r'\b(left|remaining|unanswered|pending|done|answered|'
                r'progress|summary|missing)\b')
            .hasMatch(lower)) {
      return VoiceReply(_voiceProgress(
        listLeft: RegExp(r'\b(which|what)\b').hasMatch(lower),
      ));
    }

    final parsed = ItemAnswerVoiceParser.parse(text, context: _voiceContext());
    if (parsed == null) {
      return const VoiceReply("Sorry, I didn't get that. $_voiceHelp");
    }
    final reply = await _applyVoiceAnswers(parsed);
    if (!mounted) return const VoiceReply('');
    return VoiceReply(reply);
  }

  /// Finds an item by its question number (current section first).
  ({int section, int partIndex, TempFoodChecklistPartNode part, TempFoodItemModel item})?
      _findItemByNumber(int number) {
    final order = [
      if (_sectionIndex < _checklist.length) _sectionIndex,
      for (var s = 0; s < _checklist.length; s++)
        if (s != _sectionIndex) s,
    ];
    for (final s in order) {
      final parts = _checklist[s].parts;
      for (var p = 0; p < parts.length; p++) {
        for (final item in parts[p].items) {
          if (_serialOf(item) == number) {
            return (section: s, partIndex: p, part: parts[p], item: item);
          }
        }
      }
    }
    return null;
  }

  /// Opens the item's section and sub-category and scrolls to it.
  void _focusItem(
    ({int section, int partIndex, TempFoodChecklistPartNode part, TempFoodItemModel item})
        hit,
  ) {
    if (_currentStep != 1) return;
    setState(() {
      if (hit.section != _sectionIndex) {
        _sectionIndex = hit.section;
        _expandedParts.clear();
      }
      _expandedParts.add(hit.part.part.id);
    });
    _scrollToItem(hit.item.id, hit.partIndex);
  }

  /// Applies spoken answers and comments with the same rules as tapping the
  /// buttons, saves them to the database and returns what to say back.
  Future<String> _applyVoiceAnswers(VoiceItemParseResult parsed) async {
    if (_checklist.isEmpty) {
      return 'Inspection items are not downloaded yet. '
          'Please sync on the Dashboard first.';
    }

    final needsChange =
        parsed.answers.isNotEmpty || parsed.comments.isNotEmpty;

    // "what is question 4" only reads – no saving needed
    if (!needsChange && parsed.queryNumbers.isNotEmpty) {
      if (_currentStep != 1) await _goToStep(1);
      if (!mounted) return '';
      return _describeItems(parsed.queryNumbers);
    }

    // Answers live on the Inspection Form tab (this also saves the
    // Establishment tab, so an inspection id exists).
    if (needsChange && _currentStep != 1) {
      await _goToStep(1);
      if (!mounted) return '';
      if (_currentStep != 1) {
        return 'Please fill the Inspection Date, Time In, Time Out and '
            'select the Inspector first, then tell me again.';
      }
    }
    final inspectionId = _inspectionId;
    if (needsChange && inspectionId == null) {
      return 'Please save the Establishment tab first.';
    }

    final changed = <int>{};
    final notFound = <int>{};
    final byStatus = <String, List<int>>{}; // "OUT with repeat" → [4, 7]
    final undo = <int, _ItemAnswer>{};
    final undoNums = <int>[];
    ({int section, int partIndex, TempFoodChecklistPartNode part, TempFoodItemModel item})?
        first;

    void remember(int itemId, int number) {
      if (undo.containsKey(itemId)) return;
      undo[itemId] = _answerFor(itemId).copy();
      undoNums.add(number);
    }

    // ---- IN / OUT / NO / NA, COS, R ----
    for (final v in parsed.answers) {
      final hit = _findItemByNumber(v.number);
      if (hit == null) {
        notFound.add(v.number);
        continue;
      }
      first ??= hit;
      remember(hit.item.id, v.number);
      final a = _answerFor(hit.item.id);

      switch (v.action) {
        case VoiceItemAction.set:
          // "question 4 OUT" keeps an existing COS / R
          final keepFlags =
              v.result == 'OUT' && a.result == 'OUT' && !v.cos && !v.repeat;
          a.result = v.result;
          if (!keepFlags) {
            a.cos = v.result == 'OUT' && v.cos;
            a.repeat = v.result == 'OUT' && v.repeat;
          }
          break;
        case VoiceItemAction.clear:
          a.result = null;
          a.cos = false;
          a.repeat = false;
          break;
        case VoiceItemAction.removeFlags:
          if (v.cos) a.cos = false;
          if (v.repeat) a.repeat = false;
          break;
      }
      changed.add(hit.item.id);
      byStatus.putIfAbsent(_spokenStatus(a), () => []).add(v.number);
    }

    // ---- Comments ----
    final commentSaid = <String>[];
    final commentGroups = <String, List<int>>{};
    for (final c in parsed.comments) {
      final hit = _findItemByNumber(c.number);
      if (hit == null) {
        notFound.add(c.number);
        continue;
      }
      first ??= hit;
      remember(hit.item.id, c.number);
      final a = _answerFor(hit.item.id);

      switch (c.mode) {
        case VoiceCommentMode.set:
          a.comment = c.text;
          break;
        case VoiceCommentMode.append:
          final old = a.comment.trim();
          a.comment = old.isEmpty ? c.text : '$old ${c.text}';
          break;
        case VoiceCommentMode.clear:
          a.comment = '';
          break;
      }

      // Show it in the comment box (no extra save from its listener)
      _commentTimers.remove(hit.item.id)?.cancel();
      final ctrl = _commentCtrls[hit.item.id];
      if (ctrl != null && ctrl.text != a.comment) ctrl.text = a.comment;

      changed.add(hit.item.id);
      final label = switch (c.mode) {
        VoiceCommentMode.set => 'saved',
        VoiceCommentMode.append => 'added',
        VoiceCommentMode.clear => 'cleared',
      };
      commentGroups.putIfAbsent(label, () => []).add(c.number);
    }
    if (parsed.comments.length == 1 && commentGroups.isNotEmpty) {
      final c = parsed.comments.first;
      commentSaid.add(c.mode == VoiceCommentMode.clear
          ? 'Comment cleared for question ${c.number}.'
          : 'Comment ${commentGroups.keys.first} for question ${c.number}: '
              '${c.text}.');
    } else {
      commentGroups.forEach((label, nums) {
        commentSaid.add('Comments $label for '
            '${ItemAnswerVoiceParser.numbersSpoken(nums)}.');
      });
    }

    // Show it: right section, sub-category open, item on screen
    if (first != null) _focusItem(first);

    // Save to the TempFoodInspectionAnswer table
    if (changed.isNotEmpty && !_completed && inspectionId != null) {
      try {
        await _answerRepo.saveAnswers([
          for (final id in changed) _answers[id]!.toModel(inspectionId, id),
        ]);
      } catch (e) {
        debugPrint('❌ Voice save answers error: $e');
        return 'Sorry, I could not save the answers.';
      }
      _voiceUndo = undo;
      _voiceUndoNumbers = undoNums;
    }
    if (mounted) setState(() {});

    // What to say back
    final parts = <String>[];
    if (byStatus.isNotEmpty) {
      final said = byStatus.entries.map((e) {
        final nums = ItemAnswerVoiceParser.numbersSpoken(e.value);
        return '${nums[0].toUpperCase()}${nums.substring(1)} ${e.key}';
      }).join('. ');
      parts.add('Done. $said.');
    }
    parts.addAll(commentSaid);
    parts.addAll(parsed.warnings);
    if (notFound.isNotEmpty) {
      parts.add("I couldn't find "
          '${ItemAnswerVoiceParser.numbersSpoken(notFound)} on this form.');
    }
    if (parsed.missingResult.isNotEmpty) {
      parts.add('What should I select for '
          '${ItemAnswerVoiceParser.numbersSpoken(parsed.missingResult)}? '
          'Say IN, OUT, NO or NA.');
    }
    if (parsed.queryNumbers.isNotEmpty) {
      parts.add(_describeItems(parsed.queryNumbers));
    }
    if (undo.length >= 5) parts.add('Say undo if that was wrong.');
    return parts.isEmpty ? _voiceHelp : parts.join(' ');
  }

  /// "what is question 4" → item text, current answer and comment.
  String _describeItems(List<int> nums) {
    final lines = <String>[];
    final missing = <int>[];
    ({int section, int partIndex, TempFoodChecklistPartNode part, TempFoodItemModel item})?
        first;
    for (final n in nums.take(3)) {
      final hit = _findItemByNumber(n);
      if (hit == null) {
        missing.add(n);
        continue;
      }
      first ??= hit;
      final a = _answers[hit.item.id];
      final status = (a == null || a.result == null)
          ? 'not answered yet'
          : _spokenStatus(a);
      final comment = a?.comment.trim() ?? '';
      lines.add('Question $n, ${hit.item.name}. It is $status.'
          '${comment.isEmpty ? '' : ' Comment: $comment.'}');
    }
    if (nums.length > 3) lines.add('I read the first 3.');
    if (missing.isNotEmpty) {
      lines.add("I couldn't find "
          '${ItemAnswerVoiceParser.numbersSpoken(missing)} on this form.');
    }
    if (first != null) _focusItem(first);
    return lines.join(' ');
  }

  /// "how many are left" / "which questions are left" / "progress"
  String _voiceProgress({bool listLeft = false}) {
    if (_checklist.isEmpty) return 'Inspection items are not downloaded yet.';
    final byResult = <String, List<int>>{};
    final left = <int>[];
    var total = 0;
    for (final s in _checklist) {
      for (final p in s.parts) {
        for (final item in p.items) {
          final n = _serialOf(item);
          if (n == null) continue;
          total++;
          final r = _answers[item.id]?.result;
          if (r == null) {
            left.add(n);
          } else {
            byResult.putIfAbsent(r, () => []).add(n);
          }
        }
      }
    }
    final done = total - left.length;
    String count(String code, String label) {
      final c = byResult[code]?.length ?? 0;
      return c == 0 ? '' : '$c $label';
    }

    final breakdown = [
      count('IN', 'IN'),
      count('OUT', 'OUT'),
      count('NO', 'not observed'),
      count('NA', 'not applicable'),
    ].where((s) => s.isNotEmpty).join(', ');

    final parts = <String>[
      '$done of $total questions answered'
          '${breakdown.isEmpty ? '' : ': $breakdown'}.',
    ];
    final out = byResult['OUT'] ?? const <int>[];
    if (out.isNotEmpty) {
      parts.add('OUT is ${ItemAnswerVoiceParser.numbersSpoken(out)}.');
    }
    if (left.isEmpty) {
      parts.add('Everything is answered.');
    } else if (listLeft || left.length <= 10) {
      parts.add('Still to answer: ${ItemAnswerVoiceParser.numbersSpoken(left)}.');
    } else {
      parts.add('${left.length} are left. Say all remaining, then IN, OUT, '
          'NO or NA to fill them.');
    }
    return parts.join(' ');
  }

  /// Puts back the answers from before the last voice change.
  Future<String> _undoVoiceChange() async {
    final undo = _voiceUndo;
    final id = _inspectionId;
    if (undo == null || undo.isEmpty || id == null) {
      return 'There is nothing to undo.';
    }
    _voiceUndo = null;
    final nums = _voiceUndoNumbers;
    _voiceUndoNumbers = [];

    setState(() {
      undo.forEach((itemId, old) {
        final a = _answerFor(itemId)
          ..result = old.result
          ..cos = old.cos
          ..repeat = old.repeat
          ..comment = old.comment;
        _commentTimers.remove(itemId)?.cancel();
        final ctrl = _commentCtrls[itemId];
        if (ctrl != null && ctrl.text != a.comment) ctrl.text = a.comment;
      });
    });

    try {
      await _answerRepo.saveAnswers([
        for (final itemId in undo.keys) _answers[itemId]!.toModel(id, itemId),
      ]);
    } catch (e) {
      debugPrint('❌ Voice undo error: $e');
      return 'Sorry, I could not undo the change.';
    }
    final which = ItemAnswerVoiceParser.numbersSpoken(nums);
    return 'Undone. ${which[0].toUpperCase()}${which.substring(1)} '
        '${nums.length == 1 ? 'is' : 'are'} back to how ${nums.length == 1 ? 'it was' : 'they were'}.';
  }

  String _spokenStatus(_ItemAnswer a) {
    if (a.result == null) return 'cleared';
    final r = switch (a.result) {
      'NO' => 'not observed',
      'NA' => 'not applicable',
      _ => a.result!,
    };
    if (a.cos) return '$r with corrected on site';
    if (a.repeat) return '$r with repeat';
    return r;
  }

  /// Scrolls the parts list so the answered item is visible.
  Future<void> _scrollToItem(int itemId, int partIndex) async {
    // wait for the section switch + sub-category expand animation
    await Future.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;

    var ctx = _itemKeys[itemId]?.currentContext;
    if (ctx == null && _itemsScrollCtrl.hasClients) {
      // Sub-category is off-screen (ListView.builder hasn't built it):
      // jump near it, then try again.
      final max = _itemsScrollCtrl.position.maxScrollExtent;
      _itemsScrollCtrl.jumpTo((partIndex * 64.0).clamp(0.0, max));
      await Future.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;
      ctx = _itemKeys[itemId]?.currentContext;
    }
    if (ctx != null && ctx.mounted) {
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0.08,
      );
    }
  }

  // ---------------- Photos ----------------

  Future<void> _pickPhoto(int itemId, int slot, ImageSource source) async {
    final inspectionId = _inspectionId;
    if (inspectionId == null) {
      _showSnack('Save the Establishment tab first.', isError: true);
      return;
    }
    try {
      // Smaller capture → smaller file on disk and faster upload later
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 60,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (file == null) return;

      // Copy into the app's photo folder (picker files are temporary).
      // The DATABASE stores this FILE PATH.
      final savedPath = await _answerRepo.storePhoto(
        inspectionId: inspectionId,
        itemId: itemId,
        slot: slot,
        sourcePath: file.path,
      );

      final a = _answerFor(itemId);
      final oldPath = a.photos[slot];
      a.photos[slot] = savedPath;
      if (mounted) setState(() {});

      await _persistAnswer(itemId);
      await _answerRepo.deletePhoto(oldPath);
    } catch (e) {
      debugPrint('❌ Pick photo error: $e');
      if (mounted) {
        _showSnack(
            'Could not add the photo from the ${source == ImageSource.camera ? 'camera' : 'gallery'}.',
            isError: true);
      }
    }
  }

  Future<void> _removePhoto(int itemId, int slot) async {
    final a = _answerFor(itemId);
    final oldPath = a.photos[slot];
    setState(() => a.photos[slot] = null);
    await _persistAnswer(itemId);
    await _answerRepo.deletePhoto(oldPath);
  }

  void _viewPhoto(String path) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Stack(
          children: [
            InteractiveViewer(child: Image.file(File(path))),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInspectionFormStep() {
    if (_checklist.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _SectionCard(
            title: 'Inspection items not available',
            icon: Icons.cloud_download_outlined,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Sections and items have not been downloaded yet.\n'
                    'Go back to the Dashboard with internet to sync them.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _kTextMuted, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    final section = _checklist[_sectionIndex.clamp(0, _checklist.length - 1)];

    // Same layout on every screen size (phone, tablet, simulator):
    // section tabs on top, sub-categories as an expandable list below.
    return Column(
      children: [
        _buildSectionTabs(),
        Expanded(child: _buildPartsList(section.parts)),
      ],
    );
  }

  /// Section tabs (e.g. FOODBORNE ILLNESS… / GOOD RETAIL PRACTICES…)
  Widget _buildSectionTabs() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(_checklist.length, (i) {
            final s = _checklist[i];
            final active = i == _sectionIndex;
            final items = s.parts.expand((p) => p.items);
            final done = _answeredIn(items);
            final total = s.itemCount;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Material(
                color: active ? _kPrimary : const Color(0xFFF0F5FC),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _selectSection(i),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 300),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          s.section.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                            color: active ? Colors.white : _kPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$done / $total answered',
                          style: TextStyle(
                            fontSize: 11,
                            color: active ? Colors.white70 : _kTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  /// Sub-categories (Supervision, Employee Health…) as a list.
  /// Tap a sub-category to show / hide its items underneath.
  Widget _buildPartsList(List<TempFoodChecklistPartNode> parts) {
    return ListView.builder(
      key: PageStorageKey('parts_$_sectionIndex'),
      controller: _itemsScrollCtrl,
      // extra bottom space so the AI Guide button doesn't cover the last item
      padding: EdgeInsets.fromLTRB(12, 12, 12, widget.enableVoice ? 96 : 24),
      itemCount: parts.length,
      itemBuilder: (context, i) {
        final p = parts[i];
        final open = _expandedParts.contains(p.part.id);
        final done = _answeredIn(p.items);

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: open
                    ? _kPrimary.withOpacity(0.35)
                    : const Color(0xFFE3EAF3),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ---- Sub-category row ----
                Material(
                  color: open ? const Color(0xFFEFF5FD) : Colors.white,
                  child: InkWell(
                    onTap: () => _togglePart(p.part.id),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 22,
                            decoration: BoxDecoration(
                              color:
                                  open ? _kPrimary : const Color(0xFFBFD3EC),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              p.part.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight:
                                    open ? FontWeight.w700 : FontWeight.w600,
                                color: _kPrimary,
                              ),
                            ),
                          ),
                          _progressBadge(done, p.items.length, onDark: false),
                          const SizedBox(width: 6),
                          AnimatedRotation(
                            turns: open ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: const Icon(Icons.keyboard_arrow_down,
                                color: _kTextMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ---- Items of this sub-category ----
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: open
                      ? Container(
                          color: _kBackground,
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 2),
                          child: Column(
                            children: p.items
                                .map((item) => Padding(
                                      key: _itemKeys.putIfAbsent(
                                          item.id, () => GlobalKey()),
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: _buildItemCard(item),
                                    ))
                                .toList(),
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _progressBadge(int done, int total, {required bool onDark}) {
    final complete = total > 0 && done == total;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: onDark
            ? Colors.white.withOpacity(0.2)
            : (complete
                ? _kSuccess.withOpacity(0.12)
                : const Color(0xFFE8F1FC)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: complete
          ? Icon(Icons.check,
              size: 13, color: onDark ? Colors.white : _kSuccess)
          : Text(
              '$done/$total',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: onDark ? Colors.white : _kPrimary,
              ),
            ),
    );
  }

  Widget _buildItemCard(TempFoodItemModel item) {
    final a = _answers[item.id];
    final hasOut = a?.result == 'OUT';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasOut ? _kError.withOpacity(0.5) : const Color(0xFFE3EAF3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: "1. Person-in-charge present…"
          Container(
            color: _kPrimary,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${item.serialNumber}. ',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: item.name),
                ],
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(builder: (context, c) {
              final wide = c.maxWidth >= 620;
              final buttons = _buildResultButtons(item.id, a);
              final comment = _buildCommentField(item.id);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buttons,
                        const SizedBox(width: 16),
                        Expanded(child: comment),
                      ],
                    )
                  else ...[
                    buttons,
                    const SizedBox(height: 12),
                    comment,
                  ],
                  const SizedBox(height: 12),
                  _buildPhotoSlots(item.id),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildResultButtons(int itemId, _ItemAnswer? a) {
    final outSelected = a?.result == 'OUT';

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _kResults.map((code) {
        final selected = _isSelected(a, code);
        final isFlag = code == 'COS' || code == 'R';
        final enabled = !isFlag || outSelected; // COS / R need OUT

        final color = switch (code) {
          'OUT' => _kError,
          'IN' => _kSuccess,
          'NO' => _kNoBlue,
          'NA' => _kNaYellow,
          _ => _kGreyBtn,
        };
        final selectedTextColor = code == 'NA' ? _kTextDark : Colors.white;

        return Opacity(
          opacity: enabled ? 1 : 0.4,
          child: SizedBox(
            height: 38,
            child: Material(
              color: selected ? color : Colors.white,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _onResultTap(itemId, code),
                child: Container(
                  constraints: const BoxConstraints(minWidth: 46),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected ? color : const Color(0xFFD5DCE5),
                    ),
                  ),
                  child: Text(
                    code,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? selectedTextColor
                          : (code == 'OUT' ? _kError : _kTextDark),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCommentField(int itemId) {
    return TextField(
      controller: _commentFor(itemId),
      minLines: 2,
      maxLines: 4,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(fontSize: 14, color: _kTextDark),
      decoration: _inputDecoration(hint: 'Comments..'),
    );
  }

  Widget _buildPhotoSlots(int itemId) {
    final photos = _answers[itemId]?.photos;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(_kPhotoSlots, (slot) {
        final path = photos?[slot];
        if (path != null) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: () => _viewPhoto(path),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(path),
                    width: 76,
                    height: 76,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 76,
                      height: 76,
                      color: const Color(0xFFF6F9FD),
                      child: const Icon(Icons.broken_image_outlined,
                          color: _kTextMuted),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -8,
                right: -8,
                child: InkWell(
                  onTap: () => _removePhoto(itemId, slot),
                  child: const CircleAvatar(
                    radius: 11,
                    backgroundColor: _kError,
                    child: Icon(Icons.close, size: 13, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        }
        return Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: const Color(0xFFF6F9FD),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD5E2F2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _photoButton(
                Icons.photo_camera_outlined,
                'Camera',
                () => _pickPhoto(itemId, slot, ImageSource.camera),
              ),
              const Divider(height: 1, color: Color(0xFFE1E9F3)),
              _photoButton(
                Icons.photo_library_outlined,
                'Gallery',
                () => _pickPhoto(itemId, slot, ImageSource.gallery),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _photoButton(IconData icon, String tooltip, VoidCallback onTap) {
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          child: Center(child: Icon(icon, size: 20, color: _kPrimary)),
        ),
      ),
    );
  }

  // ---------- Step 3: Temperature Observations ----------

  void _addTempRow({String itemLocation = '', String temperature = ''}) {
    final row = _TempRow(
      key: _tempRowSeq++,
      itemLocation: itemLocation,
      temperature: temperature,
    );
    row.itemCtrl.addListener(row.onChanged(_scheduleTempSave));
    row.tempCtrl.addListener(row.onChanged(_scheduleTempSave));
    _tempRows.add(row);
  }

  void _onAddNewTempRow() {
    setState(_addTempRow);
    // Focus the new row's Item/Location field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _tempRows.isNotEmpty) {
        _tempRows.last.itemFocus.requestFocus();
      }
    });
  }

  void _deleteTempRow(int index) {
    if (index == 0 || index >= _tempRows.length) return; // first row stays
    FocusScope.of(context).unfocus();
    final row = _tempRows.removeAt(index);
    setState(() {});
    // Dispose after the frame so the removed TextFields are gone first
    WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose());
    _saveTemperatures();
  }

  Widget _buildTemperatureStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _SectionCard(
          title: 'Temperature Observations',
          icon: Icons.thermostat_outlined,
          subtitle: 'Add one row per item / location',
          children: [
            // Column titles
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(flex: 3, child: _FieldLabel(label: 'Item/Location')),
                  SizedBox(width: 10),
                  Expanded(flex: 2, child: _FieldLabel(label: 'Temp (℉)')),
                  SizedBox(width: 44), // space for the delete button
                ],
              ),
            ),
            for (var i = 0; i < _tempRows.length; i++)
              _buildTempRow(i, _tempRows[i]),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _onAddNewTempRow,
                icon: const Icon(Icons.add),
                label: const Text('ADD NEW'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kPrimary,
                  side: const BorderSide(color: _kPrimary),
                  minimumSize: const Size(140, 46),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ],
    );
  }

  Widget _buildTempRow(int index, _TempRow row) {
    return Padding(
      key: ValueKey('temp_row_${row.key}'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: row.itemCtrl,
              focusNode: row.itemFocus,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              style: const TextStyle(fontSize: 14, color: _kTextDark),
              decoration: _inputDecoration(hint: 'Item / Location'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: TextField(
              controller: row.tempCtrl,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              // Digits only – no decimal point, no minus sign
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              style: const TextStyle(fontSize: 14, color: _kTextDark),
              decoration: _inputDecoration(hint: '0').copyWith(
                suffixText: '℉',
                suffixStyle: const TextStyle(color: _kTextMuted),
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: index == 0
                ? null
                : IconButton(
                    tooltip: 'Delete row',
                    onPressed: () => _deleteTempRow(index),
                    icon: const Icon(Icons.delete_outline, color: _kError),
                  ),
          ),
        ],
      ),
    );
  }

  // ---------- Step 4: Final Submit ----------

  String _displayDate(String? dbDate) {
    if (dbDate == null) return '';
    final d = DateTime.tryParse(dbDate);
    return d == null ? dbDate : _formatDate(d);
  }

  Future<void> _pickReinspectionDate() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final first = DateTime(now.year - 2);
    final last = DateTime(now.year + 5);
    var initial = _reinspectionDate ?? now;
    if (initial.isBefore(first) || initial.isAfter(last)) initial = now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      builder: (ctx, child) => Theme(data: _pickerTheme(ctx), child: child!),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _reinspectionDate = picked;
      _reinspectionDateCtrl.text = _formatDate(picked);
    });
    _saveFinal();
  }

  /// Saves a new signature PNG file. The DATABASE stores the FILE PATH.
  Future<void> _onSigned(
      {required bool isInspector, required Uint8List png}) async {
    final id = _inspectionId;
    if (id == null) return;
    try {
      final path = await _answerRepo.storeSignature(
        inspectionId: id,
        who: isInspector ? 'inspector' : 'pic',
        bytes: png,
      );
      final String? old;
      if (isInspector) {
        old = _inspectorSignaturePath;
        _inspectorSignaturePath = path;
      } else {
        old = _picSignaturePath;
        _picSignaturePath = path;
      }
      if (mounted) setState(() {});
      await _saveFinal();
      if (old != null && old != path) await _answerRepo.deletePhoto(old);
    } catch (e) {
      debugPrint('❌ Save signature error: $e');
      if (mounted) _showSnack('Could not save the signature.', isError: true);
    }
  }

  Future<void> _onSignatureCleared(bool isInspector) async {
    final String? old;
    if (isInspector) {
      old = _inspectorSignaturePath;
      _inspectorSignaturePath = null;
    } else {
      old = _picSignaturePath;
      _picSignaturePath = null;
    }
    if (mounted) setState(() {});
    await _saveFinal();
    await _answerRepo.deletePhoto(old);
  }

  /// Required Final Submit fields that are still empty.
  List<String> _missingFinalFields() => [
        if (_picSignDate == null) 'Person-in-Charge date',
        if (_picNameCtrl.text.trim().isEmpty) 'Person-in-Charge name',
        if (_inspectorSignDate == null) 'Inspector date',
        // From the dropdown: a real inspector id is required
        if (_inspectorList.isNotEmpty
            ? _realInspectorId == null
            : _inspectorNameCtrl.text.trim().isEmpty)
          'Inspector name',
      ];

  Future<void> _pickSignDate(bool isInspector) async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final first = DateTime(now.year - 2);
    final last = DateTime(now.year + 2);
    final current = DateTime.tryParse(
        (isInspector ? _inspectorSignDate : _picSignDate) ?? '');
    var initial = current ?? now;
    if (initial.isBefore(first) || initial.isAfter(last)) initial = now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      builder: (ctx, child) => Theme(data: _pickerTheme(ctx), child: child!),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isInspector) {
        _inspectorSignDate = _toDbDate(picked);
        _inspectorSignDateCtrl.text = _formatDate(picked);
      } else {
        _picSignDate = _toDbDate(picked);
        _picSignDateCtrl.text = _formatDate(picked);
      }
    });
    _saveFinal();
  }

  Future<String?> getAccessToken() async {
    final db = await DBManager.instance.database;
    final rows = await db.query(
      'auth_session',
      columns: ['access_token'],
      orderBy: 'logged_in_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final token = rows.first['access_token']?.toString().trim();
    return (token == null || token.isEmpty) ? null : token;
  }

  // ---------------- Base64 for the server (compressed) ----------------
  // Database = original file paths. Server = compressed base64 strings.

  /// DB paths may be relative ("MFI-3-.../photo.jpg") – resolve them
  /// against the app documents folder. null if empty or missing on device.
  Future<String?> _resolvePath(String? path) async {
    if (path == null || path.trim().isEmpty) return null;
    var full = path;
    if (!p.isAbsolute(path)) {
      final dir = await getApplicationDocumentsDirectory();
      full = p.join(dir.path, path);
    }
    if (!File(full).existsSync()) {
      debugPrint('⚠️ Photo missing on device, skipped: $full');
      return null;
    }
    return full;
  }

  /// Item photo → resized JPEG → base64. '' if the file is missing.
  Future<String> _photoBase64(String? dbPath) async {
    final path = await _resolvePath(dbPath);
    if (path == null) return '';
    try {
      final bytes = await FlutterImageCompress.compressWithFile(
        path,
        minWidth: _kUploadPhotoMaxSide, // scaled down to fit this box
        minHeight: _kUploadPhotoMaxSide,
        quality: _kUploadPhotoQuality,
        format: CompressFormat.jpeg,
        keepExif: false, // drop GPS / camera metadata
      );
      if (bytes == null || bytes.isEmpty) return await _fileBase64(path);
      return base64Encode(bytes);
    } catch (e) {
      debugPrint('❌ Compress photo error: $e');
      return await _fileBase64(path); // fallback: original file
    }
  }

  /// Signature → smaller PNG (keeps sharp lines) → base64. '' if missing.
  Future<String> _signatureBase64(String? dbPath) async {
    final path = await _resolvePath(dbPath);
    if (path == null) return '';
    try {
      final bytes = await FlutterImageCompress.compressWithFile(
        path,
        minWidth: _kUploadSignWidth,
        minHeight: _kUploadSignHeight,
        format: CompressFormat.png,
      );
      if (bytes == null || bytes.isEmpty) return await _fileBase64(path);
      return base64Encode(bytes);
    } catch (e) {
      debugPrint('❌ Compress signature error: $e');
      return await _fileBase64(path);
    }
  }

  /// Uncompressed fallback.
  Future<String> _fileBase64(String? path) async {
    final bytes = await _readFile(path);
    return bytes == null ? '' : base64Encode(bytes);
  }

  /// One item's photos (file paths from the DB) → compressed base64,
  /// one entry per slot (image, image1, image2, image3). '' = empty slot.
  Future<List<String>> _itemPhotosBase64(
      MobileFoodInspectionAnswerModel a) async {
    const slots = MobileFoodInspectionItemRequest.imageKeys;
    return [
      for (var i = 0; i < slots.length; i++)
        await _photoBase64(i < a.photos.length ? a.photos[i] : null),
    ];
  }

  // ---------------- Payload log ----------------

  /// Prints a request body as clean, copy-ready JSON (debug builds only).
  /// * developer.log → IDE Debug Console / Run tab (no length limit)
  /// * debugPrint in 800-char chunks → terminal (`flutter run`) and logcat,
  ///   so long JSON is not cut off.
  /// Long base64 strings are shortened unless [_kLogFullBase64] is true.
  void _logPayload(String title, Object? body) {
    if (!kDebugMode) return;
    try {
      final pretty = const JsonEncoder.withIndent('  ')
          .convert(_kLogFullBase64 ? body : _shortenBase64(body));
      developer.log(pretty, name: title); // IDE Debug Console
      debugPrint('📤 $title'); // terminal / logcat
      for (var i = 0; i < pretty.length; i += 800) {
        debugPrint(pretty.substring(i, (i + 800).clamp(0, pretty.length)));
      }
    } catch (e) {
      debugPrint('⚠️ Could not log payload for $title: $e');
    }
  }

  /// Copy of [v] with long strings (base64 images) replaced by a summary.
  Object? _shortenBase64(Object? v) {
    if (v is Map) {
      return {for (final e in v.entries) '${e.key}': _shortenBase64(e.value)};
    }
    if (v is List) return v.map(_shortenBase64).toList();
    if (v is String && v.length > 200) {
      return '<base64 ${v.length} chars: ${v.substring(0, 30)}…>';
    }
    return v;
  }

  Future<void> _onSubmit() async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();

    // ---- Required fields ----
    final missing = _missingFinalFields();
    if (_picSignaturePath == null) missing.add('Person-in-Charge signature');
    if (_inspectorSignaturePath == null) missing.add('Inspector signature');
    if (missing.isNotEmpty) {
      setState(() => _finalShowErrors = true);
      _showSnack('Please fill: ${missing.join(', ')}.', isError: true);
      return;
    }

    final id = _inspectionId;
    if (id == null) {
      _showSnack('Inspection not saved yet.', isError: true);
      return;
    }

    // Read the ViewModel before any await
    final inspectionVM = _inspectionVM;

    setState(() => _isSubmitting = true);
    try {
      // 0. Token from the auth_session table
      final token = await getAccessToken();
      if (token == null) {
        if (mounted) {
          _showSnack('Session expired. Please log in again.', isError: true);
        }
        return;
      }

      // 1. Flush every tab to the database (file paths are saved)
      await _saveAllAnswers();
      await _saveTemperatures();
      await _saveFinal();

      // 2. Answers from the TempFoodInspectionAnswer table
      final answers = await _answerRepo.loadAnswers(id);

      // 3. API 1 – /temp-food/inspection (skipped on retry if it already succeeded)
      if (_serverInspectionId == null) {
        final inspection = await inspectionVM.getById(id);
        final finalData = await _answerRepo.loadFinalSubmit(id);
        if (inspection == null || finalData == null) {
          if (mounted) {
            _showSnack('Saved inspection data not found.', isError: true);
          }
          return;
        }

        final request =
            await _buildSubmitRequest(inspection, finalData, answers);
        _logPayload('POST ${URLConstants.tempFoodInspection}', request.toJson());
        final result = await _apiRepo.submitInspection(request, token: token);
        if (!mounted) return;

        if (!result.isSuccess) {
          _showSnack(result.error ?? 'Submission failed.', isError: true);
          return;
        }

        _serverInspectionId = result.data?.inspectionId;
        debugPrint('✅ Inspection submitted. Server id: $_serverInspectionId');

        if (_serverInspectionId == null) {
          _showSnack('Server did not return an inspection ID.',
              isError: true);
          return;
        }
      }

      // 4. API 2 – /temp-food/inspection-item: checklist items, photos as COMPRESSED BASE64
      //    (skipped on retry if it already succeeded)
      if (!_itemsSubmitted) {
        final itemRequests = <MobileFoodInspectionItemRequest>[];
        for (final a in answers.values) {
          final req = MobileFoodInspectionItemRequest.fromAnswer(
            a,
            _serverInspectionId!,
            imagesBase64: await _itemPhotosBase64(a),
          );
          if (req.hasData) itemRequests.add(req); // skip untouched items
        }

        _logPayload(
          'POST ${URLConstants.tempFoodListSubmit} (${itemRequests.length} items)',
          TempFoodInspectionItemRepository.buildBody(itemRequests),
        );
        final itemResult = await _itemRepo.submitItems(
          items: itemRequests,
          token: token,
        );
        if (!mounted) return;

        if (!itemResult.isSuccess) {
          _showSnack(
            'Inspection saved, but items failed: ${itemResult.error}. '
            'Tap Submit to retry.',
            isError: true,
          );
          return;
        }
        _itemsSubmitted = true;
        debugPrint('✅ Items submitted for inspection $_serverInspectionId');
      }

      // 5. API 3 – /temp-food/item-temperature: Temperature Observations (from the DB table)
      final savedTemps = await _answerRepo.loadTemperatures(id);
      final tempRequests = savedTemps
          .map((t) =>
              MobileFoodTemperatureRequest.fromModel(t, _serverInspectionId!))
          .where((t) => t.hasData) // skip empty rows
          .toList();

      _logPayload(
        'POST ${URLConstants.tempFoodTemperatureSubmit} (${tempRequests.length} rows)',
        TempFoodTemperatureSubmitRepository.buildBody(tempRequests),
      );
      final tempResult = await _tempRepo.submitTemperatures(
        temperatures: tempRequests,
        token: token,
      );
      if (!mounted) return;

      if (!tempResult.isSuccess) {
        _showSnack(
          'Items saved, but temperatures failed: ${tempResult.error}. '
          'Tap Submit to retry.',
          isError: true,
        );
        return;
      }
      debugPrint('✅ Temperatures submitted for inspection $_serverInspectionId');

      // 6. Everything is on the server → remove it from Incomplete
      //    (all local tables for this inspection_id + its image files)
      _completed = true; // dispose() must not save it back
      for (final t in _commentTimers.values) {
        t.cancel();
      }
      _tempSaveTimer?.cancel();
      _finalSaveTimer?.cancel();
      try {
        await _inspectionVM.delete(id);
      } catch (e) {
        debugPrint('❌ Delete local inspection error: $e');
      }
      if (!mounted) return;

      // Stop the microphone before leaving
      await _voiceVM.closePanel();
      if (!mounted) return;

      // 7. Back to the Dashboard
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Inspection submitted successfully.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _kSuccess,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      // Dashboard is the first route under this screen.
      // If not, use: Navigator.of(context).pushAndRemoveUntil(
      //   MaterialPageRoute(builder: (_) => const DashboardScreen()),
      //   (_) => false);
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    } catch (e, st) {
      debugPrint('❌ Submit inspection error: $e\n$st');
      if (mounted) {
        _showSnack('Could not submit the inspection.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ---------------- Schedule id ----------------
  // Kept in TempFoodInspection.schedule_id so an incomplete inspection
  // started from a schedule still sends its schedule id later.

  static const _kScheduleCol = 'schedule_id';

  /// Adds the schedule_id column the first time (no DB version change).
  Future<Database> _scheduleDb() async {
    final db = await DBManager.instance.database;
    final cols = await db
        .rawQuery('PRAGMA table_info(${DBManager.tableTempFoodInspection})');
    if (!cols.any((c) => c['name'] == _kScheduleCol)) {
      await db.execute('ALTER TABLE ${DBManager.tableTempFoodInspection} '
          'ADD COLUMN $_kScheduleCol INTEGER');
    }
    return db;
  }

  Future<void> _saveScheduleId(String inspectionId) async {
    final id = _scheduleId;
    if (id == null || id <= 0) return; // not from a schedule
    try {
      final db = await _scheduleDb();
      await db.update(
        DBManager.tableTempFoodInspection,
        {_kScheduleCol: id},
        where: 'inspection_id = ?',
        whereArgs: [inspectionId],
      );
      debugPrint('📅 Saved schedule_id $id');
    } catch (e) {
      debugPrint('❌ Save schedule id error: $e');
    }
  }

  Future<int?> _loadScheduleId(String inspectionId) async {
    try {
      final db = await _scheduleDb();
      final rows = await db.query(
        DBManager.tableTempFoodInspection,
        columns: [_kScheduleCol],
        where: 'inspection_id = ?',
        whereArgs: [inspectionId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final v = rows.first[_kScheduleCol];
      final id = v is int ? v : int.tryParse('${v ?? ''}');
      return (id != null && id > 0) ? id : null;
    } catch (e) {
      debugPrint('❌ Load schedule id error: $e');
      return null;
    }
  }

  /// schedule_id for the submit request:
  /// 1. the schedule the form was opened from (or saved with it), else
  /// 2. a schedule for this permit in the Temp Food schedules list
  ///    (temp_food_inspection_schedules, synced on the Dashboard), else
  /// 3. 0 (not from a schedule).
  Future<int> _scheduleIdForApi(TempFoodInspectionModel inspection) async {
    var id = _scheduleId ?? await _loadScheduleId(inspection.inspectionId);
    id ??= await _scheduleIdForPermit(
      inspection.permitId,
      inspection.inspectionDate,
    );
    debugPrint('📅 schedule_id sent: ${id ?? 0} '
        '(permit ${inspection.permitId})');
    return id ?? 0;
  }

  /// The schedule of [permitId] closest to [inspectionDate] (yyyy-MM-dd);
  /// null when the permit has no schedule.
  Future<int?> _scheduleIdForPermit(int? permitId, String inspectionDate) async {
    if (permitId == null || permitId <= 0) return null;
    try {
      final db = await DBManager.instance.database;
      final rows = await db.rawQuery('''
        SELECT id FROM ${DBManager.tableTempFoodInspectionSchedules}
        WHERE temp_food_permit_id = ?
          AND IFNULL(deleted_at, '') = ''
          AND IFNULL(status, 1) != 0
        ORDER BY
          ABS(julianday(IFNULL(NULLIF(schedule_date, ''), '9999-12-31'))
              - julianday(?)) ASC,
          id DESC
        LIMIT 1
      ''', [permitId, inspectionDate]);
      if (rows.isEmpty) return null;
      final v = rows.first['id'];
      final id = v is int ? v : int.tryParse('${v ?? ''}');
      return (id != null && id > 0) ? id : null;
    } catch (e) {
      debugPrint('❌ Find schedule for permit error: $e');
      return null;
    }
  }

  /// Builds the API body from the DB rows.
  /// Signatures: DB path → compressed PNG → base64.
  Future<TempFoodInspectionRequest> _buildSubmitRequest(
    TempFoodInspectionModel inspection,
    MobileFoodFinalSubmitModel f,
    Map<int, MobileFoodInspectionAnswerModel> answers,
  ) async {
    final pic = inspection.personInCharge.isNotEmpty
        ? inspection.personInCharge
        : f.picName;

    // Required field: Submit is blocked earlier if it is missing.
    final inspectorId =
        await _inspectorIdForApi(inspection) ?? inspection.userId;
    debugPrint('👤 inspector_id sent: $inspectorId');

    return TempFoodInspectionRequest(
      inspectionDate: _apiDate(inspection.inspectionDate),
      tempFoodPermitId: inspection.permitId ?? 0, // temp_food_permit_id
      scheduleId: await _scheduleIdForApi(inspection), // schedule id or 0
      reinspectionDate:
          f.reinspectionDate == null ? '' : _apiDate(f.reinspectionDate!),
      timeIn: _apiTime(inspection.timeIn),
      timeOut: _apiTime(inspection.timeOut),
      purposeId: f.purpose == null ? null : _kPurposeIds[f.purpose],
      operationTypeId: f.operationTypeId,
      personInCharge: pic,
      otherInformation: f.otherInformation,
      violatedProvisions: '',
      repeatViolations: '',
      personInChargeDiscussion: f.discussion,
      inspectorId: inspectorId, // selected / default inspector's id
      personInChargeSign: await _signatureBase64(f.picSignature),
      inspectorSign: await _signatureBase64(f.inspectorSignature),
      personInChargeSignDate: _apiDate(f.picSignDate ?? ''),
      inspectorSignDate: _apiDate(f.inspectorSignDate ?? ''),
    );
  }

  /// yyyy-MM-dd → MM/dd/yyyy (Temp Food API date format)
  String _apiDate(String db) {
  final d = DateTime.tryParse(db);
  if (d == null) return db;
  return '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}-${d.year}';
}

  /// HH:mm → HH:mm:ss
  String _apiTime(String hhmm) {
    final t = _parseTime(hhmm);
    return t == null ? hhmm : _reportTime(t);
  }

  Widget _finalCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3EAF3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _textArea(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      minLines: 5,
      maxLines: 8,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(fontSize: 14, color: _kTextDark),
      decoration: _inputDecoration(hint: hint),
    );
  }

  Widget _buildVisitCard() {
    return _finalCard(children: [
      const _FieldLabel(label: 'Date of Reinspection'),
      const SizedBox(height: 6),
      TextField(
        controller: _reinspectionDateCtrl,
        readOnly: true,
        onTap: _pickReinspectionDate,
        style: const TextStyle(
            fontSize: 14, color: _kTextDark, fontWeight: FontWeight.w500),
        decoration: _inputDecoration(
          hint: 'MM-DD-YYYY',
          prefixIcon: Icons.calendar_month_outlined,
          suffixIcon: Icons.arrow_drop_down,
        ),
      ),
      const SizedBox(height: 14),
      const _FieldLabel(label: 'Purpose of Inspection'),
      const SizedBox(height: 6),
      DropdownButtonFormField<String>(
        value: _purpose,
        isExpanded: true,
        icon: const Icon(Icons.keyboard_arrow_down, color: _kPrimary),
        decoration: _inputDecoration(hint: 'Select purpose'),
        items: _kPurposes
            .map((p) => DropdownMenuItem(
                  value: p,
                  child: Text(p, style: const TextStyle(fontSize: 14)),
                ))
            .toList(),
        onChanged: (v) {
          setState(() => _purpose = v);
          _saveFinal();
        },
      ),
      const SizedBox(height: 14),
      const _FieldLabel(label: 'Operation Type'),
      const SizedBox(height: 6),
      DropdownButtonFormField<int>(
        value: _operationTypeId,
        isExpanded: true,
        icon: const Icon(Icons.keyboard_arrow_down, color: _kPrimary),
        decoration: _inputDecoration(hint: 'Select operation type'),
        items: _operationTypes
            .map((t) => DropdownMenuItem(
                  value: t.id,
                  child: Text(
                    t.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                ))
            .toList(),
        onChanged: (v) {
          setState(() => _operationTypeId = v);
          _saveFinal();
        },
      ),
      if (_operationTypes.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            'Operation types not downloaded yet. Sync on the Dashboard.',
            style: TextStyle(fontSize: 12, color: _kTextMuted),
          ),
        ),
    ]);
  }

  Widget _buildSignatureCard({
    required String title,
    required bool isInspector,
  }) {
    final path = isInspector ? _inspectorSignaturePath : _picSignaturePath;
    final dateCtrl = isInspector ? _inspectorSignDateCtrl : _picSignDateCtrl;
    final nameCtrl = isInspector ? _inspectorNameCtrl : _picNameCtrl;
    final dateMissing = _finalShowErrors &&
        (isInspector ? _inspectorSignDate : _picSignDate) == null;
    final nameMissing = _finalShowErrors && nameCtrl.text.trim().isEmpty;

    return _finalCard(children: [
      _FieldLabel(label: title),
      const SizedBox(height: 10),
      SignaturePad(
        key: ValueKey(isInspector ? 'sig_inspector' : 'sig_pic'),
        imagePath: path,
        onSigned: (png) => _onSigned(isInspector: isInspector, png: png),
        onCleared: () => _onSignatureCleared(isInspector),
      ),
      const SizedBox(height: 14),
      const _FieldLabel(label: 'Date', required: true),
      const SizedBox(height: 6),
      TextField(
        controller: dateCtrl,
        readOnly: true,
        onTap: () => _pickSignDate(isInspector),
        style: const TextStyle(
            fontSize: 14, color: _kTextDark, fontWeight: FontWeight.w500),
        decoration: _inputDecoration(
          hint: 'MM-DD-YYYY',
          prefixIcon: Icons.calendar_month_outlined,
          suffixIcon: Icons.arrow_drop_down,
        ).copyWith(errorText: dateMissing ? 'Date is required' : null),
      ),
      const SizedBox(height: 12),
      _FieldLabel(
        label: isInspector ? 'Inspector Name' : 'Person-in-Charge Name',
        required: true,
      ),
      const SizedBox(height: 6),
      // Inspector: same dropdown as the Establishment tab (name shown,
      // id sent to the API). Person-in-Charge: free text.
      if (isInspector && _inspectorList.isNotEmpty)
        _inspectorSelect(errorText: nameMissing ? 'Name is required' : null)
      else
        TextField(
          controller: nameCtrl,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(
              fontSize: 14, color: _kTextDark, fontWeight: FontWeight.w500),
          onChanged: (_) {
            if (_finalShowErrors) setState(() {}); // refresh error text
          },
          decoration: _inputDecoration(
            hint: isInspector
                ? 'Enter inspector name'
                : 'Enter person-in-charge name',
          ).copyWith(errorText: nameMissing ? 'Name is required' : null),
        ),
    ]);
  }

  Widget _buildFinalSubmitStep() {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 900; // 3 cards in a row (web layout)
      final medium = c.maxWidth >= 640; // tablet portrait
      const gap = SizedBox(width: 16, height: 16);

      final visit = _buildVisitCard();
      final discussion = _finalCard(children: [
        const _FieldLabel(label: 'Discussion with Person-in-Charge:'),
        const SizedBox(height: 10),
        _textArea(_discussionCtrl, 'Enter discussion'),
      ]);
      final other = _finalCard(children: [
        const _FieldLabel(label: 'Other Information:'),
        const SizedBox(height: 10),
        _textArea(_otherInfoCtrl, 'Enter other information'),
      ]);
      final picSig = _buildSignatureCard(
          title: 'Signature of Person-in-Charge:', isInspector: false);
      final inspSig = _buildSignatureCard(
          title: 'Signature of Inspector:', isInspector: true);

      Widget row(List<Widget> items) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) gap,
                Expanded(child: items[i]),
              ],
            ],
          );

      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (wide)
            row([visit, discussion, other])
          else if (medium) ...[
            visit,
            gap,
            row([discussion, other]),
          ] else ...[
            visit,
            gap,
            discussion,
            gap,
            other,
          ],
          gap,
          if (medium)
            row([picSig, inspSig])
          else ...[
            picSig,
            gap,
            inspSig,
          ],
        ],
      );
    });
  }

  // ---------- Step 5: Email (inspection report PDF) ----------

  String _reportFileName() {
    final name = _businessNameCtrl.text
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return '${name.isEmpty ? 'Temp_Food_Inspection' : name}.pdf';
  }

  String _reportTime(TimeOfDay? t) => t == null
      ? ''
      : '${t.hour.toString().padLeft(2, '0')}:'
          '${t.minute.toString().padLeft(2, '0')}:00';

  Future<Uint8List?> _readFile(String? path) async {
    if (path == null) return null;
    try {
      final f = File(path);
      return await f.exists() ? await f.readAsBytes() : null;
    } catch (_) {
      return null;
    }
  }

  /// Collects everything entered on the 4 tabs for the report.
  Future<MobileFoodReportData> _reportData() async {
    String? opName;
    for (final t in _operationTypes) {
      if (t.id == _operationTypeId) opName = t.name;
    }
    final d = _inspectionDate;

    // Item answers + their photos (read from the saved image files)
    final answers = <int, ReportItemAnswer>{};
    for (final e in _answers.entries) {
      final photos = <Uint8List>[];
      for (final path in e.value.photos) {
        final bytes = await _readFile(path);
        if (bytes != null) photos.add(bytes);
      }
      answers[e.key] = ReportItemAnswer(
        result: e.value.result,
        cos: e.value.cos,
        repeat: e.value.repeat,
        comment: e.value.comment,
        photos: photos,
      );
    }

    return MobileFoodReportData(
      reportType: ReportType.food, // TODO: use ReportType.tempFood if your PDF builder has one
      businessName: _businessNameCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      telephone: _telephoneCtrl.text.trim(),
      permitNumber: _permitNumberCtrl.text.trim(),
      applicant: _applicantNameCtrl.text.trim(),
      personInCharge: _personInChargeCtrl.text.trim(),
      inspector: _selectedInspectorName,
      date: d == null
          ? ''
          : '${d.month.toString().padLeft(2, '0')}/'
              '${d.day.toString().padLeft(2, '0')}/${d.year}',
      timeIn: _reportTime(_timeIn),
      timeOut: _reportTime(_timeOut),
      checklist: _pdfChecklist(),
      answers: answers,
      temperatures: [
        for (final r in _tempRows)
          if (r.itemCtrl.text.trim().isNotEmpty ||
              r.tempCtrl.text.trim().isNotEmpty)
            ReportTemperature(r.itemCtrl.text.trim(), r.tempCtrl.text.trim()),
      ],
      reinspectionDate: _reinspectionDateCtrl.text,
      discussion: _discussionCtrl.text.trim(),
      operationType: opName ?? '',
      inspectionType: _purpose ?? '',
      otherInformation: _otherInfoCtrl.text.trim(),
      picSignature: await _readFile(_picSignaturePath),
      picSignDate: _picSignDateCtrl.text,
      inspectorSignature: await _readFile(_inspectorSignaturePath),
      inspectorSignDate: _inspectorSignDateCtrl.text,
    );
  }

  /// The PDF builder takes the Mobile Food checklist classes; the Food
  /// rows have the same fields, so they are copied over 1:1.
  List<ChecklistSectionNode> _pdfChecklist() => [
        for (final s in _checklist)
          ChecklistSectionNode(
            MobileFoodSectionModel.fromJson(s.section.toJson()),
            [
              for (final p in s.parts)
                ChecklistPartNode(
                  MobileFoodSectionPartModel.fromJson(p.part.toJson()),
                  [
                    for (final i in p.items)
                      MobileFoodItemModel.fromJson(i.toJson()),
                  ],
                ),
            ],
          ),
      ];

  Future<Uint8List> _generateReport() async =>
      MobileFoodReportPdf.build(await _reportData());

  /// Opens the share sheet with the PDF (choose Mail / Gmail / Outlook).
  Future<void> _emailReport() async {
    try {
      final bytes = await (_reportFuture ??= _generateReport());
      await Printing.sharePdf(
        bytes: bytes,
        filename: _reportFileName(),
        subject: 'Temporary Food Inspection Report - '
            '${_businessNameCtrl.text.trim()}',
      );
    } catch (e) {
      debugPrint('❌ Share report error: $e');
      if (mounted) _showSnack('Could not open the PDF.', isError: true);
    }
  }

  Widget _buildEmailStep() {
    final future = _reportFuture ??= _generateReport();
    return Container(
      color: const Color(0xFFE9ECF1),
      child: PdfPreview(
        build: (_) => future,
        pdfFileName: _reportFileName(),
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        loadingWidget: const CircularProgressIndicator(color: _kPrimary),
        onError: (context, error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not create the PDF.\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kError),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Placeholder (unused steps) ----------

  Widget _buildPlaceholderStep(String title) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionCard(
          title: title,
          icon: Icons.construction_outlined,
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'This section will be added next.',
                  style: TextStyle(color: _kTextMuted, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------- Bottom bar ----------

  Widget _buildBottomBar() {
    final isFirst = _currentStep == 0;
    final isLast = _currentStep == _steps.length - 1;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              if (!isFirst)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSubmitting
                        ? null
                        : () => _goToStep(_currentStep - 1),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kPrimary,
                      side: const BorderSide(color: _kPrimary),
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              if (!isFirst) const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting
                      ? null
                      : (isLast
                          ? _emailReport
                          : (_currentStep == 3
                              ? _onSubmit
                              : () => _goToStep(_currentStep + 1))),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(isLast
                          ? Icons.email_outlined
                          : (_currentStep == 3
                              ? Icons.check_circle_outline
                              : Icons.arrow_forward)),
                  label: Text(_isSubmitting
                      ? 'Submitting...'
                      : (isLast
                          ? 'Email PDF'
                          : (_currentStep == 3
                              ? 'Submit'
                              : 'Next: ${_steps[_currentStep + 1]}'))),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- Reusable widgets ----------------

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? subtitle;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3EAF3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFEEF2F7))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: _kPrimary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _kTextDark,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style:
                              const TextStyle(fontSize: 12, color: _kTextMuted),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

/// Places fields side-by-side on tablets, stacked on phones.
class _ResponsiveRow extends StatelessWidget {
  final List<Widget> children;
  final List<int> flex;

  const _ResponsiveRow({required this.children, required this.flex});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 640;

      if (!wide) {
        return Column(
          children: children
              .map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: c,
                  ))
              .toList(),
        );
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 14),
              Expanded(
                flex: i < flex.length ? flex[i] : 1,
                child: children[i],
              ),
            ],
          ],
        ),
      );
    });
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool required;
  final bool locked;

  const _FieldLabel({
    required this.label,
    this.required = false,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _kTextDark,
        ),
        children: [
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: _kError, fontWeight: FontWeight.w700),
            ),
        ],
      ),
    );
  }
}

/// One editable row of the Temperature Observations tab.
class _TempRow {
  /// Stable key so rows keep their state when another row is deleted
  final int key;
  final TextEditingController itemCtrl;
  final TextEditingController tempCtrl;
  final FocusNode itemFocus = FocusNode();

  String _lastItem;
  String _lastTemp;

  _TempRow({
    required this.key,
    String itemLocation = '',
    String temperature = '',
  })  : itemCtrl = TextEditingController(text: itemLocation),
        tempCtrl = TextEditingController(text: temperature),
        _lastItem = itemLocation,
        _lastTemp = temperature;

  /// Calls [save] only when the text really changed
  /// (controllers also notify on cursor / selection moves).
  VoidCallback onChanged(VoidCallback save) => () {
        if (itemCtrl.text == _lastItem && tempCtrl.text == _lastTemp) return;
        _lastItem = itemCtrl.text;
        _lastTemp = tempCtrl.text;
        save();
      };

  void dispose() {
    itemCtrl.dispose();
    tempCtrl.dispose();
    itemFocus.dispose();
  }
}

/// What the inspector entered for one item.
/// Mirrors a row of the TempFoodInspectionAnswer table.
class _ItemAnswer {
  /// OUT / IN / NO / NA
  String? result;

  /// Corrected on site (only with OUT)
  bool cos = false;

  /// Repeat violation (only with OUT)
  bool repeat = false;

  String comment = '';

  /// Absolute file paths, one per photo slot (saved in the DB as paths)
  final List<String?> photos = List<String?>.filled(_kPhotoSlots, null);

  _ItemAnswer();

  /// Snapshot used by voice "undo".
  _ItemAnswer copy() {
    final c = _ItemAnswer()
      ..result = result
      ..cos = cos
      ..repeat = repeat
      ..comment = comment;
    for (var i = 0; i < photos.length; i++) {
      c.photos[i] = photos[i];
    }
    return c;
  }

  factory _ItemAnswer.fromModel(MobileFoodInspectionAnswerModel m) {
    final a = _ItemAnswer()
      ..result = m.result
      ..cos = m.cos
      ..repeat = m.repeat
      ..comment = m.comment;
    for (var i = 0; i < _kPhotoSlots && i < m.photos.length; i++) {
      final path = m.photos[i];
      // Skip photos whose file was removed from the device
      a.photos[i] = (path != null && File(path).existsSync()) ? path : null;
    }
    return a;
  }

  MobileFoodInspectionAnswerModel toModel(String inspectionId, int itemId) =>
      MobileFoodInspectionAnswerModel(
        inspectionId: inspectionId,
        itemId: itemId,
        result: result,
        cos: cos,
        repeat: repeat,
        comment: comment,
        photos: List<String?>.from(photos),
      );
}