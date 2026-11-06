import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quincy/AI/AIBrain.dart';

import 'package:quincy/AI/GeneralAssitant.dart';

import 'package:quincy/AI/ItemAnswerVoiceParser.dart';
import 'package:quincy/AI/SubmitFlowReply.dart';
import 'package:quincy/Dashboard/Model/InspectionMenu.dart';

import 'package:quincy/Dashboard/View/AIGuidePanel.dart';

import 'package:quincy/Dashboard/View/ModeSelectionDialog.dart';
import 'package:quincy/Dashboard/ViewModel/DashboardViewModel.dart';
import 'package:quincy/Dashboard/ViewModel/VoiceAssistantViewModel.dart';

import 'package:quincy/Dashboard/Voice/VoiceCommandParser.dart';
import 'package:quincy/Database/DBManager.dart';
import 'package:quincy/Inspections/Food/Model/FoodPermitModel.dart';
import 'package:quincy/Inspections/Food/Schedule/View/FoodInspectionScheduleScreen.dart';
import 'package:quincy/Inspections/Food/Schedule/ViewModel/FoodInspectionScheduleViewModel.dart';
import 'package:quincy/Inspections/Food/View/FoodIncompleteScreen.dart';

import 'package:quincy/Inspections/MobileFood/View/MobileFoodPermitList.dart';
import 'package:quincy/Inspections/Food/View/FoodPermitListScreen.dart';
import 'package:quincy/Inspections/Food/ViewModel/FoodPermitViewModel.dart';
import 'package:quincy/Inspections/Food/View/FoodDetailsScreen.dart';

import 'package:quincy/Inspections/Food/ViewModel/FoodChecklistViewModel.dart';

import 'package:quincy/Inspections/TempFood/Model/TempFoodPermitModel.dart';
import 'package:quincy/Inspections/TempFood/Schedule/View/TempFoodInspectionScheduleScreen.dart';
import 'package:quincy/Inspections/TempFood/Schedule/ViewModel/TempFoodInspectionScheduleViewModel.dart';
import 'package:quincy/Inspections/TempFood/View/TempFoodDetailsScreen.dart';
import 'package:quincy/Inspections/TempFood/View/TempFoodIncompleteScreen.dart';
import 'package:quincy/Inspections/TempFood/View/TempFoodPermitListScreen.dart';
import 'package:quincy/Inspections/TempFood/ViewModel/TempFoodChecklistViewModel.dart';
import 'package:quincy/Inspections/TempFood/ViewModel/TempFoodPermitViewModel.dart';

import 'package:quincy/Inspections/Tobacco/Model/TobaccoPermitModel.dart';
import 'package:quincy/Inspections/Tobacco/Schedule/View/TobaccoInspectionScheduleScreen.dart';
import 'package:quincy/Inspections/Tobacco/Schedule/ViewModel/TobaccoInspectionScheduleViewModel.dart';
import 'package:quincy/Inspections/Tobacco/View/TobaccoDetailsScreen.dart';
import 'package:quincy/Inspections/Tobacco/View/TobaccoIncompleteListScreen.dart';
import 'package:quincy/Inspections/Tobacco/View/TobaccoPermitListScreen.dart';
import 'package:quincy/Inspections/Tobacco/ViewModel/TobaccoChecklistViewModel.dart';

import 'package:quincy/Inspections/Tobacco/ViewModel/TobaccoInspectionViewModel.dart';


import 'package:quincy/Inspections/MobileFood/Model/MobileFoodOperationTypeViewModel.dart';
import 'package:quincy/Inspections/MobileFood/Model/MobileFoodPermitModel.dart';
import 'package:quincy/Inspections/MobileFood/Schedule/View/MobileInspectionScheduleView.dart';
import 'package:quincy/Inspections/MobileFood/Schedule/ViewModel/MobileFoodInspectionScheduleViewModel.dart';

import 'package:quincy/Inspections/MobileFood/View/FoodMobileDetailsScreen.dart';
import 'package:quincy/Inspections/MobileFood/View/MobileFoodIncompleteScreen.dart';

import 'package:quincy/Inspections/MobileFood/View/MobileFoodPermitList.dart';

import 'package:quincy/Inspections/MobileFood/ViewModel/MobileFoodChecklistViewModel.dart';

import 'package:quincy/Inspections/MobileFood/ViewModel/MobileFoodPermitViewModel.dart';
import 'package:quincy/Inspections/Tobacco/ViewModel/TobaccoPermitViewModel.dart';

import 'package:quincy/Inspector/ViewModel/InspectorViewModel.dart';
import 'package:quincy/Login/View/login.dart';
import 'package:quincy/Login/ViewModel/LoginViewModel.dart';
import 'package:quincy/Utilities/SyncStatus.dart';
import 'package:quincy/Utilities/smartLoader.dart';

const Map<String, IconData> _iconMap = {
  'restaurant': Icons.restaurant,
  'tobacco': Icons.smoke_free,
  'nursing': Icons.elderly,
  'pool': Icons.pool,
  'complaint': Icons.report_problem_outlined,
  'food': Icons.fastfood_outlined,
  'temp_food': Icons.storefront_outlined,
  'mobile_food': Icons.local_shipping_outlined,
  'new': Icons.add_circle_outline,
  'incomplete': Icons.pending_actions,
  'schedule': Icons.event_note,
};

IconData _icon(String key) => _iconMap[key] ?? Icons.folder_outlined;

/// Words ignored when matching a spoken business name.
const Set<String> _businessStopWords = {
  'open', 'start', 'show', 'find', 'search', 'select', 'pick', 'choose',
  'mobile', 'food', 'new', 'incomplete', 'inspection', 'inspections',
  'permit', 'permits', 'schedule', 'schedules', 'my', 'temp', 'temporary',
  'business', 'for', 'a', 'an', 'and', 'of', 'to', 'with', 'list', 'me',
  'tobacco',
};

/// Which schedule list to open.
enum _ScheduleKind { food, tempFood, mobileFood, tobacco }

class DashboardScreen extends StatefulWidget {
  final AppMode mode;

  const DashboardScreen({super.key, required this.mode});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final VoiceAssistantViewModel _voiceVM = VoiceAssistantViewModel();
  final Map<int, GlobalKey> _tileKeys = {};

  // Controllers so voice commands can "tap" tiles programmatically.
  // NOTE: On Flutter 3.32+ replace ExpansionTileController with
  // ExpansibleController (same expand/collapse/isExpanded API).
  final Map<int, ExpansionTileController> _inspCtrls = {};
  final Map<String, ExpansionTileController> _catCtrls = {};

  bool get _isAi => widget.mode == AppMode.ai;

  /// Conversation manager: follow-up questions, fuzzy names, DB answers.
  late final VoiceAssistantBrain _brain = VoiceAssistantBrain(
    permits: () => context.read<MobileFoodPermitViewModel>().permits,
    userId: () => context.read<LoginViewModel>().user?.id,
    menuTitles: () => context
        .read<DashboardViewModel>()
        .menu
        .map((m) => m.title)
        .toList(),
    openPermitList: _openPermitList,
    openIncompleteList: _openIncompleteList,
    openInspection: _openInspection,
  );

  /// "Submit my inspection" conversation:
  /// type → business name → date & time (only if needed) → auto submit.
  late final VoiceSubmitFlow _submitFlow = VoiceSubmitFlow(
    userId: () => context.read<LoginViewModel>().user?.id,
  );

  /// Anything outside the app: news, weather, general questions (Claude with
  /// web search) and places (Google Maps).
  final GeneralAssistant _general = GeneralAssistant();

  /// Food permits saved in SQLite – used for voice business-name matching.
  List<FoodPermitModel> _foodPermits = [];

  /// Temporary Food permits saved in SQLite – voice business-name matching.
  List<TempFoodPermitModel> _tempFoodPermits = [];

  /// Tobacco permits saved in SQLite – voice business-name matching.
  List<TobaccoPermitModel> _tobaccoPermits = [];

  /// "Open schedules" asked "Food or Mobile Food?" → next answer picks one.
  bool _awaitingScheduleChoice = false;

  // ---- API sync / smart loader ----
  bool _syncStarted = false;
  bool _syncRunning = false;
  bool _syncVisible = false;

  /// Full-screen loader only when nothing is saved yet (first sync).
  bool _syncBlocking = false;

  ExpansionTileController _inspCtrl(int id) =>
      _inspCtrls.putIfAbsent(id, () => ExpansionTileController());

  ExpansionTileController _catCtrl(int inspId, int catId) =>
      _catCtrls.putIfAbsent('${inspId}_$catId', () => ExpansionTileController());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final loginVM = context.read<LoginViewModel>();
      final dashboardVM = context.read<DashboardViewModel>();

      if (loginVM.user == null) await loginVM.loadSavedUser();
      if (!mounted) return;

      // Fetch permits + sections + section parts + items + operation types
      // + inspectors + inspection schedules + food permits
      // + food sections / section parts / items + food schedules → save to DB
      await _prepareSync();
      if (!mounted) return;
      final sync = _runSync();

      await dashboardVM.loadMenu();

      // First sync: wait for data before the AI starts talking
      if (_syncBlocking) await sync;

      if (!mounted || !_isAi) return;

      _voiceVM.onCommand = _handleVoiceCommand;
      await _voiceVM.init();
      if (!mounted) return;
      await _voiceVM.greet(loginVM.user?.firstName ?? '');
    });
  }

  @override
  void dispose() {
    _ownChecklistVM?.dispose();
    _ownInspectorVM?.dispose();
    _ownScheduleVM?.dispose();
    _ownFoodPermitVM?.dispose();
    _ownFoodChecklistVM?.dispose();
    _ownFoodScheduleVM?.dispose();
    _ownTempFoodPermitVM?.dispose();
    _ownTempFoodChecklistVM?.dispose();
    _ownTempFoodScheduleVM?.dispose();
    _ownTobaccoPermitVM?.dispose();
    _ownTobaccoChecklistVM?.dispose();
    _ownTobaccoScheduleVM?.dispose();
    _opTypesVM.dispose();
    _voiceVM.dispose();
    super.dispose();
  }

  // ---------------- API sync (smart loader) ----------------

  /// Used only if MobileFoodChecklistViewModel is not registered in main.dart.
  MobileFoodChecklistViewModel? _ownChecklistVM;

  /// Used only if InspectorViewModel is not registered in main.dart.
  InspectorViewModel? _ownInspectorVM;

  /// Used only if MobileFoodInspectionScheduleViewModel is not registered
  /// in main.dart.
  MobileFoodInspectionScheduleViewModel? _ownScheduleVM;

  /// Used only if FoodPermitViewModel is not registered in main.dart.
  FoodPermitViewModel? _ownFoodPermitVM;

  /// Used only if FoodChecklistViewModel is not registered in main.dart.
  FoodChecklistViewModel? _ownFoodChecklistVM;

  /// Used only if FoodInspectionScheduleViewModel is not registered
  /// in main.dart.
  FoodInspectionScheduleViewModel? _ownFoodScheduleVM;

  /// Used only if TempFoodPermitViewModel is not registered in main.dart.
  TempFoodPermitViewModel? _ownTempFoodPermitVM;

  /// Used only if TempFoodChecklistViewModel is not registered in main.dart.
  TempFoodChecklistViewModel? _ownTempFoodChecklistVM;

  /// Used only if TempFoodInspectionScheduleViewModel is not registered
  /// in main.dart.
  TempFoodInspectionScheduleViewModel? _ownTempFoodScheduleVM;

  /// Used only if TobaccoPermitViewModel is not registered in main.dart.
  TobaccoPermitViewModel? _ownTobaccoPermitVM;

  /// Used only if TobaccoChecklistViewModel is not registered in main.dart.
  TobaccoChecklistViewModel? _ownTobaccoChecklistVM;

  /// Used only if TobaccoInspectionScheduleViewModel is not registered
  /// in main.dart.
  TobaccoInspectionScheduleViewModel? _ownTobaccoScheduleVM;

  /// operation-types API → mobile_food_operation_types table
  final MobileFoodOperationTypeViewModel _opTypesVM =
      MobileFoodOperationTypeViewModel();

  /// The app-wide checklist ViewModel, or a local one as a safe fallback.
  MobileFoodChecklistViewModel get _checklistVM {
    try {
      return Provider.of<MobileFoodChecklistViewModel>(context, listen: false);
    } on ProviderNotFoundException {
      debugPrint('⚠️ MobileFoodChecklistViewModel is not registered in '
          'main.dart – using a local instance.');
      return _ownChecklistVM ??= MobileFoodChecklistViewModel();
    }
  }

  /// inspector API → inspectors table.
  InspectorViewModel get _inspectorVM {
    try {
      return Provider.of<InspectorViewModel>(context, listen: false);
    } on ProviderNotFoundException {
      debugPrint('⚠️ InspectorViewModel is not registered in '
          'main.dart – using a local instance.');
      return _ownInspectorVM ??= InspectorViewModel();
    }
  }

  /// mobile-food/get-inspection-shedules → mobile_food_inspection_schedules.
  MobileFoodInspectionScheduleViewModel get _scheduleVM {
    try {
      return Provider.of<MobileFoodInspectionScheduleViewModel>(context,
          listen: false);
    } on ProviderNotFoundException {
      debugPrint('⚠️ MobileFoodInspectionScheduleViewModel is not registered '
          'in main.dart – using a local instance.');
      return _ownScheduleVM ??= MobileFoodInspectionScheduleViewModel();
    }
  }

  /// food/get-permit-list API → food_permits table.
  FoodPermitViewModel get _foodPermitVM {
    try {
      return Provider.of<FoodPermitViewModel>(context, listen: false);
    } on ProviderNotFoundException {
      debugPrint('⚠️ FoodPermitViewModel is not registered '
          'in main.dart – using a local instance.');
      return _ownFoodPermitVM ??= FoodPermitViewModel();
    }
  }

  /// food sections / section parts / items → food checklist tables.
  FoodChecklistViewModel get _foodChecklistVM {
    try {
      return Provider.of<FoodChecklistViewModel>(context, listen: false);
    } on ProviderNotFoundException {
      debugPrint('⚠️ FoodChecklistViewModel is not registered '
          'in main.dart – using a local instance.');
      return _ownFoodChecklistVM ??= FoodChecklistViewModel();
    }
  }

  /// food/get-inspection-shedules → food_inspection_schedules table.
  FoodInspectionScheduleViewModel get _foodScheduleVM {
    try {
      return Provider.of<FoodInspectionScheduleViewModel>(context,
          listen: false);
    } on ProviderNotFoundException {
      debugPrint('⚠️ FoodInspectionScheduleViewModel is not registered '
          'in main.dart – using a local instance.');
      return _ownFoodScheduleVM ??= FoodInspectionScheduleViewModel();
    }
  }

  /// temp-food/get-permit-list API → temp_food_permits table.
  TempFoodPermitViewModel get _tempFoodPermitVM {
    try {
      return Provider.of<TempFoodPermitViewModel>(context, listen: false);
    } on ProviderNotFoundException {
      debugPrint('⚠️ TempFoodPermitViewModel is not registered '
          'in main.dart – using a local instance.');
      return _ownTempFoodPermitVM ??= TempFoodPermitViewModel();
    }
  }

  /// temp-food sections / section parts / items → temp food checklist tables.
  TempFoodChecklistViewModel get _tempFoodChecklistVM {
    try {
      return Provider.of<TempFoodChecklistViewModel>(context, listen: false);
    } on ProviderNotFoundException {
      debugPrint('⚠️ TempFoodChecklistViewModel is not registered '
          'in main.dart – using a local instance.');
      return _ownTempFoodChecklistVM ??= TempFoodChecklistViewModel();
    }
  }

  /// temp-food/get-inspection-shedules-by-pagination
  /// → temp_food_inspection_schedules table.
  TempFoodInspectionScheduleViewModel get _tempFoodScheduleVM {
    try {
      return Provider.of<TempFoodInspectionScheduleViewModel>(context,
          listen: false);
    } on ProviderNotFoundException {
      debugPrint('⚠️ TempFoodInspectionScheduleViewModel is not registered '
          'in main.dart – using a local instance.');
      return _ownTempFoodScheduleVM ??= TempFoodInspectionScheduleViewModel();
    }
  }

  /// tobacco/get-permit-list-by-pagination → tobacco_permits table.
  TobaccoPermitViewModel get _tobaccoPermitVM {
    try {
      return Provider.of<TobaccoPermitViewModel>(context, listen: false);
    } on ProviderNotFoundException {
      debugPrint('⚠️ TobaccoPermitViewModel is not registered '
          'in main.dart – using a local instance.');
      return _ownTobaccoPermitVM ??= TobaccoPermitViewModel();
    }
  }

  /// tobacco/get-section-details → tobacco checklist tables.
  TobaccoChecklistViewModel get _tobaccoChecklistVM {
    try {
      return Provider.of<TobaccoChecklistViewModel>(context, listen: false);
    } on ProviderNotFoundException {
      debugPrint('⚠️ TobaccoChecklistViewModel is not registered '
          'in main.dart – using a local instance.');
      return _ownTobaccoChecklistVM ??= TobaccoChecklistViewModel();
    }
  }

  /// tobacco/get-inspection-schedules-by-pagination
  /// → tobacco_inspection_schedules table.
  TobaccoInspectionScheduleViewModel get _tobaccoScheduleVM {
    try {
      return Provider.of<TobaccoInspectionScheduleViewModel>(context,
          listen: false);
    } on ProviderNotFoundException {
      debugPrint('⚠️ TobaccoInspectionScheduleViewModel is not registered '
          'in main.dart – using a local instance.');
      return _ownTobaccoScheduleVM ??= TobaccoInspectionScheduleViewModel();
    }
  }

  /// Reloads the saved tobacco permits (for voice business names).
  Future<void> _reloadTobaccoPermits() async {
    try {
      _tobaccoPermits = await DBManager.instance.getTobaccoPermits();
    } catch (e) {
      debugPrint('⚠️ Tobacco permits DB read error: $e');
    }
  }

  /// Reloads the saved temporary food permits (for voice business names).
  Future<void> _reloadTempFoodPermits() async {
    try {
      _tempFoodPermits = await DBManager.instance.getTempFoodPermits();
    } catch (e) {
      debugPrint('⚠️ Temp Food permits DB read error: $e');
    }
  }

  /// Reloads the saved food permits (for voice business names).
  Future<void> _reloadFoodPermits() async {
    try {
      _foodPermits = await DBManager.instance.getFoodPermits();
    } catch (e) {
      debugPrint('⚠️ Food permits DB read error: $e');
    }
  }

  /// Prepare + run (used by Retry).
  Future<void> _startSync() async {
    if (_syncRunning) return;
    await _prepareSync();
    await _runSync();
  }

  /// Loads what is already saved and decides blocking vs compact loader.
  Future<void> _prepareSync() async {
    final permitVM = context.read<MobileFoodPermitViewModel>();
    final checklistVM = _checklistVM;
    final inspectorVM = _inspectorVM;
    final scheduleVM = _scheduleVM;
    final foodPermitVM = _foodPermitVM;
    final foodChecklistVM = _foodChecklistVM;
    final foodScheduleVM = _foodScheduleVM;
    final tempFoodPermitVM = _tempFoodPermitVM;
    final tempFoodChecklistVM = _tempFoodChecklistVM;
    final tempFoodScheduleVM = _tempFoodScheduleVM;
    final tobaccoPermitVM = _tobaccoPermitVM;
    final tobaccoChecklistVM = _tobaccoChecklistVM;
    final tobaccoScheduleVM = _tobaccoScheduleVM;
    await Future.wait([
      permitVM.loadLocalPermits(),
      checklistVM.loadLocal(),
      _opTypesVM.loadFromDb(),
      inspectorVM.loadFromDb(),
      scheduleVM.loadFromDb(),
      foodPermitVM.loadFromDb(),
      foodChecklistVM.loadLocal(),
      foodScheduleVM.loadFromDb(),
      _reloadFoodPermits(),
      tempFoodPermitVM.loadFromDb(),
      tempFoodChecklistVM.loadLocal(),
      tempFoodScheduleVM.loadFromDb(),
      _reloadTempFoodPermits(),
      tobaccoPermitVM.loadFromDb(),
      tobaccoChecklistVM.loadLocal(),
      tobaccoScheduleVM.loadFromDb(),
      _reloadTobaccoPermits(),
    ]);
    if (!mounted) return;
    // Schedules, food / temp food permits and their checklists are NOT part of the
    // blocking check, so a new / failing API never blocks the whole app
    // on every launch.
    _syncBlocking = permitVM.permits.isEmpty ||
        !checklistVM.hasLocalData ||
        _opTypesVM.operationTypes.isEmpty ||
        !inspectorVM.hasData;
  }

  /// Calls all APIs in parallel and saves each response to its table.
  Future<void> _runSync() async {
    if (_syncRunning || !mounted) return;
    final permitVM = context.read<MobileFoodPermitViewModel>();
    final checklistVM = _checklistVM;
    final inspectorVM = _inspectorVM;
    final scheduleVM = _scheduleVM;
    final foodPermitVM = _foodPermitVM;
    final foodChecklistVM = _foodChecklistVM;
    final foodScheduleVM = _foodScheduleVM;
    final tempFoodPermitVM = _tempFoodPermitVM;
    final tempFoodChecklistVM = _tempFoodChecklistVM;
    final tempFoodScheduleVM = _tempFoodScheduleVM;
    final tobaccoPermitVM = _tobaccoPermitVM;
    final tobaccoChecklistVM = _tobaccoChecklistVM;
    final tobaccoScheduleVM = _tobaccoScheduleVM;

    setState(() {
      _syncStarted = true;
      _syncRunning = true;
      _syncVisible = true;
    });

    await Future.wait([
      permitVM.fetchPermits(), // get-permit-list
      checklistVM.syncAll(), // sections-list + section-parts-list + items-list
      _opTypesVM.syncOperationTypes(), // operation-types → DB
      inspectorVM.syncInspectors(), // inspector → inspectors table
      scheduleVM.syncSchedules(), // mobile food schedules (paged)
      foodPermitVM.syncPermits(), // food/get-permit-list → food_permits table
      foodChecklistVM.sync(), // food sections + section parts + items → DB
      foodScheduleVM.syncSchedules(), // food schedules (paged)
      tempFoodPermitVM.syncPermits(), // temp-food/get-permit-list
      tempFoodChecklistVM.sync(), // temp food sections + parts + items → DB
      tempFoodScheduleVM.syncSchedules(), // temp food schedules (paged)
      tobaccoPermitVM.syncPermits(), // tobacco/get-permit-list-by-pagination
      tobaccoChecklistVM.sync(), // tobacco/get-section-details → DB
      tobaccoScheduleVM.syncSchedules(), // tobacco schedules (paged)
    ]);
    if (!mounted) return;

    // Schedules were read back while permits were still syncing in
    // parallel → re-read so business names / permit numbers are joined.
    await Future.wait([
      scheduleVM.loadFromDb(),
      foodScheduleVM.loadFromDb(),
      _reloadFoodPermits(),
      tempFoodScheduleVM.loadFromDb(),
      _reloadTempFoodPermits(),
      tobaccoScheduleVM.loadFromDb(),
      _reloadTobaccoPermits(),
    ]);
    if (!mounted) return;

    setState(() => _syncRunning = false);

    // Everything downloaded → show "up to date" briefly, then hide.
    final allOk = _syncTasks(permitVM, checklistVM, inspectorVM, scheduleVM,
            foodPermitVM, foodChecklistVM, foodScheduleVM)
        .every((t) => t.status == SyncStatus.done);
    if (allOk) {
      await Future.delayed(const Duration(milliseconds: 1400));
      if (mounted && !_syncRunning) setState(() => _syncVisible = false);
    }
  }

  SyncStatus _permitStatus(MobileFoodPermitViewModel vm) {
    if (!_syncStarted) return SyncStatus.pending;
    if (vm.isLoading) return SyncStatus.loading;
    if (vm.isOffline) {
      return vm.permits.isEmpty ? SyncStatus.failed : SyncStatus.offline;
    }
    return SyncStatus.done;
  }

  SyncStatus _opTypesStatus() {
    if (!_syncStarted) return SyncStatus.pending;
    if (_opTypesVM.isLoading) return SyncStatus.loading;
    if (_opTypesVM.error != null) {
      return _opTypesVM.operationTypes.isEmpty
          ? SyncStatus.failed
          : SyncStatus.offline;
    }
    return SyncStatus.done;
  }

  /// Shared rule: loading → loading, error + saved rows → offline,
  /// error + nothing saved → failed, otherwise done.
  SyncStatus _vmStatus({
    required bool isLoading,
    required String? error,
    required bool hasData,
  }) {
    if (!_syncStarted) return SyncStatus.pending;
    if (isLoading) return SyncStatus.loading;
    if (error != null) return hasData ? SyncStatus.offline : SyncStatus.failed;
    return SyncStatus.done;
  }

  SyncStatus _inspectorStatus(InspectorViewModel vm) =>
      _vmStatus(isLoading: vm.isLoading, error: vm.error, hasData: vm.hasData);

  SyncStatus _scheduleStatus(MobileFoodInspectionScheduleViewModel vm) =>
      _vmStatus(isLoading: vm.isLoading, error: vm.error, hasData: vm.hasData);

  SyncStatus _foodPermitStatus(FoodPermitViewModel vm) =>
      _vmStatus(isLoading: vm.isLoading, error: vm.error, hasData: vm.hasData);

  SyncStatus _foodChecklistStatus(FoodChecklistViewModel vm) =>
      _vmStatus(isLoading: vm.isLoading, error: vm.error, hasData: vm.hasData);

  SyncStatus _foodScheduleStatus(FoodInspectionScheduleViewModel vm) =>
      _vmStatus(isLoading: vm.isLoading, error: vm.error, hasData: vm.hasData);

  SyncStatus _tempFoodPermitStatus(TempFoodPermitViewModel vm) =>
      _vmStatus(isLoading: vm.isLoading, error: vm.error, hasData: vm.hasData);

  SyncStatus _tempFoodChecklistStatus(TempFoodChecklistViewModel vm) =>
      _vmStatus(isLoading: vm.isLoading, error: vm.error, hasData: vm.hasData);

  SyncStatus _tempFoodScheduleStatus(TempFoodInspectionScheduleViewModel vm) =>
      _vmStatus(isLoading: vm.isLoading, error: vm.error, hasData: vm.hasData);

  SyncStatus _tobaccoPermitStatus(TobaccoPermitViewModel vm) =>
      _vmStatus(isLoading: vm.isLoading, error: vm.error, hasData: vm.hasData);

  SyncStatus _tobaccoChecklistStatus(TobaccoChecklistViewModel vm) =>
      _vmStatus(isLoading: vm.isLoading, error: vm.error, hasData: vm.hasData);

  SyncStatus _tobaccoScheduleStatus(TobaccoInspectionScheduleViewModel vm) =>
      _vmStatus(isLoading: vm.isLoading, error: vm.error, hasData: vm.hasData);

  List<SyncTaskView> _syncTasks(
    MobileFoodPermitViewModel permitVM,
    MobileFoodChecklistViewModel checklistVM,
    InspectorViewModel inspectorVM,
    MobileFoodInspectionScheduleViewModel scheduleVM,
    FoodPermitViewModel foodPermitVM,
    FoodChecklistViewModel foodChecklistVM,
    FoodInspectionScheduleViewModel foodScheduleVM,
  ) {
    final foodStatus = _foodChecklistStatus(foodChecklistVM);
    final tempFoodPermitVM = _tempFoodPermitVM;
    final tempFoodChecklistVM = _tempFoodChecklistVM;
    final tempFoodScheduleVM = _tempFoodScheduleVM;
    final tempFoodStatus = _tempFoodChecklistStatus(tempFoodChecklistVM);
    final tobaccoPermitVM = _tobaccoPermitVM;
    final tobaccoChecklistVM = _tobaccoChecklistVM;
    final tobaccoScheduleVM = _tobaccoScheduleVM;
    final tobaccoStatus = _tobaccoChecklistStatus(tobaccoChecklistVM);
    return [
      SyncTaskView(
        label: 'Food Permits',
        icon: Icons.restaurant,
        status: _foodPermitStatus(foodPermitVM),
        count: foodPermitVM.totalCount,
        unit: 'permits',
      ),
      SyncTaskView(
        label: 'Food Sections',
        icon: Icons.view_agenda_outlined,
        status: foodStatus,
        count: foodChecklistVM.sectionCount,
        unit: 'sections',
      ),
      SyncTaskView(
        label: 'Food Section Parts',
        icon: Icons.segment,
        status: foodStatus,
        count: foodChecklistVM.partCount,
        unit: 'parts',
      ),
      SyncTaskView(
        label: 'Food Inspection Items',
        icon: Icons.checklist_rtl,
        status: foodStatus,
        count: foodChecklistVM.itemCount,
        unit: 'items',
      ),
      SyncTaskView(
        label: 'Food Schedules',
        icon: Icons.event_note,
        status: _foodScheduleStatus(foodScheduleVM),
        // While paging, show how many have been downloaded so far.
        count: foodScheduleVM.isLoading && foodScheduleVM.fetchedCount > 0
            ? foodScheduleVM.fetchedCount
            : foodScheduleVM.totalCount,
        unit: 'schedules',
      ),
      SyncTaskView(
        label: 'Temp Food Permits',
        icon: Icons.storefront_outlined,
        status: _tempFoodPermitStatus(tempFoodPermitVM),
        count: tempFoodPermitVM.totalCount,
        unit: 'permits',
      ),
      SyncTaskView(
        label: 'Temp Food Sections',
        icon: Icons.view_agenda_outlined,
        status: tempFoodStatus,
        count: tempFoodChecklistVM.sectionCount,
        unit: 'sections',
      ),
      SyncTaskView(
        label: 'Temp Food Section Parts',
        icon: Icons.segment,
        status: tempFoodStatus,
        count: tempFoodChecklistVM.partCount,
        unit: 'parts',
      ),
      SyncTaskView(
        label: 'Temp Food Inspection Items',
        icon: Icons.checklist_rtl,
        status: tempFoodStatus,
        count: tempFoodChecklistVM.itemCount,
        unit: 'items',
      ),
      SyncTaskView(
        label: 'Temp Food Schedules',
        icon: Icons.event_note,
        status: _tempFoodScheduleStatus(tempFoodScheduleVM),
        // While paging, show how many have been downloaded so far.
        count: tempFoodScheduleVM.isLoading &&
                tempFoodScheduleVM.fetchedCount > 0
            ? tempFoodScheduleVM.fetchedCount
            : tempFoodScheduleVM.totalCount,
        unit: 'schedules',
      ),
      SyncTaskView(
        label: 'Tobacco Permits',
        icon: Icons.smoke_free,
        status: _tobaccoPermitStatus(tobaccoPermitVM),
        count: tobaccoPermitVM.totalCount,
        unit: 'permits',
      ),
      SyncTaskView(
        label: 'Tobacco Sections',
        icon: Icons.view_agenda_outlined,
        status: tobaccoStatus,
        count: tobaccoChecklistVM.sectionCount,
        unit: 'sections',
      ),
      SyncTaskView(
        label: 'Tobacco Sub Sections',
        icon: Icons.segment,
        status: tobaccoStatus,
        count: tobaccoChecklistVM.subSectionCount,
        unit: 'sub sections',
      ),
      SyncTaskView(
        label: 'Tobacco Inspection Items',
        icon: Icons.checklist_rtl,
        status: tobaccoStatus,
        count: tobaccoChecklistVM.itemCount,
        unit: 'items',
      ),
      SyncTaskView(
        label: 'Tobacco Schedules',
        icon: Icons.event_note,
        status: _tobaccoScheduleStatus(tobaccoScheduleVM),
        // While paging, show how many have been downloaded so far.
        count: tobaccoScheduleVM.isLoading && tobaccoScheduleVM.fetchedCount > 0
            ? tobaccoScheduleVM.fetchedCount
            : tobaccoScheduleVM.totalCount,
        unit: 'schedules',
      ),
      SyncTaskView(
        label: 'Mobile Food Permits',
        icon: Icons.local_shipping_outlined,
        status: _permitStatus(permitVM),
        count: permitVM.permits.length,
        unit: 'permits',
      ),
      SyncTaskView(
        label: 'Sections',
        icon: Icons.view_agenda_outlined,
        status: checklistVM.statusOf(ChecklistTask.sections),
        count: checklistVM.countOf(ChecklistTask.sections),
        unit: 'sections',
      ),
      SyncTaskView(
        label: 'Section Parts',
        icon: Icons.segment,
        status: checklistVM.statusOf(ChecklistTask.sectionParts),
        count: checklistVM.countOf(ChecklistTask.sectionParts),
        unit: 'parts',
      ),
      SyncTaskView(
        label: 'Inspection Items',
        icon: Icons.checklist_rtl,
        status: checklistVM.statusOf(ChecklistTask.items),
        count: checklistVM.countOf(ChecklistTask.items),
        unit: 'items',
      ),
      SyncTaskView(
        label: 'Operation Types',
        icon: Icons.category_outlined,
        status: _opTypesStatus(),
        count: _opTypesVM.operationTypes.length,
        unit: 'types',
      ),
      SyncTaskView(
        label: 'Inspectors',
        icon: Icons.badge_outlined,
        status: _inspectorStatus(inspectorVM),
        count: inspectorVM.inspectors.length,
        unit: 'inspectors',
      ),
      SyncTaskView(
        label: 'Mobile Food Schedules',
        icon: Icons.event_note,
        status: _scheduleStatus(scheduleVM),
        count: scheduleVM.totalCount,
        unit: 'schedules',
      ),
    ];
  }

  // ---------------- Voice command handling ----------------

  /// Removes filler words so "please open food inspection",
  /// "can you open food inspection" etc. all become "open food inspection".
  String _cleanCommand(String text) {
    var t = text.toLowerCase().trim();
    t = t.replaceAll(
        RegExp(r'\b(show me|go to|take me to|open up|navigate to)\b'), 'open');
    const fillers = [
      'please',
      'can you',
      'could you',
      'would you',
      'kindly',
      'hey quincy',
      'for me',
      'the',
    ];
    for (final f in fillers) {
      t = t.replaceAll(RegExp('\\b$f\\b'), ' ');
    }
    // "temporary food" / "tempfood" / "temp. food" → "temp food"
    t = t
        .replaceAll(RegExp(r'\btemporary\b'), 'temp')
        .replaceAll(RegExp(r'\btemp\.?\s*food\b'), 'temp food');
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// "food" said, but not "mobile food" / "temp food" → the plain Food section.
  bool _mentionsPlainFood(String cleaned) =>
      RegExp(r'\bfood\b').hasMatch(cleaned) &&
      !cleaned.contains('mobile food') &&
      !_mentionsTempFood(cleaned);

  /// "tobacco" said.
  bool _mentionsTobacco(String cleaned) =>
      RegExp(r'\btobacco\b').hasMatch(cleaned);

  /// "temp food" / "temporary food" said (after [_cleanCommand]).
  bool _mentionsTempFood(String cleaned) => cleaned.contains('temp food');

  /// "question 4 OUT with R" said on the Dashboard: answers can only be
  /// given inside an open inspection, so explain how to get there.
  bool _isQuestionAnswer(String text) {
    if (!ItemAnswerVoiceParser.mentionsItem(text)) return false;
    final parsed = ItemAnswerVoiceParser.parse(text);
    return parsed != null &&
        (parsed.answers.isNotEmpty || parsed.comments.isNotEmpty);
  }

  Future<VoiceReply> _handleVoiceCommand(String text) async {
    final vm = context.read<DashboardViewModel>();
    final permitVM = context.read<MobileFoodPermitViewModel>();
    if (permitVM.permits.isEmpty) await permitVM.loadLocalPermits();
    if (_foodPermits.isEmpty) await _reloadFoodPermits();
    if (_tempFoodPermits.isEmpty) await _reloadTempFoodPermits();
    if (_tobaccoPermits.isEmpty) await _reloadTobaccoPermits();
    if (!mounted) return const VoiceReply('');

    // 0) "Submit my inspection" conversation (runs before everything else,
    //    and keeps the follow-up answers: Mobile Food → business → date/time)
    final submit = await _submitFlow.handle(text);
    if (!mounted) return const VoiceReply('');
    if (submit != null) {
      _awaitingScheduleChoice = false;
      final id = submit.inspectionId;
      if (id != null) {
        return VoiceReply(
          submit.text,
          keepListening: false,
          afterSpeak: () async => _autoSubmitInspection(id),
        );
      }
      return VoiceReply(submit.text, keepListening: submit.keepListening);
    }

    final cleaned = _cleanCommand(text);

    // 0.2) Schedules: "food schedules", "mobile food schedule",
    //      or just "schedules" → "Food or Mobile Food?"
    final scheduleReply = _scheduleCommand(cleaned);
    if (scheduleReply != null) return scheduleReply;

    // 0.5) Question answers belong to the inspection screen
    if (_isQuestionAnswer(text)) {
      return const VoiceReply(
        'To answer questions, open an inspection first. Say open incomplete, '
        'or say a business name to start a new one. Then tap AI Guide on the '
        'inspection screen and say, for example, question 4 OUT with R.',
      );
    }

    // 0.8) Food business name ("open food Pizza Palace", or a full Food
    //      business name that is not also a Mobile Food business)
    final plainFood = _mentionsPlainFood(cleaned);
    final foodFull = _findFoodBusinesses(cleaned, allowPartial: false);
    final mobileFull =
        _findBusinesses(cleaned, permitVM.permits, allowPartial: false);

    // 0.6) Tobacco: "tobacco new", "tobacco incomplete",
    //      "tobacco Franklin St BP", or a full Tobacco business name that
    //      is not also a Food / Temp Food / Mobile Food business.
    final tobacco = _mentionsTobacco(cleaned);
    final tobaccoFull = _findTobaccoBusinesses(cleaned, allowPartial: false);
    if (tobacco ||
        (tobaccoFull.isNotEmpty &&
            foodFull.isEmpty &&
            mobileFull.isEmpty &&
            _findTempFoodBusinesses(cleaned, allowPartial: false).isEmpty)) {
      final tobaccoReply = _tobaccoCommand(cleaned, allowPartial: tobacco);
      if (tobaccoReply != null) return tobaccoReply;
    }

    // 0.7) Temporary Food: "temp food new", "temp food incomplete",
    //      "temp food Sunny Tacos", or a full Temp Food business name that
    //      is not also a Food / Mobile Food business.
    final tempFood = _mentionsTempFood(cleaned);
    final tempFull = _findTempFoodBusinesses(cleaned, allowPartial: false);
    if (tempFood ||
        (tempFull.isNotEmpty && foodFull.isEmpty && mobileFull.isEmpty)) {
      final tempReply = _tempFoodCommand(cleaned, allowPartial: tempFood);
      if (tempReply != null) return tempReply;
    }

    if (plainFood || (foodFull.isNotEmpty && mobileFull.isEmpty)) {
      final foodReply =
          _tryFoodBusinessCommand(cleaned, allowPartial: plainFood);
      if (foodReply != null) return foodReply;
    }

    // 1) Conversation: follow-up questions, business names (even
    //    misspelled / mispronounced), counts, PDF …
    final brainReply = await _brain.handle(text);
    if (!mounted) return const VoiceReply('');
    if (brainReply != null) {
      return VoiceReply(
        brainReply.text,
        keepListening: brainReply.keepListening,
        afterSpeak: brainReply.afterSpeak,
      );
    }

    // 1.5) Places → Google Maps ("where is Central Park",
    //      "directions to the airport", "nearest gas station")
    final mapIntent = GeneralAssistant.detectMapIntent(text);
    if (mapIntent != null &&
        !_isAppTarget(mapIntent.place, permitVM.permits, vm.menu)) {
      return _openMapReply(mapIntent);
    }

    // 1.6) General questions ("what's the latest news") go to the AI before
    //      the menu parser, so a word like "food" doesn't open a menu.
    if (_general.isConfigured &&
        GeneralAssistant.looksLikeGeneralQuestion(text) &&
        !_isAppTarget(text, permitVM.permits, vm.menu, checkMenu: false)) {
      return _askGeneral(text);
    }

    final cmd = VoiceCommandParser.parse(
      cleaned,
      vm.menu,
      currentInspection: vm.expandedInspection,
      currentCategory: vm.expandedCategory,
    );

    // 2) Mobile Food business name spoken?
    //    ("Rolling Bites", "open mobile food new Rolling Bites")
    final mentionsMobileFood = cleaned.contains('mobile food');
    final businessReply = _tryBusinessCommand(
      cleaned,
      permitVM.permits,
      allowPartial: cmd.action == VoiceAction.unknown || mentionsMobileFood,
    );
    if (businessReply != null) return businessReply;

    // 2.5) Partial Food / Temp Food business name ("pizza") when nothing
    //      else matched
    if (cmd.action == VoiceAction.unknown && !mentionsMobileFood) {
      final foodReply = _tryFoodBusinessCommand(cleaned, allowPartial: true);
      if (foodReply != null) return foodReply;
      final tempReply =
          _tryTempFoodBusinessCommand(cleaned, allowPartial: true);
      if (tempReply != null) return tempReply;
      final tobaccoReply =
          _tryTobaccoBusinessCommand(cleaned, allowPartial: true);
      if (tobaccoReply != null) return tobaccoReply;
    }

    // 3) "mobile food incomplete" / "mobile food new" the menu parser missed
    if (cmd.action == VoiceAction.unknown &&
        mentionsMobileFood &&
        cleaned.contains('incomplete')) {
      return VoiceReply(
        'Opening your incomplete Mobile Food inspections.',
        keepListening: false,
        afterSpeak: () async => _openIncompleteList(),
      );
    }
    if (cmd.action == VoiceAction.unknown &&
        mentionsMobileFood &&
        RegExp(r'\bnew\b').hasMatch(cleaned)) {
      return VoiceReply(
        'Opening Mobile Food permits. Pick a business to start the inspection.',
        keepListening: false,
        afterSpeak: () async => _openPermitList(),
      );
    }

    // 3.2) "food incomplete" / "open incomplete food inspections"
    if (cmd.action == VoiceAction.unknown &&
        plainFood &&
        cleaned.contains('incomplete')) {
      return VoiceReply(
        'Opening your incomplete Food inspections.',
        keepListening: false,
        afterSpeak: () async => _openFoodIncompleteList(),
      );
    }

    // 3.3) "food new" / "open food permits" / "new food inspection"
    if (cmd.action == VoiceAction.unknown &&
        plainFood &&
        RegExp(r'\b(new|permits?)\b').hasMatch(cleaned)) {
      return VoiceReply(
        'Opening Food permits. Pick a business, '
        'or tell me the business name.',
        keepListening: false,
        afterSpeak: () async => _openFoodPermitList(),
      );
    }

    // 4) Normal menu commands
    switch (cmd.action) {
      case VoiceAction.help:
        return const VoiceReply(
          'You can say: open incomplete, open new, food new, food incomplete, '
          'food schedules, temp food new, temp food incomplete, '
          'temp food schedules, tobacco new, tobacco incomplete, '
          'tobacco schedules, mobile food schedules, or a business name, '
          'for example food Pizza Palace. '
          'Say submit my inspection to send an incomplete inspection to the '
          'server. Ask how many IN, OUT, not observed, not applicable, '
          'corrected on site or repeat items an inspection has. Say open the '
          'PDF, or list incomplete inspections. Inside an inspection you can '
          'say question 1 IN, or question 4 OUT with R. You can also ask me '
          'anything, like the latest news or the weather, or say where is, '
          'or directions to, a place to open it in Maps. Say close to '
          'collapse the list, or logout to sign out.',
        );

      case VoiceAction.collapse:
        _collapseAllTiles();
        vm.collapseAll();
        return const VoiceReply('Okay, I closed the list.');

      case VoiceAction.logout:
        return VoiceReply(
          'Logging you out. Goodbye!',
          keepListening: false,
          afterSpeak: _performLogout,
        );

      case VoiceAction.stop:
        return VoiceReply(
          'Okay. Tap the AI Guide button whenever you need me.',
          keepListening: false,
          afterSpeak: _voiceVM.closePanel,
        );

      case VoiceAction.needCategory:
        final inspection = cmd.inspection!;
        await _autoOpen(inspection);
        return VoiceReply(
          'Which one? ${_joinOptions(inspection.categories.map((c) => c.title))}',
        );

      case VoiceAction.open:
        final inspection = cmd.inspection!;
        await _autoOpen(inspection, category: cmd.category);

        if (cmd.sub != null) {
          // Schedule → Food or Mobile Food schedules, by menu section
          if (_isSchedule(cmd.sub!)) {
            return _scheduleReply(_scheduleKindFor(inspection, cmd.category));
          }

          // Tobacco → Incomplete opens the saved Tobacco inspections
          if (_isTobaccoIncomplete(inspection, cmd.category, cmd.sub!)) {
            return VoiceReply(
              'Opening your incomplete Tobacco inspections.',
              keepListening: false,
              afterSpeak: () async => _openTobaccoIncompleteList(),
            );
          }

          // Tobacco → New opens the tobacco permit list
          if (_isTobaccoPermits(inspection, cmd.category, cmd.sub!)) {
            return VoiceReply(
              'Opening Tobacco permits. Pick a business, '
              'or tell me the business name.',
              keepListening: false,
              afterSpeak: () async => _openTobaccoPermitList(),
            );
          }

          // Temp Food → Incomplete opens the saved Temp Food inspections
          if (_isTempFoodIncomplete(inspection, cmd.category, cmd.sub!)) {
            return VoiceReply(
              'Opening your incomplete Temporary Food inspections.',
              keepListening: false,
              afterSpeak: () async => _openTempFoodIncompleteList(),
            );
          }

          // Temp Food → New opens the temp food permit list
          if (_isTempFoodPermits(inspection, cmd.category, cmd.sub!)) {
            return VoiceReply(
              'Opening Temporary Food permits. Pick a business, '
              'or tell me the business name.',
              keepListening: false,
              afterSpeak: () async => _openTempFoodPermitList(),
            );
          }

          // Mobile Food → New goes straight to the permit list
          if (_isMobileFoodNew(inspection, cmd.category, cmd.sub!)) {
            return VoiceReply(
              'Opening Mobile Food permits. Pick a business, '
              'or tell me the business name.',
              keepListening: false,
              afterSpeak: () async => _openPermitList(),
            );
          }

          // Mobile Food → Incomplete opens the saved inspections
          if (_isMobileFoodIncomplete(inspection, cmd.category, cmd.sub!)) {
            return VoiceReply(
              'Opening your incomplete Mobile Food inspections.',
              keepListening: false,
              afterSpeak: () async => _openIncompleteList(),
            );
          }

          // Food → Incomplete opens the saved Food inspections
          if (_isFoodIncomplete(inspection, cmd.category, cmd.sub!)) {
            return VoiceReply(
              'Opening your incomplete Food inspections.',
              keepListening: false,
              afterSpeak: () async => _openFoodIncompleteList(),
            );
          }

          // Food → New opens the food permit list
          if (_isFoodPermits(inspection, cmd.category, cmd.sub!)) {
            return VoiceReply(
              'Opening Food permits. Pick a business, '
              'or tell me the business name.',
              keepListening: false,
              afterSpeak: () async => _openFoodPermitList(),
            );
          }

          final path = [
            inspection.title,
            if (cmd.category != null) cmd.category!.title,
            cmd.sub!.title,
          ].join(', ');
          return VoiceReply(
            'Opening $path.',
            keepListening: false,
            afterSpeak: () async =>
                _onSubCategoryTap(inspection, cmd.category, cmd.sub!),
          );
        }

        if (cmd.category != null) {
          return VoiceReply(
            '${cmd.category!.title} is open. Say '
            '${_joinOptions(cmd.category!.subCategories.map((s) => s.title))}.',
          );
        }

        if (inspection.hasCategories) {
          return VoiceReply(
            '${inspection.title} is open. Which one: '
            '${_joinOptions(inspection.categories.map((c) => c.title))}?',
          );
        }

        return VoiceReply(
          '${inspection.title} is open. Say '
          '${_joinOptions(inspection.subCategories.map((s) => s.title))}.',
        );

      case VoiceAction.unknown:
        // Not an app command → answer it like a normal assistant
        if (_general.isConfigured) return _askGeneral(text);
        return const VoiceReply(
          "Sorry, I didn't get that. You can say food new, food incomplete, "
          'food schedules, temp food new, temp food incomplete, '
          'tobacco new, tobacco incomplete, '
          'open incomplete, say a business name, '
          'say submit my inspection, '
          'or ask how many items are out of compliance.',
        );
    }
  }

  // ---------------- Schedules (voice) ----------------

  static final RegExp _scheduleWord = RegExp(r'\bschedul\w*');

  /// Handles "food schedules", "mobile food schedule", "open my schedules"
  /// "temp food schedules" and the answer to "Food, Temporary Food or
  /// Mobile Food?".
  VoiceReply? _scheduleCommand(String cleaned) {
    final saysSchedule = _scheduleWord.hasMatch(cleaned);

    if (_awaitingScheduleChoice) {
      _awaitingScheduleChoice = false;
      if (_mentionsTobacco(cleaned)) {
        return _scheduleReply(_ScheduleKind.tobacco);
      }
      if (_mentionsTempFood(cleaned) || RegExp(r'\btemp\b').hasMatch(cleaned)) {
        return _scheduleReply(_ScheduleKind.tempFood);
      }
      if (cleaned.contains('mobile')) {
        return _scheduleReply(_ScheduleKind.mobileFood);
      }
      if (RegExp(r'\bfood\b').hasMatch(cleaned)) {
        return _scheduleReply(_ScheduleKind.food);
      }
      // Not an answer → treat it as a normal command below.
    }

    if (!saysSchedule) return null;

    if (_mentionsTobacco(cleaned)) {
      return _scheduleReply(_ScheduleKind.tobacco);
    }

    if (_mentionsTempFood(cleaned) || RegExp(r'\btemp\b').hasMatch(cleaned)) {
      return _scheduleReply(_ScheduleKind.tempFood);
    }
    if (cleaned.contains('mobile')) {
      return _scheduleReply(_ScheduleKind.mobileFood);
    }
    if (RegExp(r'\bfood\b').hasMatch(cleaned)) {
      return _scheduleReply(_ScheduleKind.food);
    }

    _awaitingScheduleChoice = true;
    return const VoiceReply(
        'Which schedules would you like, Food, Temporary Food, '
        'Mobile Food or Tobacco?');
  }

  VoiceReply _scheduleReply(_ScheduleKind kind) {
    _awaitingScheduleChoice = false;
    if (kind == _ScheduleKind.food) {
      final n = _foodScheduleVM.totalCount;
      return VoiceReply(
        n == 0
            ? 'Opening your Food inspection schedules.'
            : 'Opening your Food inspection schedules. You have $n.',
        keepListening: false,
        afterSpeak: () async => _openFoodScheduleList(),
      );
    }
    if (kind == _ScheduleKind.tobacco) {
      final n = _tobaccoScheduleVM.totalCount;
      return VoiceReply(
        n == 0
            ? 'Opening your Tobacco inspection schedules.'
            : 'Opening your Tobacco inspection schedules. You have $n.',
        keepListening: false,
        afterSpeak: () async => _openTobaccoScheduleList(),
      );
    }
    if (kind == _ScheduleKind.tempFood) {
      final n = _tempFoodScheduleVM.totalCount;
      return VoiceReply(
        n == 0
            ? 'Opening your Temporary Food inspection schedules.'
            : 'Opening your Temporary Food inspection schedules. You have $n.',
        keepListening: false,
        afterSpeak: () async => _openTempFoodScheduleList(),
      );
    }
    return VoiceReply(
      'Opening your Mobile Food inspection schedules.',
      keepListening: false,
      afterSpeak: () async => _openScheduleList(),
    );
  }

  // ---------------- Outside the app: questions & maps ----------------

  static final RegExp _appWords = RegExp(
    r'\b(?:inspections?|permits?|incomplete|pdf|submit|log ?out|dashboard|'
    r'checklist|questions? \d|items? \d|operation types?|inspectors?|'
    r'schedules?|'
    r'mobile food|temp(?:orary)? food|tobacco|my (?:business|report|form)|out of compliance|'
    r'not observed|not applicable|corrected on site|repeat items?|'
    r'how many items)\b',
    caseSensitive: false,
  );

  /// True when the words are about something inside the app (a menu, a
  /// business, an inspection), so they must not go to Maps or the AI.
  /// [checkMenu] is off for questions, so "latest food safety news" isn't
  /// mistaken for the Food menu.
  bool _isAppTarget(
    String words,
    List<MobileFoodPermitModel> permits,
    List<InspectionMenu> menu, {
    bool checkMenu = true,
  }) {
    if (_appWords.hasMatch(words)) return true;
    final w = _normalize(words);
    if (w.isEmpty) return false;
    for (final m in checkMenu ? menu : const <InspectionMenu>[]) {
      final title = _normalize(m.title);
      if (title.isNotEmpty && (w == title || w.contains(' $title ') ||
          w.startsWith('$title ') || w.endsWith(' $title'))) {
        return true;
      }
    }
    return _findBusinesses(words, permits, allowPartial: false).isNotEmpty ||
        _findFoodBusinesses(words, allowPartial: false).isNotEmpty ||
        _findTempFoodBusinesses(words, allowPartial: false).isNotEmpty ||
        _findTobaccoBusinesses(words, allowPartial: false).isNotEmpty;
  }

  VoiceReply _openMapReply(MapIntent m) {
    final say = m.place.isEmpty
        ? 'Opening Maps.'
        : m.directions
            ? 'Getting directions to ${m.place}.'
            : 'Opening ${m.place} in Maps.';
    return VoiceReply(
      say,
      keepListening: false,
      afterSpeak: () async {
        await _stopDashboardVoice();
        final ok = await GeneralAssistant.openMap(m);
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open Maps.')),
          );
        }
      },
    );
  }

  Future<VoiceReply> _askGeneral(String text) async {
    final reply = await _general.ask(text);
    if (!mounted) return const VoiceReply('');
    final map = reply.map;
    if (map != null) {
      return VoiceReply(
        reply.text,
        keepListening: false,
        afterSpeak: () async {
          await _stopDashboardVoice();
          await GeneralAssistant.openMap(map);
        },
      );
    }
    return VoiceReply(reply.text);
  }

  String _joinOptions(Iterable<String> items) {
    final list = items.toList();
    if (list.length <= 1) return list.join();
    return '${list.sublist(0, list.length - 1).join(', ')} or ${list.last}';
  }

  // ---------------- Business name matching ----------------

  String _normalize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\bthe\b'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Returns the items whose name was spoken (Mobile Food or Food permits).
  /// - Full name inside the command always matches.
  /// - Partial name ("rolling bites") matches only when [allowPartial] is true,
  ///   so normal menu commands like "open food inspection" aren't hijacked.
  List<T> _matchByName<T>(
    String command,
    List<T> items,
    String Function(T) nameOf, {
    required bool allowPartial,
  }) {
    final cmd = _normalize(command);
    if (cmd.isEmpty || items.isEmpty) return const [];

    // 1. Full business name contained in the command
    final full = items.where((p) {
      final name = _normalize(nameOf(p));
      return name.length >= 3 &&
          RegExp('\\b${RegExp.escape(name)}\\b').hasMatch(cmd);
    }).toList();
    if (full.isNotEmpty) {
      final longest = full
          .map((p) => _normalize(nameOf(p)).length)
          .reduce((a, b) => a > b ? a : b);
      return full.where((p) => _normalize(nameOf(p)).length == longest).toList();
    }

    if (!allowPartial) return const [];

    // 2. Remaining spoken words all appear in the business name
    final tokens = cmd
        .split(' ')
        .where((w) => w.isNotEmpty && !_businessStopWords.contains(w))
        .toList();
    if (tokens.isEmpty || tokens.join().length < 3) return const [];

    return items.where((p) {
      final words = _normalize(nameOf(p)).split(' ');
      return tokens.every((t) => words.any((w) => w.startsWith(t)));
    }).toList();
  }

  List<MobileFoodPermitModel> _findBusinesses(
    String command,
    List<MobileFoodPermitModel> permits, {
    required bool allowPartial,
  }) =>
      _matchByName(command, permits, (p) => p.businessName,
          allowPartial: allowPartial);

  String _foodName(FoodPermitModel p) => p.businessName ?? '';

  String _foodPermitNo(FoodPermitModel p) => (p.permitNumber ?? '').toString();

  List<FoodPermitModel> _findFoodBusinesses(
    String command, {
    required bool allowPartial,
  }) =>
      _matchByName(command, _foodPermits, _foodName,
          allowPartial: allowPartial);

  String _tempFoodName(TempFoodPermitModel p) => p.businessName ?? '';

  String _tempFoodPermitNo(TempFoodPermitModel p) =>
      (p.permitNumber ?? '').toString();

  List<TempFoodPermitModel> _findTempFoodBusinesses(
    String command, {
    required bool allowPartial,
  }) =>
      _matchByName(command, _tempFoodPermits, _tempFoodName,
          allowPartial: allowPartial);

  String _tobaccoName(TobaccoPermitModel p) => p.businessName ?? '';

  List<TobaccoPermitModel> _findTobaccoBusinesses(
    String command, {
    required bool allowPartial,
  }) =>
      _matchByName(command, _tobaccoPermits, _tobaccoName,
          allowPartial: allowPartial);

  /// Tobacco version: opens the Tobacco permit list on the spoken business.
  VoiceReply? _tryTobaccoBusinessCommand(
    String cleaned, {
    required bool allowPartial,
  }) {
    if (_tobaccoPermits.isEmpty) return null;

    final matches = _findTobaccoBusinesses(cleaned, allowPartial: allowPartial);
    if (matches.isEmpty) return null;

    if (matches.length == 1) {
      final p = matches.first;
      final name = _tobaccoName(p);
      final no = p.permitNumber ?? '';
      return VoiceReply(
        'Opening Tobacco business $name'
        '${no.isEmpty ? '' : ', permit $no'}. '
        'Tap Start New Inspection to begin.',
        keepListening: false,
        afterSpeak: () async =>
            _openTobaccoPermitList(query: name, permitId: p.id),
      );
    }

    final spoken = _spokenName(cleaned);
    return VoiceReply(
      'I found ${matches.length} Tobacco businesses matching $spoken. '
      'Showing them now.',
      keepListening: false,
      afterSpeak: () async => _openTobaccoPermitList(query: spoken),
    );
  }

  /// "tobacco incomplete" / "tobacco <business>" / "tobacco new".
  /// Returns null for just "tobacco" so the menu parser can open the menu.
  VoiceReply? _tobaccoCommand(String cleaned, {required bool allowPartial}) {
    if (cleaned.contains('incomplete')) {
      return VoiceReply(
        'Opening your incomplete Tobacco inspections.',
        keepListening: false,
        afterSpeak: () async => _openTobaccoIncompleteList(),
      );
    }
    final business =
        _tryTobaccoBusinessCommand(cleaned, allowPartial: allowPartial);
    if (business != null) return business;
    if (RegExp(r'\b(new|permits?|inspection)\b').hasMatch(cleaned)) {
      return VoiceReply(
        'Opening Tobacco permits. Pick a business, '
        'or tell me the business name.',
        keepListening: false,
        afterSpeak: () async => _openTobaccoPermitList(),
      );
    }
    return null;
  }

  /// Spoken words without command / stop words ("open food pizza" → "pizza").
  String _spokenName(String cleaned) => cleaned
      .split(' ')
      .where((w) => !_businessStopWords.contains(w))
      .join(' ');

  VoiceReply? _tryBusinessCommand(
    String cleaned,
    List<MobileFoodPermitModel> permits, {
    required bool allowPartial,
  }) {
    if (permits.isEmpty) return null;

    final matches = _findBusinesses(cleaned, permits, allowPartial: allowPartial);
    if (matches.isEmpty) return null;

    if (matches.length == 1) {
      final p = matches.first;
      return VoiceReply(
        'Opening ${p.businessName}, permit ${p.permitNumber}.',
        keepListening: false,
        afterSpeak: () async =>
            _openPermitList(query: p.businessName, permitId: p.id),
      );
    }

    final spoken = _spokenName(cleaned);
    return VoiceReply(
      'I found ${matches.length} businesses matching $spoken. '
      'Showing them now.',
      keepListening: false,
      afterSpeak: () async => _openPermitList(query: spoken),
    );
  }

  /// Food version: opens the Food permit list on the spoken business.
  /// "Start New Inspection" there opens the Food inspection form
  /// (with voice answers in AI mode).
  VoiceReply? _tryFoodBusinessCommand(
    String cleaned, {
    required bool allowPartial,
  }) {
    if (_foodPermits.isEmpty) return null;

    final matches = _findFoodBusinesses(cleaned, allowPartial: allowPartial);
    if (matches.isEmpty) return null;

    if (matches.length == 1) {
      final p = matches.first;
      final name = _foodName(p);
      final no = _foodPermitNo(p);
      return VoiceReply(
        'Opening Food business $name'
        '${no.isEmpty ? '' : ', permit $no'}. '
        'Tap Start New Inspection to begin.',
        keepListening: false,
        afterSpeak: () async =>
            _openFoodPermitList(query: name, permitId: p.id),
      );
    }

    final spoken = _spokenName(cleaned);
    return VoiceReply(
      'I found ${matches.length} Food businesses matching $spoken. '
      'Showing them now.',
      keepListening: false,
      afterSpeak: () async => _openFoodPermitList(query: spoken),
    );
  }

  /// Temp Food version: opens the Temp Food permit list on the spoken
  /// business. "Start New Inspection" there opens the Temp Food form.
  VoiceReply? _tryTempFoodBusinessCommand(
    String cleaned, {
    required bool allowPartial,
  }) {
    if (_tempFoodPermits.isEmpty) return null;

    final matches =
        _findTempFoodBusinesses(cleaned, allowPartial: allowPartial);
    if (matches.isEmpty) return null;

    if (matches.length == 1) {
      final p = matches.first;
      final name = _tempFoodName(p);
      final no = _tempFoodPermitNo(p);
      return VoiceReply(
        'Opening Temporary Food business $name'
        '${no.isEmpty ? '' : ', permit $no'}. '
        'Tap Start New Inspection to begin.',
        keepListening: false,
        afterSpeak: () async =>
            _openTempFoodPermitList(query: name, permitId: p.id),
      );
    }

    final spoken = _spokenName(cleaned);
    return VoiceReply(
      'I found ${matches.length} Temporary Food businesses matching $spoken. '
      'Showing them now.',
      keepListening: false,
      afterSpeak: () async => _openTempFoodPermitList(query: spoken),
    );
  }

  /// "temp food incomplete" / "temp food <business>" / "temp food new".
  /// Returns null for just "temp food" so the menu parser can open the menu.
  VoiceReply? _tempFoodCommand(String cleaned, {required bool allowPartial}) {
    if (cleaned.contains('incomplete')) {
      return VoiceReply(
        'Opening your incomplete Temporary Food inspections.',
        keepListening: false,
        afterSpeak: () async => _openTempFoodIncompleteList(),
      );
    }
    final business =
        _tryTempFoodBusinessCommand(cleaned, allowPartial: allowPartial);
    if (business != null) return business;
    if (RegExp(r'\b(new|permits?)\b').hasMatch(cleaned)) {
      return VoiceReply(
        'Opening Temporary Food permits. Pick a business, '
        'or tell me the business name.',
        keepListening: false,
        afterSpeak: () async => _openTempFoodPermitList(),
      );
    }
    return null;
  }

  // ---------------- Programmatic expand ("auto click") ----------------

  /// Opens an inspection (and optionally a category) exactly like a user tap.
  Future<void> _autoOpen(
    InspectionMenu inspection, {
    MenuCategory? category,
  }) async {
    // Close any other open inspection (accordion behaviour)
    for (final e in _inspCtrls.entries) {
      if (e.key != inspection.id) _safeCollapse(e.value);
    }

    await _scrollTo(inspection.id);
    if (!mounted) return;

    _safeExpand(_inspCtrls[inspection.id]);

    if (category != null) {
      // Close sibling categories, then open the requested one
      for (final c in inspection.categories) {
        if (c.id != category.id) {
          _safeCollapse(_catCtrls['${inspection.id}_${c.id}']);
        }
      }
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      _safeExpand(_catCtrls['${inspection.id}_${category.id}']);
    }
  }

  void _collapseAllTiles() {
    for (final c in _catCtrls.values) {
      _safeCollapse(c);
    }
    for (final c in _inspCtrls.values) {
      _safeCollapse(c);
    }
  }

  void _safeExpand(ExpansionTileController? c) {
    try {
      if (c != null && !c.isExpanded) c.expand();
    } catch (_) {
      // Tile not built yet – ignore
    }
  }

  void _safeCollapse(ExpansionTileController? c) {
    try {
      if (c != null && c.isExpanded) c.collapse();
    } catch (_) {
      // Tile not built yet – ignore
    }
  }

  Future<void> _scrollTo(int inspectionId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final ctx = _tileKeys[inspectionId]?.currentContext;
    if (ctx != null && mounted) {
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.05,
      );
    }
  }

  // ---------------- Navigation ----------------

  bool _isMobileFood(String icon, String title) =>
      icon == 'mobile_food' || title.toLowerCase().contains('mobile food');

  bool _isMobileFoodNew(
    InspectionMenu inspection,
    MenuCategory? category,
    MenuSubCategory sub,
  ) {
    final isMobile = _isMobileFood(inspection.icon, inspection.title) ||
        (category != null && _isMobileFood(category.icon, category.title));
    final isNew = sub.icon == 'new' ||
        RegExp(r'\bnew\b').hasMatch(sub.title.toLowerCase());
    return isMobile && isNew;
  }

  bool _isMobileFoodIncomplete(
    InspectionMenu inspection,
    MenuCategory? category,
    MenuSubCategory sub,
  ) {
    final isMobile = _isMobileFood(inspection.icon, inspection.title) ||
        (category != null && _isMobileFood(category.icon, category.title));
    final isIncomplete = sub.icon == 'incomplete' ||
        sub.title.toLowerCase().contains('incomplete');
    return isMobile && isIncomplete;
  }

  bool _isSchedule(MenuSubCategory sub) =>
      sub.icon == 'schedule' || sub.title.toLowerCase().contains('schedule');

  /// The plain "Food" menu (not Mobile Food / Temporary Food).
  bool _isFoodMenu(String icon, String title) {
    if (icon == 'food') return true;
    final t = title.toLowerCase();
    return t.contains('food') && !t.contains('mobile') && !t.contains('temp');
  }

  /// True when the tapped / spoken item is inside the plain Food section.
  /// Category wins: Food inspection → Mobile Food category is not "Food".
  bool _isFoodSection(InspectionMenu inspection, MenuCategory? category) =>
      category != null
          ? _isFoodMenu(category.icon, category.title)
          : _isFoodMenu(inspection.icon, inspection.title);

  /// The "Temporary Food" menu.
  bool _isTempFoodMenu(String icon, String title) {
    if (icon == 'temp_food') return true;
    final t = title.toLowerCase();
    return t.contains('temp') && t.contains('food');
  }

  /// True when the tapped / spoken item is inside the Temporary Food section.
  bool _isTempFoodSection(InspectionMenu inspection, MenuCategory? category) =>
      category != null
          ? _isTempFoodMenu(category.icon, category.title)
          : _isTempFoodMenu(inspection.icon, inspection.title);

  /// Temp Food → Incomplete opens the saved Temp Food inspections.
  bool _isTempFoodIncomplete(
    InspectionMenu inspection,
    MenuCategory? category,
    MenuSubCategory sub,
  ) {
    final isIncomplete = sub.icon == 'incomplete' ||
        sub.title.toLowerCase().contains('incomplete');
    return _isTempFoodSection(inspection, category) && isIncomplete;
  }

  /// Temp Food → New (or a "Permits" item) opens the temp food permit list.
  bool _isTempFoodPermits(
    InspectionMenu inspection,
    MenuCategory? category,
    MenuSubCategory sub,
  ) {
    final t = sub.title.toLowerCase();
    final isNewOrPermit = sub.icon == 'new' ||
        RegExp(r'\bnew\b').hasMatch(t) ||
        t.contains('permit');
    return _isTempFoodSection(inspection, category) && isNewOrPermit;
  }

  /// The "Tobacco" menu.
  bool _isTobaccoMenu(String icon, String title) =>
      icon == 'tobacco' || title.toLowerCase().contains('tobacco');

  /// True when the tapped / spoken item is inside the Tobacco section.
  bool _isTobaccoSection(InspectionMenu inspection, MenuCategory? category) =>
      category != null
          ? _isTobaccoMenu(category.icon, category.title)
          : _isTobaccoMenu(inspection.icon, inspection.title);

  /// Tobacco → Incomplete opens the saved Tobacco inspections.
  bool _isTobaccoIncomplete(
    InspectionMenu inspection,
    MenuCategory? category,
    MenuSubCategory sub,
  ) {
    final isIncomplete = sub.icon == 'incomplete' ||
        sub.title.toLowerCase().contains('incomplete');
    return _isTobaccoSection(inspection, category) && isIncomplete;
  }

  /// Tobacco → New (or a "Permits" item) opens the tobacco permit list.
  bool _isTobaccoPermits(
    InspectionMenu inspection,
    MenuCategory? category,
    MenuSubCategory sub,
  ) {
    final t = sub.title.toLowerCase();
    final isNewOrPermit = sub.icon == 'new' ||
        RegExp(r'\bnew\b').hasMatch(t) ||
        t.contains('permit');
    return _isTobaccoSection(inspection, category) && isNewOrPermit;
  }

  /// Which schedule list a "Schedule" menu item belongs to.
  _ScheduleKind _scheduleKindFor(
    InspectionMenu inspection,
    MenuCategory? category,
  ) {
    if (_isTobaccoSection(inspection, category)) return _ScheduleKind.tobacco;
    if (_isTempFoodSection(inspection, category)) return _ScheduleKind.tempFood;
    if (_isFoodSection(inspection, category)) return _ScheduleKind.food;
    return _ScheduleKind.mobileFood;
  }

  void _openSchedulesOf(_ScheduleKind kind) {
    switch (kind) {
      case _ScheduleKind.food:
        _openFoodScheduleList();
      case _ScheduleKind.tempFood:
        _openTempFoodScheduleList();
      case _ScheduleKind.mobileFood:
        _openScheduleList();
      case _ScheduleKind.tobacco:
        _openTobaccoScheduleList();
    }
  }

  /// Food → Incomplete opens the saved (not submitted) Food inspections.
  bool _isFoodIncomplete(
    InspectionMenu inspection,
    MenuCategory? category,
    MenuSubCategory sub,
  ) {
    final isIncomplete = sub.icon == 'incomplete' ||
        sub.title.toLowerCase().contains('incomplete');
    return _isFoodSection(inspection, category) && isIncomplete;
  }

  /// Food → New (or a "Permits" item) opens the food permit list.
  bool _isFoodPermits(
    InspectionMenu inspection,
    MenuCategory? category,
    MenuSubCategory sub,
  ) {
    final t = sub.title.toLowerCase();
    final isNewOrPermit = sub.icon == 'new' ||
        RegExp(r'\bnew\b').hasMatch(t) ||
        t.contains('permit');
    return _isFoodSection(inspection, category) && isNewOrPermit;
  }

  /// Only one microphone may listen at a time: the inspection screen has
  /// its own AI Guide, so the Dashboard panel is closed before leaving.
  Future<void> _stopDashboardVoice() async {
    if (!_isAi) return;
    try {
      await _voiceVM.closePanel();
    } catch (e) {
      debugPrint('⚠️ Close voice panel error: $e');
    }
  }

  Future<void> _openIncompleteList() async {
    if (!mounted) return;
    await _stopDashboardVoice();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MobileFoodIncompleteListScreen()),
    );
  }

  /// Saved Food inspections (FoodInspection table, logged-in user).
  Future<void> _openFoodIncompleteList({String? query}) async {
    if (!mounted) return;
    await _stopDashboardVoice();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FoodIncompleteListScreen(
          initialQuery: query,
          enableVoice: _isAi, // voice answers only in AI mode
        ),
      ),
    );
  }

  /// Food permits (already synced, shared ViewModel).
  Future<void> _openFoodPermitList({String? query, int? permitId}) async {
    if (!mounted) return;
    await _stopDashboardVoice();
    if (!mounted) return;
    final foodPermitVM = _foodPermitVM;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FoodPermitListScreen(
          viewModel: foodPermitVM,
          initialQuery: query,
          highlightPermitId: permitId,
          // "Start New Inspection" in the permit popup → Food inspection form
          onPermitTap: (p) => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FoodDetailsScreen(
                mode: FoodInspectionEntryMode.newInspection,
                permit: p,
                permitId: p.id,
                enableVoice: _isAi, // voice answers only in AI mode
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Saved Temporary Food inspections (TempFoodInspection table).
  Future<void> _openTempFoodIncompleteList({String? query}) async {
    if (!mounted) return;
    await _stopDashboardVoice();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TempFoodIncompleteListScreen(
          initialQuery: query,
          enableVoice: _isAi, // voice answers only in AI mode
        ),
      ),
    );
  }

  /// Temporary Food permits (already synced, shared ViewModel).
  Future<void> _openTempFoodPermitList({
    String? query,
    int? permitId,
    int? scheduleId,
  }) async {
    if (!mounted) return;
    await _stopDashboardVoice();
    if (!mounted) return;
    final tempFoodPermitVM = _tempFoodPermitVM;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TempFoodPermitListScreen(
          viewModel: tempFoodPermitVM,
          initialQuery: query,
          highlightPermitId: permitId,
          // "Start New Inspection" → Temporary Food inspection form
          onPermitTap: (p) => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TempFoodDetailsScreen(
                mode: TempFoodInspectionEntryMode.newInspection,
                permit: p,
                permitId: p.id,
                // only for the schedule's own permit
                scheduleId: (scheduleId != null && p.id == permitId)
                    ? scheduleId
                    : null,
                enableVoice: _isAi, // voice answers only in AI mode
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Temporary Food schedules (already synced, shared ViewModel).
  /// Tapping a schedule opens the Temp Food permit list on that business.
  Future<void> _openTempFoodScheduleList() async {
    if (!mounted) return;
    await _stopDashboardVoice();
    if (!mounted) return;
    final tempFoodScheduleVM = _tempFoodScheduleVM;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TempFoodInspectionScheduleScreen(
          viewModel: tempFoodScheduleVM,
          onScheduleTap: (s) {
            final id = s.tempFoodPermitId;
            final permit = id == null
                ? null
                : _tempFoodPermits.where((p) => p.id == id).firstOrNull;
                
            _openTempFoodPermitList(
              query: s.businessName ??
                  (permit == null ? null : _tempFoodName(permit)),
              permitId: id,
              scheduleId: s.id, // → "schedule_id"
            );
            
          },
        ),
      ),
    );
  }

  /// Saved Tobacco inspections (TobaccoInspection table, logged-in user).
  Future<void> _openTobaccoIncompleteList({String? query}) async {
    if (!mounted) return;
    await _stopDashboardVoice();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TobaccoIncompleteListScreen(
          initialQuery: query,
          enableVoice: _isAi, // voice answers only in AI mode
        ),
      ),
    );
  }

  /// Tobacco permits (already synced, shared ViewModel).
  /// [scheduleId] / [inspectorId] only apply to the schedule's own permit.
  Future<void> _openTobaccoPermitList({
    String? query,
    int? permitId,
    int? scheduleId,
    int? inspectorId,
  }) async {
    if (!mounted) return;
    await _stopDashboardVoice();
    if (!mounted) return;
    final tobaccoPermitVM = _tobaccoPermitVM;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TobaccoPermitListScreen(
          viewModel: tobaccoPermitVM,
          initialQuery: query,
          highlightPermitId: permitId,
          // "Start New Inspection" → Tobacco inspection form
          onPermitTap: (p) {
            final fromSchedule = scheduleId != null && p.id == permitId;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TobaccoDetailsScreen(
                  mode: TobaccoInspectionEntryMode.newInspection,
                  permit: p,
                  permitId: p.id,
                  // → "schedule_id" (0 = normal inspection)
                  scheduleId: fromSchedule ? scheduleId : 0,
                  inspectorId: fromSchedule ? inspectorId : null,
                  enableVoice: _isAi, // voice answers only in AI mode
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Tobacco schedules (already synced, shared ViewModel).
  /// Tapping a schedule opens the Tobacco permit list on that business.
  Future<void> _openTobaccoScheduleList() async {
    if (!mounted) return;
    await _stopDashboardVoice();
    if (!mounted) return;
    final tobaccoScheduleVM = _tobaccoScheduleVM;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TobaccoInspectionScheduleScreen(
          viewModel: tobaccoScheduleVM,
          enableVoice: _isAi,
          onScheduleTap: (s) {
            final id = s.tobaccoPermitId;
            final permit = id == null
                ? null
                : _tobaccoPermits.where((p) => p.id == id).firstOrNull;
            _openTobaccoPermitList(
              query: s.businessName ??
                  (permit == null ? null : _tobaccoName(permit)),
              permitId: id,
              scheduleId: s.id, // → "schedule_id"
              inspectorId: s.inspectorId,
            );
          },
        ),
      ),
    );
  }

  /// Mobile Food inspection schedules (already synced, shared ViewModel).
  Future<void> _openScheduleList() async {
    if (!mounted) return;
    await _stopDashboardVoice();
    if (!mounted) return;
    final scheduleVM = _scheduleVM;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MobileFoodInspectionScheduleView(
          viewModel: scheduleVM,
          onScheduleTap: (s) {
            final id = s.mobileFoodPermitId;
            final permit = id == null
                ? null
                : context
                    .read<MobileFoodPermitViewModel>()
                    .permits
                    .where((p) => p.id == id)
                    .firstOrNull;
            // Open the permit list on that business to start the inspection.
            _openPermitList(query: permit?.businessName, permitId: id);
          },
        ),
      ),
    );
  }

  /// Food inspection schedules (already synced, shared ViewModel).
  /// Tapping a schedule opens the Food permit list on that business,
  /// where "Start New Inspection" opens the Food inspection form.
  Future<void> _openFoodScheduleList() async {
    if (!mounted) return;
    await _stopDashboardVoice();
    if (!mounted) return;
    final foodScheduleVM = _foodScheduleVM;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FoodInspectionScheduleScreen(
          viewModel: foodScheduleVM,
          onScheduleTap: (s) {
            final id = s.foodPermitId;
            final permit = id == null
                ? null
                : _foodPermits.where((p) => p.id == id).firstOrNull;
            _openFoodPermitList(
              query: s.businessName ?? (permit == null ? null : _foodName(permit)),
              permitId: id,
            );
          },
        ),
      ),
    );
  }

  /// App bar button: choose which schedules to open.
  Future<void> _pickSchedules() async {
    final kind = await showModalBottomSheet<_ScheduleKind>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(_icon('food')),
              title: const Text('Food Schedules'),
              trailing: Text('${_foodScheduleVM.totalCount}'),
              onTap: () => Navigator.pop(ctx, _ScheduleKind.food),
            ),
            ListTile(
              leading: Icon(_icon('temp_food')),
              title: const Text('Temporary Food Schedules'),
              trailing: Text('${_tempFoodScheduleVM.totalCount}'),
              onTap: () => Navigator.pop(ctx, _ScheduleKind.tempFood),
            ),
            ListTile(
              leading: Icon(_icon('mobile_food')),
              title: const Text('Mobile Food Schedules'),
              trailing: Text('${_scheduleVM.totalCount}'),
              onTap: () => Navigator.pop(ctx, _ScheduleKind.mobileFood),
            ),
            ListTile(
              leading: Icon(_icon('tobacco')),
              title: const Text('Tobacco Schedules'),
              trailing: Text('${_tobaccoScheduleVM.totalCount}'),
              onTap: () => Navigator.pop(ctx, _ScheduleKind.tobacco),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || kind == null) return;
    _openSchedulesOf(kind);
  }

  /// Opens a saved inspection at a tab (4 = Email / PDF).
  Future<void> _openInspection(String inspectionId, int step) async {
    if (!mounted) return;
    await _stopDashboardVoice();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FoodMobileDetailsScreen(
          mode: InspectionEntryMode.incomplete,
          inspectionId: inspectionId,
          initialStep: step,
          enableVoice: _isAi, // voice answers only in AI mode
        ),
      ),
    );
  }

  /// AI Guide "submit": opens the inspection on the Final Submit tab and
  /// submits it (inspection → items → temperatures). On success the
  /// screen deletes it from Incomplete and comes back here with a
  /// "submitted successfully" message. If a required field is missing
  /// (e.g. a signature), the Final Submit tab stays open to complete it.
  Future<void> _autoSubmitInspection(String inspectionId) async {
    if (!mounted) return;
    await _stopDashboardVoice(); // stop listening while it submits
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FoodMobileDetailsScreen(
          mode: InspectionEntryMode.incomplete,
          inspectionId: inspectionId,
          autoSubmit: true,
          enableVoice: _isAi,
        ),
      ),
    );
  }

  Future<void> _openPermitList({String? query, int? permitId}) async {
    if (!mounted) return;
    await _stopDashboardVoice();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MobileFoodPermitListScreen(
          initialQuery: query,
          highlightPermitId: permitId,
        ),
      ),
    );
  }

  void _onSubCategoryTap(
    InspectionMenu inspection,
    MenuCategory? category,
    MenuSubCategory sub,
  ) {
    debugPrint('➡️ inspection: ${inspection.id}, '
        'category: ${category?.id}, sub: ${sub.id}, mode: ${widget.mode.name}');

    // Schedule item → Food or Mobile Food schedules, by menu section
    if (_isSchedule(sub)) {
      _openSchedulesOf(_scheduleKindFor(inspection, category));
      return;
    }

    if (_isTobaccoIncomplete(inspection, category, sub)) {
      _openTobaccoIncompleteList();
      return;
    }

    if (_isTobaccoPermits(inspection, category, sub)) {
      _openTobaccoPermitList();
      return;
    }

    if (_isTempFoodIncomplete(inspection, category, sub)) {
      _openTempFoodIncompleteList();
      return;
    }

    if (_isTempFoodPermits(inspection, category, sub)) {
      _openTempFoodPermitList();
      return;
    }

    if (_isMobileFoodNew(inspection, category, sub)) {
      _openPermitList();
      return;
    }

    if (_isMobileFoodIncomplete(inspection, category, sub)) {
      _openIncompleteList();
      return;
    }

    if (_isFoodIncomplete(inspection, category, sub)) {
      _openFoodIncompleteList();
      return;
    }

    if (_isFoodPermits(inspection, category, sub)) {
      _openFoodPermitList();
      return;
    }

    // TODO: navigate other items based on ids, e.g.
    // if (inspection.id == 1 && category?.id == 1 && sub.id == 1) { ... }

    final path = [
      inspection.title,
      if (category != null) category.title,
      sub.title,
    ].join(' › ');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(path)));
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await _performLogout();
  }

  Future<void> _performLogout() async {
    await _voiceVM.closePanel();
    if (!mounted) return;
    await context.read<LoginViewModel>().logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final dashboardVM = context.watch<DashboardViewModel>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.event_note),
            tooltip: 'Inspection Schedules',
            onPressed: _pickSchedules,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      floatingActionButton: _isAi
          ? ListenableBuilder(
              listenable: _voiceVM,
              builder: (context, _) => _voiceVM.isPanelOpen
                  ? const SizedBox.shrink()
                  : FloatingActionButton.extended(
                      onPressed: _voiceVM.openPanel,
                      icon: const Icon(Icons.support_agent),
                      label: const Text('AI Guide'),
                    ),
            )
          : null,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildWelcomeBox(),
                Expanded(child: _buildMenuList(dashboardVM)),
              ],
            ),
            if (_isAi)
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

            // Smart loader for the API sync
            if (_syncVisible)
              Builder(builder: (context) {
                final permitVM = context.read<MobileFoodPermitViewModel>();
                final checklistVM = _checklistVM;
                final inspectorVM = _inspectorVM;
                final scheduleVM = _scheduleVM;
                final foodPermitVM = _foodPermitVM;
                final foodChecklistVM = _foodChecklistVM;
                final foodScheduleVM = _foodScheduleVM;
                return ListenableBuilder(
                  listenable: Listenable.merge([
                    permitVM,
                    checklistVM,
                    _opTypesVM,
                    inspectorVM,
                    scheduleVM,
                    foodPermitVM,
                    foodChecklistVM,
                    foodScheduleVM,
                    _tempFoodPermitVM,
                    _tempFoodChecklistVM,
                    _tempFoodScheduleVM,
                    _tobaccoPermitVM,
                    _tobaccoChecklistVM,
                    _tobaccoScheduleVM,
                  ]),
                  builder: (context, _) => SmartSyncLoader(
                    tasks: _syncTasks(permitVM, checklistVM, inspectorVM,
                        scheduleVM, foodPermitVM, foodChecklistVM,
                        foodScheduleVM),
                    blocking: _syncBlocking,
                    isRunning: _syncRunning,
                    onRetry: _startSync,
                    onDismiss: () => setState(() => _syncVisible = false),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeBox() {
    final user = context.watch<LoginViewModel>().user;
    final firstName = user?.firstName ?? '';
    final lastName = user?.lastName ?? '';
    final initials = '${firstName.isNotEmpty ? firstName[0] : ''}'
            '${lastName.isNotEmpty ? lastName[0] : ''}'
        .toUpperCase();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white,
            child: Text(
              initials.isEmpty ? '?' : initials,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1565C0),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome,',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  '$firstName $lastName'.trim(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isAi ? Icons.auto_awesome : Icons.assignment_outlined,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.mode.label,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuList(DashboardViewModel vm) {
    if (vm.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.errorMessage != null) {
      return Center(child: Text(vm.errorMessage!));
    }

    // Plain ListView (not .builder) so every tile is built and its
    // controller is attached – voice can open items that are off-screen.
    return ListView(
      // extra bottom space so the AI panel doesn't cover the last items
      padding: EdgeInsets.fromLTRB(16, 8, 16, _isAi ? 260 : 16),
      children: vm.menu.map((inspection) {
        final tileKey =
            _tileKeys.putIfAbsent(inspection.id, () => GlobalKey());

        return Card(
          key: tileKey,
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            key: ValueKey('insp_${inspection.id}'),
            controller: _inspCtrl(inspection.id),
            maintainState: true, // keep category tiles built for voice
            initiallyExpanded: vm.expandedInspectionId == inspection.id,
            onExpansionChanged: (expanded) =>
                vm.onInspectionToggled(inspection.id, expanded),
            shape: const Border(),
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade50,
              child: Icon(_icon(inspection.icon), color: Colors.blue.shade700),
            ),
            title: Text(
              inspection.title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            children: inspection.hasCategories
                ? inspection.categories
                    .map((cat) => _buildCategory(vm, inspection, cat))
                    .toList()
                : inspection.subCategories
                    .map((sub) => _buildSubTile(inspection, null, sub))
                    .toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCategory(
    DashboardViewModel vm,
    InspectionMenu inspection,
    MenuCategory category,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: ExpansionTile(
        key: ValueKey('cat_${inspection.id}_${category.id}'),
        controller: _catCtrl(inspection.id, category.id),
        initiallyExpanded: vm.expandedInspectionId == inspection.id &&
            vm.expandedCategoryId == category.id,
        onExpansionChanged: (expanded) =>
            vm.onCategoryToggled(inspection.id, category.id, expanded),
        shape: const Border(),
        leading: Icon(_icon(category.icon), color: Colors.blueGrey),
        title: Text(
          category.title,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        children: category.subCategories
            .map((sub) => _buildSubTile(inspection, category, sub))
            .toList(),
      ),
    );
  }

  Widget _buildSubTile(
    InspectionMenu inspection,
    MenuCategory? category,
    MenuSubCategory sub,
  ) {
    return Padding(
      padding: EdgeInsets.only(left: category != null ? 32 : 16),
      child: ListTile(
        dense: true,
        leading: Icon(_icon(sub.icon), size: 20, color: Colors.grey.shade700),
        title: Text(sub.title, style: const TextStyle(fontSize: 14)),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () => _onSubCategoryTap(inspection, category, sub),
      ),
    );
  }
}
