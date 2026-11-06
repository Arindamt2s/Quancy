import 'package:flutter/material.dart';
import 'package:quincy/Inspections/Tobacco/Schedule/Model/TobaccoInspectionScheduleModel.dart';
import 'package:quincy/Inspections/Tobacco/Schedule/ViewModel/TobaccoInspectionScheduleViewModel.dart';
import 'package:quincy/Inspections/Tobacco/TobaccoDeps.dart';
import 'package:quincy/Inspections/Tobacco/View/TobaccoDetailsScreen.dart';
import 'package:quincy/Inspections/Tobacco/ViewModel/TobaccoInspectionViewModel.dart';

/// Tobacco inspection schedules: search, Upcoming/Today/Past/All filter,
/// grouped by date, pull to refresh, works offline from SQLite.
///
/// Path: lib/Inspections/Tobacco/Schedule/View/TobaccoInspectionScheduleScreen.dart
///
/// Pass the Dashboard's view model to reuse what it already synced;
/// otherwise the screen creates (and disposes) its own.
///
/// Tapping a schedule opens the Tobacco inspection with
/// schedule_id = schedule.id (unless [onScheduleTap] is given).
class TobaccoInspectionScheduleScreen extends StatefulWidget {
  const TobaccoInspectionScheduleScreen({
    super.key,
    this.viewModel,
    this.inspectorId,
    this.onScheduleTap,
    this.enableVoice = false,
  });

  /// AI Guide on the inspection opened from a schedule.
  final bool enableVoice;

  final TobaccoInspectionScheduleViewModel? viewModel;
  final int? inspectorId;

  /// Overrides the default "open inspection" action.
  final void Function(TobaccoInspectionScheduleModel schedule)? onScheduleTap;

  @override
  State<TobaccoInspectionScheduleScreen> createState() =>
      _TobaccoInspectionScheduleScreenState();
}

class _TobaccoInspectionScheduleScreenState
    extends State<TobaccoInspectionScheduleScreen> {
  late final TobaccoInspectionScheduleViewModel _vm;
  late final bool _ownsVm;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ownsVm = widget.viewModel == null;
    _vm = widget.viewModel ??
        TobaccoInspectionScheduleViewModel(inspectorId: widget.inspectorId);
    _searchCtrl.text = _vm.query;

    if (_ownsVm) {
      _vm.init(); // DB first, then API
    } else if (!_vm.initialised) {
      _vm.loadFromDb();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    if (_ownsVm) _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tobacco Schedules'),
        actions: [
          AnimatedBuilder(
            animation: _vm,
            builder: (_, __) => IconButton(
              tooltip: 'Refresh',
              onPressed: _vm.isLoading ? null : _vm.refresh,
              icon: _vm.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _vm,
        builder: (context, _) => Column(
          children: [
            _searchBar(),
            _filterChips(),
            if (_vm.isLoading && _vm.fetchedCount > 0)
              _infoBar('Downloading… ${_vm.fetchedCount} schedules',
                  Icons.cloud_download_outlined, Colors.blue),
            if (_vm.showingCached)
              _infoBar('${_vm.error} Showing saved schedules.',
                  Icons.cloud_off, Colors.orange),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- widgets

  Widget _searchBar() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) {
            _vm.setQuery(v);
          },
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search job code, business, permit, address…',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _vm.query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchCtrl.clear();
                      _vm.setQuery('');
                    },
                  ),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );

  Widget _filterChips() => SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: TobaccoScheduleFilter.values
              .map((f) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.label),
                      selected: _vm.filter == f,
                      onSelected: (_) => _vm.setFilter(f),
                    ),
                  ))
              .toList(),
        ),
      );

  Widget _infoBar(String text, IconData icon, Color color) => Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: color))),
        ]),
      );

  Widget _body() {
    // First launch, nothing saved yet.
    if (!_vm.hasData && (_vm.isLoading || !_vm.initialised)) {
      return const Center(child: CircularProgressIndicator());
    }

    // Failed and nothing saved.
    if (!_vm.hasData && _vm.error != null) {
      return _message(
        icon: Icons.error_outline,
        title: _vm.error!,
        action: TextButton.icon(
          onPressed: _vm.refresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      );
    }

    final groups = _vm.grouped;
    if (groups.isEmpty) {
      return _message(
        icon: Icons.event_available,
        title: _vm.query.isNotEmpty
            ? 'No schedules match "${_vm.query}".'
            : 'No ${_vm.filter.label.toLowerCase()} schedules.',
      );
    }

    final entries = groups.entries.toList();
    return RefreshIndicator(
      onRefresh: _vm.refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: entries.length,
        itemBuilder: (_, i) {
          final e = entries[i];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dateHeader(e.key, e.value.length),
              ...e.value.map(_card),
            ],
          );
        },
      ),
    );
  }

  Widget _message({required IconData icon, required String title, Widget? action}) =>
      RefreshIndicator(
        onRefresh: _vm.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            Icon(icon, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 15)),
            ),
            if (action != null) Center(child: action),
          ],
        ),
      );

  Widget _dateHeader(String date, int count) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(children: [
        Text(_formatDate(date),
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        Text('· $count', style: theme.textTheme.bodySmall),
      ]),
    );
  }

  Widget _card(TobaccoInspectionScheduleModel s) {
    final theme = Theme.of(context);
    final title = s.businessName ??
        (s.tobaccoPermitId != null
            ? 'Permit #${s.tobaccoPermitId}'
            : 'Schedule #${s.id}');
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => widget.onScheduleTap != null
            ? widget.onScheduleTap!(s)
            : _openInspection(s),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                _statusChip(s),
              ]),
              if (s.permitNumber != null) ...[
                const SizedBox(height: 4),
                _line(Icons.badge_outlined, 'Permit: ${s.permitNumber}'),
              ],
              if (s.businessAddress != null) ...[
                const SizedBox(height: 4),
                _line(
                    Icons.place_outlined,
                    [s.businessAddress, s.city]
                        .whereType<String>()
                        .join(', ')),
              ],
              if (s.inspectorName.isNotEmpty) ...[
                const SizedBox(height: 4),
                _line(Icons.person_outline, s.inspectorName),
              ],
              const SizedBox(height: 8),
              Row(children: [
                if (s.jobCode != null)
                  Text('Job ${s.jobCode}', style: theme.textTheme.bodySmall),
                const Spacer(),
                if (s.isReinspection)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Re-inspection',
                        style: TextStyle(color: Colors.purple, fontSize: 12)),
                  ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  /// Opens the Tobacco inspection for this schedule (schedule_id = s.id).
  Future<void> _openInspection(TobaccoInspectionScheduleModel s) async {
    final permitId = s.tobaccoPermitId;
    final permit = permitId == null
        ? null
        : await DBManager.instance.getTobaccoPermitById(permitId);
    if (!mounted) return;
    if (permit == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Permit for this schedule is not downloaded yet. Open Tobacco Permits and refresh.')));
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TobaccoDetailsScreen(
        mode: TobaccoInspectionEntryMode.newInspection,
        permit: permit,
        permitId: permit.id,
        scheduleId: s.id,
        inspectorId: s.inspectorId,
        enableVoice: widget.enableVoice,
      ),
    ));
  }

  Widget _line(IconData icon, String text) => Row(children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ]);

  Widget _statusChip(TobaccoInspectionScheduleModel s) {
    final color = s.isCompleted ? Colors.green : Colors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(s.inspectionStatusLabel,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  // ---------------------------------------------------------------- helpers

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  /// "Today", "Tomorrow", "Yesterday" or "Wed, 28 Oct 2026".
  String _formatDate(String raw) {
    final d = DateTime.tryParse(raw);
    if (d == null) return raw.isEmpty ? 'No date' : raw;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = DateTime(d.year, d.month, d.day).difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    return '${_days[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} ${d.year}';
  }
}
