import 'package:flutter/material.dart';


import 'package:quincy/Inspections/MobileFood/Schedule/Model/MobileFoodInspectionscheduleModel.dart';
import 'package:quincy/Inspections/MobileFood/Schedule/ViewModel/MobileFoodInspectionScheduleViewModel.dart' hide MobileFoodInspectionScheduleModel;


/// List of mobile food inspection schedules (offline-first).
///
/// Usage:
///   Navigator.push(context, MaterialPageRoute(
///     builder: (_) => MobileFoodInspectionScheduleView(
///       onScheduleTap: (s) { /* start inspection for s.mobileFoodPermitId */ },
///     ),
///   ));
class MobileFoodInspectionScheduleView extends StatefulWidget {
  const MobileFoodInspectionScheduleView({
    super.key,
    this.inspectorId,
    this.onScheduleTap,
    this.viewModel,
    this.initialFilter = ScheduleFilter.all,
  });

  final int? inspectorId;

  /// Pass the app-wide ViewModel (already synced by the Dashboard) to reuse
  /// its data. If null, the screen creates and disposes its own.
  final MobileFoodInspectionScheduleViewModel? viewModel;
  final void Function(MobileFoodInspectionScheduleModel schedule)?
      onScheduleTap;

  /// Tab selected every time the screen opens (default: All).
  final ScheduleFilter initialFilter;

  @override
  State<MobileFoodInspectionScheduleView> createState() =>
      _MobileFoodInspectionScheduleViewState();
}

class _MobileFoodInspectionScheduleViewState
    extends State<MobileFoodInspectionScheduleView> {
  late final MobileFoodInspectionScheduleViewModel _vm;
  late final bool _ownsVm;
  final _searchCtrl = TextEditingController();

  /// Order of the filter tabs – All first.
  static const List<ScheduleFilter> _tabs = [
    ScheduleFilter.all,
    ScheduleFilter.upcoming,
    ScheduleFilter.today,
    ScheduleFilter.past,
  ];

  @override
  void initState() {
    super.initState();
    _ownsVm = widget.viewModel == null;
    if (_ownsVm) {
      _vm = MobileFoodInspectionScheduleViewModel(
          inspectorId: widget.inspectorId);
      _vm.setFilter(widget.initialFilter); // open on All
      _vm.init();
    } else {
      _vm = widget.viewModel!;
      // Shared ViewModel keeps the last tab → reset to All on every open,
      // and clear any old search.
      _vm.setFilter(widget.initialFilter);
      _vm.setQuery('');
      // Already synced by the Dashboard; only read the DB if never loaded.
      if (!_vm.initialised) _vm.loadFromDb();
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
        title: const Text('Inspection Schedules'),
        actions: [
          ListenableBuilder(
            listenable: _vm,
            builder: (_, __) => IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: _vm.isLoading ? null : _vm.refresh,
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) => Column(
          children: [
            if (_vm.isLoading) const LinearProgressIndicator(minHeight: 2),
            _buildSearch(),
            _buildFilters(),
            if (_vm.showingCached) _buildCachedBanner(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearch() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: TextField(
          controller: _searchCtrl,
          onChanged: _vm.setQuery,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search job code, business, permit, inspector',
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
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );

  Widget _buildFilters() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: _tabs
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

  Widget _buildCachedBanner() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 18, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_vm.error} Showing saved schedules.',
              style: TextStyle(color: scheme.onErrorContainer, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (!_vm.initialised) {
      return const Center(child: CircularProgressIndicator());
    }

    // Error with nothing cached
    if (_vm.error != null && !_vm.hasData) {
      return _MessageState(
        icon: Icons.error_outline,
        title: 'Could not load schedules',
        message: _vm.error!,
        actionLabel: 'Retry',
        onAction: _vm.refresh,
      );
    }

    final groups = _vm.grouped;
    if (groups.isEmpty) {
      return RefreshIndicator(
        onRefresh: _vm.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: 320,
              child: _MessageState(
                icon: Icons.event_available,
                title: _vm.isLoading ? 'Loading…' : 'No schedules',
                message: _vm.query.isNotEmpty
                    ? 'No schedules match your search.'
                    : _vm.filter == ScheduleFilter.all
                        ? 'There are no schedules yet.'
                        : 'There are no ${_vm.filter.label.toLowerCase()} schedules.',
              ),
            ),
          ],
        ),
      );
    }

    final entries = groups.entries.toList();
    return RefreshIndicator(
      onRefresh: _vm.refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: entries.length,
        itemBuilder: (context, i) {
          final e = entries[i];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DateHeader(date: e.key, count: e.value.length),
              ...e.value.map((s) => _ScheduleCard(
                    schedule: s,
                    onTap: widget.onScheduleTap == null
                        ? null
                        : () => widget.onScheduleTap!(s),
                  )),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.date, required this.count});
  final String date;
  final int count;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  String _label() {
    final d = DateTime.tryParse(date);
    if (d == null) return date.isEmpty ? 'No date' : date;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = day.difference(today).inDays;
    final formatted =
        '${_days[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} ${d.year}';
    if (diff == 0) return 'Today · $formatted';
    if (diff == 1) return 'Tomorrow · $formatted';
    if (diff == -1) return 'Yesterday · $formatted';
    return formatted;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _label(),
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Text('$count', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.schedule, this.onTap});
  final MobileFoodInspectionScheduleModel schedule;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = schedule;
    final title = s.businessName ??
        (s.mobileFoodPermitId != null
            ? 'Permit #${s.mobileFoodPermitId}'
            : 'Schedule #${s.id}');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(schedule: s),
                ],
              ),
              const SizedBox(height: 8),
              if (s.jobCode != null)
                _InfoRow(icon: Icons.tag, text: 'Job code: ${s.jobCode}'),
              if (s.isReinspection)
                _InfoRow(
                    icon: Icons.history,
                    text: 'Re-inspection of #${s.previousInspectionId}'),
              if (s.permitNumber != null)
                _InfoRow(
                    icon: Icons.badge_outlined,
                    text: 'Permit: ${s.permitNumber}'),
              if (s.businessAddress != null)
                _InfoRow(
                    icon: Icons.location_on_outlined,
                    text: s.businessAddress!),
              if (s.inspectorName.isNotEmpty)
                _InfoRow(
                    icon: Icons.person_outline,
                    text: 'Inspector: ${s.inspectorName}'),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.schedule});
  final MobileFoodInspectionScheduleModel schedule;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = schedule.isCompleted;
    final bg = done ? scheme.secondaryContainer : scheme.primaryContainer;
    final fg = done ? scheme.onSecondaryContainer : scheme.onPrimaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        schedule.inspectionStatusLabel,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).textTheme.bodySmall?.color;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.disabledColor),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}