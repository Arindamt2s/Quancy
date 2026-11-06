import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quincy/Database/DBManager.dart';
import 'package:quincy/Inspections/Tobacco/Model/TobaccoInspectionModel.dart';
import 'package:quincy/Inspections/Tobacco/View/TobaccoDetailsScreen.dart';
import 'package:quincy/Inspections/Tobacco/ViewModel/TobaccoInspectionViewModel.dart';
import 'package:quincy/Login/ViewModel/LoginViewModel.dart';

/// Saved (not submitted) Tobacco inspections of the logged-in user.
/// Tap → opens the inspection with everything saved (Incomplete mode).
/// Same design as the Temporary Food incomplete list.
///
/// Path: lib/Inspections/Tobacco/View/TobaccoIncompleteListScreen.dart

// ---------------- Theme (same as the permit lists) ----------------
const _kPrimary = Color(0xFF1565C0);
const _kPrimaryLight = Color(0xFF1E88E5);
const _kBackground = Color(0xFFF5F7FA);
const _kTextDark = Color(0xFF1A2B3C);
const _kTextMuted = Color(0xFF6B7A90);
const _kError = Color(0xFFD32F2F);
const _kWarning = Color(0xFFEF6C00);

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "2026-07-23" → "Jul 23, 2026"
String _formatDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '';
  final d = DateTime.tryParse(raw);
  if (d == null) return raw;
  return '${_months[d.month - 1]} ${d.day.toString().padLeft(2, '0')}, ${d.year}';
}

/// "2026-07-23T10:15:00" → "Jul 23, 2026 · 10:15 AM"
String _formatDateTime(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '';
  final d = DateTime.tryParse(raw);
  if (d == null) return raw;
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '${_formatDate(raw)} · $h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
}

class TobaccoIncompleteListScreen extends StatefulWidget {
  const TobaccoIncompleteListScreen({
    super.key,
    this.initialQuery,
    this.enableVoice = false,
  });

  /// Pre-fills the search box (e.g. a business name spoken to the AI guide).
  final String? initialQuery;

  /// AI Guide on the inspection screen (AI mode only).
  final bool enableVoice;

  @override
  State<TobaccoIncompleteListScreen> createState() =>
      _TobaccoIncompleteListScreenState();
}

/// Saved inspections + answered counts, read from SQLite.
class _IncompleteData extends ChangeNotifier {
  List<TobaccoInspectionModel> _all = const [];
  Map<String, int> _answered = const {};
  String _query = '';
  bool isLoading = false;
  bool _disposed = false;

  int get incompleteCount => _all.length;
  int answeredCount(String id) => _answered[id] ?? 0;

  List<TobaccoInspectionModel> get incomplete {
    if (_query.isEmpty) return _all;
    return _all.where((i) {
      return [i.businessName, i.permitNumber, i.address, i.inspector]
          .whereType<String>()
          .any((v) => v.toLowerCase().contains(_query));
    }).toList();
  }

  void setQuery(String q) {
    _query = q.trim().toLowerCase();
    _notify();
  }

  Future<void> loadIncomplete(int userId) async {
    isLoading = true;
    _notify();
    try {
      final db = DBManager.instance;
      _all = await db.getIncompleteTobaccoInspections(userId);
      _answered = await db.getTobaccoAnsweredCounts(userId);
    } catch (e) {
      debugPrint('⚠️ Tobacco incomplete load error: $e');
    }
    isLoading = false;
    _notify();
  }

  Future<void> delete(String inspectionId) async {
    await DBManager.instance.deleteTobaccoInspection(inspectionId);
    _all = _all.where((i) => i.inspectionId != inspectionId).toList();
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class _TobaccoIncompleteListScreenState
    extends State<TobaccoIncompleteListScreen> {
  static const _steps = [
    'Establishment',
    'Inspection Form',
    'Final Submit',
    'Email',
  ];

  final _IncompleteData _vm = _IncompleteData();
  final TextEditingController _searchCtrl = TextEditingController();
  int? _userId;
  bool _loadedOnce = false;

  /// Search text as typed (the list keeps a lower-case copy).
  String get _query => _searchCtrl.text.trim();

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = widget.initialQuery ?? '';
    _vm.setQuery(_searchCtrl.text);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _vm.dispose();
    super.dispose();
  }

  // ---------------- Data ----------------

  Future<void> _load() async {
    int? id;
    try {
      id = Provider.of<LoginViewModel>(context, listen: false).user?.id;
    } on ProviderNotFoundException {
      id = null;
    }
    id ??= await DBManager.instance.getLoggedInUserId();
    if (!mounted) return;
    _userId = id;
    if (id != null) await _vm.loadIncomplete(id);
    if (mounted) setState(() => _loadedOnce = true);
  }

  Future<void> _reload() async {
    final id = _userId;
    if (id != null) await _vm.loadIncomplete(id);
  }

  // ---------------- Actions ----------------

  Future<void> _open(TobaccoInspectionModel i) async {
    FocusScope.of(context).unfocus();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TobaccoDetailsScreen(
          mode: TobaccoInspectionEntryMode.resume,
          inspectionId: i.inspectionId,
          scheduleId: i.scheduleId,
          enableVoice: widget.enableVoice,
        ),
      ),
    );
    if (mounted) await _reload();
  }

  Future<void> _delete(TobaccoInspectionModel i) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete inspection?'),
        content: Text('${i.businessName} – all answers and signatures '
            'saved on this device will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: _kError),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _vm.delete(i.inspectionId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${i.businessName} deleted'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackground,
      body: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) {
          final filtered = _vm.incomplete;
          return Column(
            children: [
              _buildHeader(_vm.incompleteCount, filtered.length),
              if (_vm.isLoading && _vm.incompleteCount > 0)
                const LinearProgressIndicator(minHeight: 2, color: _kPrimary),
              Expanded(child: _buildBody(filtered)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(int total, int shown) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kPrimaryLight, _kPrimary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Incomplete Tobacco',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Continue an inspection where you left off',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _query.isEmpty ? '$total' : '$shown / $total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _buildSearchField(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) {
          _vm.setQuery(v);
          setState(() {}); // count pill / clear button
        },
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 15, color: _kTextDark),
        decoration: InputDecoration(
          hintText: 'Search business, permit #, address, inspector',
          hintStyle: const TextStyle(color: _kTextMuted, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: _kPrimary),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, color: _kTextMuted),
                  onPressed: () {
                    _searchCtrl.clear();
                    _vm.setQuery('');
                    setState(() {});
                    FocusScope.of(context).unfocus();
                  },
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildBody(List<TobaccoInspectionModel> filtered) {
    if (!_loadedOnce || (_vm.isLoading && _vm.incompleteCount == 0)) {
      return const Center(child: CircularProgressIndicator(color: _kPrimary));
    }

    if (_vm.incompleteCount == 0) {
      return _buildEmptyState(
        icon: Icons.task_alt,
        title: 'No incomplete inspections',
        message: 'Tobacco inspections you save without submitting '
            'will appear here.',
        onRefresh: _reload,
      );
    }

    if (filtered.isEmpty) {
      return _buildEmptyState(
        icon: Icons.search_off,
        title: 'No matching inspections',
        message: 'Nothing matches "$_query". Try another search.',
      );
    }

    return RefreshIndicator(
      color: _kPrimary,
      onRefresh: _reload,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final i = filtered[index];
          final stepIndex = i.currentStep.clamp(0, _steps.length - 1);
          return _InspectionCard(
            inspection: i,
            stepName: _steps[stepIndex],
            stepIndex: stepIndex,
            stepCount: _steps.length,
            answered: _vm.answeredCount(i.inspectionId),
            query: _query,
            onTap: () => _open(i),
            onDelete: () => _delete(i),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
    Future<void> Function()? onRefresh,
  }) {
    final content = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 44, color: _kPrimary),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: _kTextDark,
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _kTextMuted, fontSize: 14),
          ),
        ),
      ],
    );

    return onRefresh == null
        ? content
        : RefreshIndicator(
            color: _kPrimary, onRefresh: onRefresh, child: content);
  }
}

// ---------------- Inspection card ----------------

class _InspectionCard extends StatelessWidget {
  final TobaccoInspectionModel inspection;
  final String stepName;
  final int stepIndex;
  final int stepCount;
  final int answered;
  final String query;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _InspectionCard({
    required this.inspection,
    required this.stepName,
    required this.stepIndex,
    required this.stepCount,
    required this.answered,
    required this.query,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final i = inspection;
    final name = i.businessName.isEmpty ? 'Unnamed business' : i.businessName;
    final date = _formatDate(i.inspectionDate);
    final updated = _formatDateTime(i.updatedAt);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE3EAF3)),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 5,
                  decoration: const BoxDecoration(
                    color: _kWarning, // incomplete = orange accent
                    borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(16),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.pending_actions,
                                color: _kWarning,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _HighlightText(
                                    text: name,
                                    query: query,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: _kTextDark,
                                    ),
                                    maxLines: 1,
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      _Chip(
                                        icon: Icons.badge_outlined,
                                        text: (i.permitNumber ?? '').isEmpty
                                            ? 'No permit #'
                                            : i.permitNumber!,
                                        query: query,
                                      ),
                                      _Chip(
                                        icon: Icons.flag_outlined,
                                        text:
                                            'Step ${stepIndex + 1}/$stepCount · $stepName',
                                        color: _kWarning,
                                        background: const Color(0xFFFFF3E0),
                                      ),
                                      if (i.scheduleId > 0)
                                        _Chip(
                                          icon: Icons.event_note,
                                          text: 'Schedule #${i.scheduleId}',
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: Color(0xFFEEF2F7)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _InfoItem(
                                icon: Icons.calendar_today_outlined,
                                label: 'Inspection date',
                                value: date.isEmpty ? '—' : date,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _InfoItem(
                                icon: Icons.checklist_rtl,
                                label: 'Answered',
                                value: '$answered items',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _InfoItem(
                                icon: Icons.badge_outlined,
                                label: 'Inspector',
                                value: (i.inspector ?? '').isEmpty
                                    ? '—'
                                    : i.inspector!,
                                query: query,
                              ),
                            ),
                          ],
                        ),
                        if (updated.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Last saved $updated',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: _kTextMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline, color: _kError),
                      onPressed: onDelete,
                    ),
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(Icons.chevron_right, color: _kTextMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;
  final String query;
  final Color color;
  final Color background;

  const _Chip({
    required this.icon,
    required this.text,
    this.query = '',
    this.color = _kPrimary,
    this.background = const Color(0xFFE8F1FC),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: _HighlightText(
              text: text,
              query: query,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
                letterSpacing: 0.3,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String query;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
    this.query = '',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: _kPrimaryLight),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  color: _kTextMuted,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 2),
              _HighlightText(
                text: value,
                query: query,
                style: const TextStyle(
                  fontSize: 13,
                  color: _kTextDark,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Highlights the part of [text] that matches the search [query].
class _HighlightText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;
  final int maxLines;

  const _HighlightText({
    required this.text,
    required this.query,
    required this.style,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final q = query.toLowerCase();
    final start = q.isEmpty ? -1 : text.toLowerCase().indexOf(q);

    if (start < 0) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    final end = start + q.length;
    return RichText(
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: style,
        children: [
          TextSpan(text: text.substring(0, start)),
          TextSpan(
            text: text.substring(start, end),
            style: style.copyWith(
              backgroundColor: const Color(0xFFFFF3B0),
              fontWeight: FontWeight.w800,
            ),
          ),
          TextSpan(text: text.substring(end)),
        ],
      ),
    );
  }
}