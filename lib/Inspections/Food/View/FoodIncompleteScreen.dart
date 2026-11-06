import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quincy/Database/DBManager.dart';
import 'package:quincy/Inspections/Food/Model/FoodInspectionModel.dart';
import 'package:quincy/Inspections/Food/View/FoodDetailsScreen.dart';
import 'package:quincy/Inspections/Food/ViewModel/FoodInspectionViewModel.dart';
import 'package:quincy/Login/ViewModel/LoginViewModel.dart';

// ---------------- Theme (same as Food permit list) ----------------
const _kPrimary = Color(0xFF1565C0);
const _kPrimaryLight = Color(0xFF1E88E5);
const _kBackground = Color(0xFFF5F7FA);
const _kTextDark = Color(0xFF1A2B3C);
const _kTextMuted = Color(0xFF6B7A90);
const _kError = Color(0xFFD32F2F);
const _kSuccess = Color(0xFF2E7D32);

/// Tab names, same order as FoodDetailsScreen.
const _kSteps = [
  'Establishment',
  'Inspection Form',
  'Temperature Observations',
  'Final Submit',
  'Email',
];

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "2026-10-27" → "Oct 27, 2026"
String _formatDate(String raw) {
  final d = DateTime.tryParse(raw);
  if (d == null) return raw;
  return '${_months[d.month - 1]} ${d.day.toString().padLeft(2, '0')}, ${d.year}';
}

/// "14:05" → "02:05 PM"
String _formatTime(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length < 2) return hhmm;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return hhmm;
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '${h12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} '
      '${h < 12 ? 'AM' : 'PM'}';
}

/// "Updated 5 min ago" style text from an ISO timestamp.
String _updatedAgo(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso);
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'Updated just now';
  if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes} min ago';
  if (diff.inHours < 24) return 'Updated ${diff.inHours} h ago';
  if (diff.inDays < 7) return 'Updated ${diff.inDays} d ago';
  return 'Updated ${_formatDate(d.toIso8601String())}';
}

/// Saved (not submitted) Food inspections of the logged-in user.
/// Tap → continue in FoodDetailsScreen. Delete → removes the local data.
class FoodIncompleteListScreen extends StatefulWidget {
  const FoodIncompleteListScreen({
    super.key,
    this.enableVoice = true,
    this.initialQuery,
  });

  /// Passed to FoodDetailsScreen (AI Guide on the inspection screen).
  final bool enableVoice;

  /// Pre-fills the search box (e.g. a business name spoken to the AI guide).
  final String? initialQuery;

  @override
  State<FoodIncompleteListScreen> createState() =>
      _FoodIncompleteListScreenState();
}

class _FoodIncompleteListScreenState extends State<FoodIncompleteListScreen> {
  final FoodInspectionViewModel _vm = FoodInspectionViewModel();
  final TextEditingController _searchCtrl = TextEditingController();

  int? _userId;
  bool _initialised = false;

  /// Active checklist items (for the progress bar). 0 = not synced yet.
  int _totalItems = 0;

  String get _query => _searchCtrl.text.trim();

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuery ?? '';
    _searchCtrl.text = q;
    _vm.setQuery(q);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    LoginViewModel? loginVM;
    try {
      loginVM = Provider.of<LoginViewModel>(context, listen: false);
    } on ProviderNotFoundException {
      loginVM = null;
    }
    _userId = loginVM?.user?.id ?? await _vm.getLoggedInUserId();

    try {
      final tree = await DBManager.instance.getFoodChecklistTree();
      _totalItems = tree.fold(0, (s, n) => s + n.itemCount);
    } catch (_) {
      _totalItems = 0;
    }

    await _reload();
    if (mounted) setState(() => _initialised = true);
  }

  Future<void> _reload() async {
    final id = _userId;
    if (id == null) return;
    await _vm.loadIncomplete(id);
  }

  // ---------------- Actions ----------------

  Future<void> _open(FoodInspectionModel i) async {
    FocusScope.of(context).unfocus();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FoodDetailsScreen(
  mode: FoodInspectionEntryMode.incomplete,
  inspectionId: i.inspectionId,
  initialStep: 0, // always open on the Establishment tab
  enableVoice: widget.enableVoice,
),
      ),
    );
    // Back from the form → it may have been saved or submitted.
    if (mounted) await _reload();
  }

  Future<void> _confirmDelete(FoodInspectionModel i) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete inspection?'),
        content: Text(
          'The saved inspection for ${i.businessName.isEmpty ? 'this business' : i.businessName}'
          ' – answers, photos, temperatures and signatures – will be removed '
          'from this device. This cannot be undone.',
        ),
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
    if (ok != true || !mounted) return;
    try {
      await _vm.delete(i.inspectionId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: const Text('Inspection deleted.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _kPrimary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
    } catch (e) {
      debugPrint('❌ Delete Food inspection error: $e');
    }
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackground,
      body: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) {
          final list = _vm.incomplete;
          return Column(
            children: [
              _buildHeader(_vm.totalCount, list.length),
              if (_vm.isLoading && _vm.hasData)
                const LinearProgressIndicator(minHeight: 2, color: _kPrimary),
              Expanded(child: _buildBody(list)),
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
                          'Incomplete Food Inspections',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Tap an inspection to continue',
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
          setState(() {}); // refresh the clear button / counter
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

  Widget _buildBody(List<FoodInspectionModel> list) {
    if (!_initialised || (_vm.isLoading && !_vm.hasData)) {
      return const Center(child: CircularProgressIndicator(color: _kPrimary));
    }

    if (_userId == null) {
      return _buildEmptyState(
        icon: Icons.person_off_outlined,
        title: 'Not logged in',
        message: 'Please log in again to see your inspections.',
      );
    }

    if (!_vm.hasData) {
      return _buildEmptyState(
        icon: Icons.task_alt,
        title: 'No incomplete inspections',
        message: 'Inspections you start from Food → New are saved here '
            'until they are submitted.',
        onRefresh: _reload,
      );
    }

    if (list.isEmpty) {
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
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final insp = list[i];
          return Dismissible(
            key: ValueKey(insp.inspectionId),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) async {
              await _confirmDelete(insp);
              return false; // the list rebuilds itself after delete
            },
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              decoration: BoxDecoration(
                color: _kError.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.delete_outline, color: _kError),
            ),
            child: _IncompleteCard(
              inspection: insp,
              answered: _vm.answeredCount(insp.inspectionId),
              totalItems: _totalItems,
              onTap: () => _open(insp),
              onDelete: () => _confirmDelete(insp),
            ),
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

class _IncompleteCard extends StatelessWidget {
  final FoodInspectionModel inspection;
  final int answered;
  final int totalItems;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _IncompleteCard({
    required this.inspection,
    required this.answered,
    required this.totalItems,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final i = inspection;
    final step = i.currentStep.clamp(0, _kSteps.length - 1);
    final progress =
        totalItems == 0 ? 0.0 : (answered / totalItems).clamp(0.0, 1.0);
    final allAnswered = totalItems > 0 && answered >= totalItems;
    final time = [
      if (i.timeIn.isNotEmpty) _formatTime(i.timeIn),
      if (i.timeOut.isNotEmpty) _formatTime(i.timeOut),
    ].join(' – ');

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
                    color: Color(0xFFFFA000), // amber = in progress
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
                        // ---- Name + permit + delete ----
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.pending_actions,
                                  color: Colors.amber.shade800, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    i.businessName.isEmpty
                                        ? 'Unnamed business'
                                        : i.businessName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: _kTextDark,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  _Chip(
                                    icon: Icons.badge_outlined,
                                    text: i.permitNumber.isEmpty
                                        ? 'No permit #'
                                        : i.permitNumber,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              onPressed: onDelete,
                              icon: const Icon(Icons.delete_outline,
                                  color: _kError),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: Color(0xFFEEF2F7)),
                        const SizedBox(height: 10),

                        // ---- Date / time ----
                        Row(
                          children: [
                            Expanded(
                              child: _InfoItem(
                                icon: Icons.calendar_today_outlined,
                                label: 'Date',
                                value: i.inspectionDate.isEmpty
                                    ? '—'
                                    : _formatDate(i.inspectionDate),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _InfoItem(
                                icon: Icons.schedule,
                                label: 'Time',
                                value: time.isEmpty ? '—' : time,
                              ),
                            ),
                          ],
                        ),
                        if (i.inspector.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _InfoItem(
                            icon: Icons.person_outline,
                            label: 'Inspector',
                            value: i.inspector,
                          ),
                        ],
                        const SizedBox(height: 12),

                        // ---- Progress ----
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 6,
                                  backgroundColor: const Color(0xFFE8F1FC),
                                  color:
                                      allAnswered ? _kSuccess : _kPrimaryLight,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              totalItems == 0
                                  ? '$answered answered'
                                  : '$answered / $totalItems',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _kPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _Chip(
                              icon: Icons.flag_outlined,
                              text: 'Step ${step + 1}: ${_kSteps[step]}',
                            ),
                            const Spacer(),
                            Text(
                              _updatedAgo(i.updatedAt),
                              style: const TextStyle(
                                  fontSize: 11, color: _kTextMuted),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.chevron_right, color: _kTextMuted),
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

  const _Chip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F1FC),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _kPrimary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _kPrimary,
                letterSpacing: 0.3,
              ),
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

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
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
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: _kTextDark,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}