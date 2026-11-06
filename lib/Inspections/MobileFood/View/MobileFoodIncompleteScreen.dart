import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quincy/Inspections/MobileFood/Model/MobileFoodInspectionModel.dart';
import 'package:quincy/Inspections/MobileFood/View/FoodMobileDetailsScreen.dart';
import 'package:quincy/Inspections/MobileFood/ViewModel/MobileFoodInspectionViewModel.dart';

// ---------------- Theme ----------------
const _kPrimary = Color(0xFF1565C0);
const _kPrimaryLight = Color(0xFF1E88E5);
const _kBackground = Color(0xFFF5F7FA);
const _kTextDark = Color(0xFF1A2B3C);
const _kTextMuted = Color(0xFF6B7A90);
const _kWarning = Color(0xFFF57C00);

const _stepNames = [
  'Establishment',
  'Inspection Form',
  'Temperature Observations',
  'Final Submit',
];

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _fmtDate(String raw) {
  final d = DateTime.tryParse(raw);
  if (d == null) return raw;
  return '${_months[d.month - 1]} ${d.day.toString().padLeft(2, '0')}, ${d.year}';
}

/// "13:05" → "01:05 PM"
String _fmtTime(String hhmm) {
  final p = hhmm.split(':');
  if (p.length != 2) return hhmm;
  final h = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  if (h == null || m == null) return hhmm;
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '${h12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} ${h < 12 ? 'AM' : 'PM'}';
}

/// "2 min ago", "3 h ago", "Oct 05, 2026"
String _relative(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays < 7) return '${diff.inDays} d ago';
  return _fmtDate(iso);
}

class MobileFoodIncompleteListScreen extends StatefulWidget {
  /// Pre-fills the search box (e.g. a business name spoken to the AI guide).
  final String? initialQuery;

  const MobileFoodIncompleteListScreen({super.key, this.initialQuery});

  @override
  State<MobileFoodIncompleteListScreen> createState() =>
      _MobileFoodIncompleteListScreenState();
}

class _MobileFoodIncompleteListScreenState
    extends State<MobileFoodIncompleteListScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _query = widget.initialQuery!;
      _searchCtrl.text = _query;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MobileFoodInspectionViewModel>().loadIncomplete();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<MobileFoodInspectionModel> _filter(List<MobileFoodInspectionModel> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((i) {
      return [
        i.businessName,
        i.permitNumber,
        i.inspectionId,
        i.inspectionDate,
        _fmtDate(i.inspectionDate),
        i.inspector,
      ].any((f) => f.toLowerCase().contains(q));
    }).toList();
  }

  Future<void> _open(MobileFoodInspectionModel inspection) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FoodMobileDetailsScreen(
          mode: InspectionEntryMode.incomplete,
          inspectionId: inspection.inspectionId,
        ),
      ),
    );
    // Refresh when coming back – data may have changed
    if (mounted) {
      context.read<MobileFoodInspectionViewModel>().loadIncomplete();
    }
  }

  Future<bool> _confirmDelete(MobileFoodInspectionModel i) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete inspection?'),
        content: Text(
          'The incomplete inspection for "${i.businessName}" will be '
          'permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MobileFoodInspectionViewModel>();
    final all = vm.incompleteInspections;
    final filtered = _filter(all);

    return Scaffold(
      backgroundColor: _kBackground,
      body: Column(
        children: [
          _buildHeader(all.length, filtered.length),
          Expanded(child: _buildBody(vm, all, filtered)),
        ],
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
                          'Incomplete Inspections',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Mobile Food • tap to continue where you left off',
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
                child: Container(
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
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Search business, permit #, date, inspector',
                      hintStyle:
                          const TextStyle(color: _kTextMuted, fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: _kPrimary),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close, color: _kTextMuted),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                            ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
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

  Widget _buildBody(
    MobileFoodInspectionViewModel vm,
    List<MobileFoodInspectionModel> all,
    List<MobileFoodInspectionModel> filtered,
  ) {
    if (vm.isLoading && all.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: _kPrimary));
    }

    if (all.isEmpty) {
      return _empty(
        Icons.task_alt,
        'No incomplete inspections',
        'Inspections you start and leave before submitting will appear here.',
      );
    }

    if (filtered.isEmpty) {
      return _empty(
        Icons.search_off,
        'No matching inspections',
        'Nothing matches "$_query".',
      );
    }

    return RefreshIndicator(
      color: _kPrimary,
      onRefresh: vm.loadIncomplete,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final item = filtered[i];
          return Dismissible(
            key: ValueKey(item.inspectionId),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) => _confirmDelete(item),
            onDismissed: (_) => vm.delete(item.inspectionId),
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              decoration: BoxDecoration(
                color: Colors.red.shade400,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.delete_outline, color: Colors.white),
            ),
            child: _InspectionCard(inspection: item, onTap: () => _open(item)),
          );
        },
      ),
    );
  }

  Widget _empty(IconData icon, String title, String msg) {
    return ListView(
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
            msg,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _kTextMuted, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

// ---------------- Card ----------------

class _InspectionCard extends StatelessWidget {
  final MobileFoodInspectionModel inspection;
  final VoidCallback onTap;

  const _InspectionCard({required this.inspection, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final i = inspection;
    final step = i.currentStep.clamp(0, _stepNames.length - 1);
    final progress = (step + 1) / _stepNames.length;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE3EAF3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.pending_actions,
                        color: _kWarning, size: 22),
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
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (i.permitNumber.isNotEmpty)
                              _chip(i.permitNumber, Icons.badge_outlined),
                            _chip(i.inspectionId, Icons.tag),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: _kTextMuted),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFEEF2F7)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _info(
                      Icons.calendar_today_outlined,
                      'Inspection',
                      _fmtDate(i.inspectionDate),
                    ),
                  ),
                  Expanded(
                    child: _info(
                      Icons.schedule,
                      'Time',
                      '${_fmtTime(i.timeIn)} – ${_fmtTime(i.timeOut)}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: const Color(0xFFE8F1FC),
                        valueColor:
                            const AlwaysStoppedAnimation(_kPrimaryLight),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Step ${step + 1}/${_stepNames.length} • ${_stepNames[step]}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: _kPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (i.updatedAt.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Last saved ${_relative(i.updatedAt)}'
                  '${i.inspector.isNotEmpty ? ' • ${i.inspector}' : ''}',
                  style: const TextStyle(fontSize: 12, color: _kTextMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F1FC),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: _kPrimary),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _kPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _info(IconData icon, String label, String value) {
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
                value.isEmpty ? '—' : value,
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