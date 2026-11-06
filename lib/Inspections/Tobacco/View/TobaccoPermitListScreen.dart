import 'package:flutter/material.dart';
import 'package:quincy/Inspections/Tobacco/Model/TobaccoPermitModel.dart';
import 'package:quincy/Inspections/Tobacco/View/TobaccoDetailsScreen.dart';
import 'package:quincy/Inspections/Tobacco/ViewModel/TobaccoInspectionViewModel.dart';
import 'package:quincy/Inspections/Tobacco/ViewModel/TobaccoPermitViewModel.dart';

// ---------------- Theme (same as Mobile Food permit list) ----------------
const _kPrimary = Color(0xFF1565C0);
const _kPrimaryLight = Color(0xFF1E88E5);
const _kBackground = Color(0xFFF5F7FA);
const _kTextDark = Color(0xFF1A2B3C);
const _kTextMuted = Color(0xFF6B7A90);

// ---------------- Shared helpers ----------------
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "2026-07-23" / "2026-07-23T10:00:00Z" → "Jul 23, 2026"
String _formatDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '';
  final d = DateTime.tryParse(raw);
  if (d == null) return raw;
  return '${_months[d.month - 1]} ${d.day.toString().padLeft(2, '0')}, ${d.year}';
}

String _cityStateZip(String? city, String? state, String? zip) {
  final stateZip =
      [state, zip].where((e) => e != null && e.isNotEmpty).join(' ');
  return [city, stateZip].where((e) => e != null && e.isNotEmpty).join(', ');
}

/// Best date to show on the card: "date" from the API, else inspection
/// date, else created_at.
String _permitDate(TobaccoPermitModel p) =>
    _formatDate(p.date ?? p.inspectionDate ?? p.createdAt);

/// "business_name" → "Business Name"
String _label(String key) => key
    .replaceAll('_', ' ')
    .split(' ')
    .where((w) => w.isNotEmpty)
    .map((w) => w[0].toUpperCase() + w.substring(1))
    .join(' ');

/// Tobacco permits list (offline-first), opened from Dashboard → Tobacco.
///
/// Path: lib/Inspections/Tobacco/View/TobaccoPermitListScreen.dart
///
/// - Pass [viewModel] to reuse the Dashboard's synced data.
/// - [onPermitTap]: called from "Start New Inspection" in the details popup.
///   If null, the button opens [TobaccoDetailsScreen] for that permit
///   (normal inspection → schedule_id 0).
class TobaccoPermitListScreen extends StatefulWidget {
  const TobaccoPermitListScreen({
    super.key,
    this.viewModel,
    this.initialQuery,
    this.highlightPermitId,
    this.onPermitTap,
    this.enableVoice = false,
  });

  final TobaccoPermitViewModel? viewModel;

  /// Pre-fills the search box (e.g. a business name spoken to the AI guide).
  final String? initialQuery;

  /// If set, the details popup for this permit opens automatically.
  final int? highlightPermitId;

  final void Function(TobaccoPermitModel permit)? onPermitTap;

  /// AI Guide on the inspection form (used only when [onPermitTap] is null).
  final bool enableVoice;

  @override
  State<TobaccoPermitListScreen> createState() =>
      _TobaccoPermitListScreenState();
}

class _TobaccoPermitListScreenState extends State<TobaccoPermitListScreen> {
  late final TobaccoPermitViewModel _vm;
  late final bool _ownsVm;
  final TextEditingController _searchCtrl = TextEditingController();

  /// Search text as typed (the ViewModel keeps a lower-case copy).
  String get _query => _searchCtrl.text.trim();

  @override
  void initState() {
    super.initState();
    _ownsVm = widget.viewModel == null;
    _vm = widget.viewModel ?? TobaccoPermitViewModel();

    final q = widget.initialQuery ?? '';
    _searchCtrl.text = q;
    _vm.setQuery(q);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_vm.initialised || !_vm.hasData) await _vm.loadFromDb();
      // Nothing saved yet → download now
      if (!_vm.hasData) await _vm.syncPermits();
      if (!mounted) return;

      final id = widget.highlightPermitId;
      if (id == null) return;
      final permit = _vm.byId(id);
      if (permit != null) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) _showPermitDetails(permit);
      }
    });
  }

  @override
  void dispose() {
    // Clear the search on a shared VM so the next screen starts clean
    // (after this frame – listeners must not rebuild while unmounting).
    if (!_ownsVm) {
      final vm = _vm;
      WidgetsBinding.instance.addPostFrameCallback((_) => vm.setQuery(''));
    }
    _searchCtrl.dispose();
    if (_ownsVm) _vm.dispose();
    super.dispose();
  }

  // ---------------- Actions ----------------

  void _showPermitDetails(TobaccoPermitModel permit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => TobaccoPermitDetailsSheet(
        permit: permit,
        onStartInspection: () {
          Navigator.pop(sheetContext); // close the details sheet
          if (widget.onPermitTap != null) {
            widget.onPermitTap!(permit);
          } else {
            _startInspection(permit);
          }
        },
      ),
    );
  }

  /// Opens the Tobacco inspection form pre-filled from [permit].
  /// Normal inspection → schedule_id 0.
  void _startInspection(TobaccoPermitModel permit) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TobaccoDetailsScreen(
          mode: TobaccoInspectionEntryMode.newInspection,
          permit: permit,
          permitId: permit.id,
          scheduleId: 0,
          enableVoice: widget.enableVoice,
        ),
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
          final filtered = _vm.permits;
          return Column(
            children: [
              _buildHeader(_vm.totalCount, filtered.length),
              if (_vm.isLoading && _vm.hasData)
                const LinearProgressIndicator(
                    minHeight: 2, color: _kPrimary),
              if (_vm.error != null && _vm.hasData) _buildOfflineBanner(),
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
                          'Tobacco Permits',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Select a permit to start a new inspection',
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
        onChanged: _vm.setQuery,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 15, color: _kTextDark),
        decoration: InputDecoration(
          hintText: 'Search establishment, permit #, address, city, applicant',
          hintStyle: const TextStyle(color: _kTextMuted, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: _kPrimary),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, color: _kTextMuted),
                  onPressed: () {
                    _searchCtrl.clear();
                    _vm.setQuery('');
                    FocusScope.of(context).unfocus();
                  },
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 18, color: Colors.orange.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Offline – showing saved permits',
              style: TextStyle(color: Colors.orange.shade900, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(List<TobaccoPermitModel> filtered) {
    if (!_vm.initialised || (_vm.isLoading && !_vm.hasData)) {
      return const Center(child: CircularProgressIndicator(color: _kPrimary));
    }

    if (!_vm.hasData) {
      return _buildEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No permits saved',
        message: _vm.error ?? 'Pull down to download permits.',
        onRefresh: _vm.syncPermits,
      );
    }

    if (filtered.isEmpty) {
      return _buildEmptyState(
        icon: Icons.search_off,
        title: 'No matching permits',
        message: 'Nothing matches "$_query". Try another search.',
      );
    }

    return RefreshIndicator(
      color: _kPrimary,
      onRefresh: _vm.syncPermits,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final p = filtered[i];
          return _PermitCard(
            permit: p,
            formattedDate: _permitDate(p),
            location: _cityStateZip(p.city, p.state, p.zip),
            query: _query,
            isHighlighted: p.id == widget.highlightPermitId,
            onTap: () => _showPermitDetails(p),
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

// ---------------- Permit card ----------------

class _PermitCard extends StatelessWidget {
  final TobaccoPermitModel permit;
  final String formattedDate;
  final String location;
  final String query;
  final bool isHighlighted;
  final VoidCallback onTap;

  const _PermitCard({
    required this.permit,
    required this.formattedDate,
    required this.location,
    required this.query,
    required this.isHighlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = permit.businessName ?? 'Unnamed business';

    return Material(
      color: isHighlighted ? const Color(0xFFF0F6FF) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHighlighted ? _kPrimaryLight : const Color(0xFFE3EAF3),
              width: isHighlighted ? 1.5 : 1,
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 5,
                  decoration: const BoxDecoration(
                    color: _kPrimaryLight,
                    borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(16),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.storefront,
                                color: _kPrimary,
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
                                  _PermitChip(
                                    text: permit.permitNumber ?? 'No permit #',
                                    query: query,
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
                                label: 'Date',
                                value: formattedDate.isEmpty
                                    ? '—'
                                    : formattedDate,
                                query: query,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _InfoItem(
                                icon: Icons.location_on_outlined,
                                label: 'Location',
                                value: location.isEmpty ? '—' : location,
                                query: query,
                              ),
                            ),
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

class _PermitChip extends StatelessWidget {
  final String text;
  final String query;

  const _PermitChip({required this.text, required this.query});

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
          const Icon(Icons.badge_outlined, size: 13, color: _kPrimary),
          const SizedBox(width: 4),
          Flexible(
            child: _HighlightText(
              text: text,
              query: query,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _kPrimary,
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
    required this.query,
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

// ---------------- Permit details popup ----------------

class TobaccoPermitDetailsSheet extends StatelessWidget {
  final TobaccoPermitModel permit;

  /// Null → no "Start New Inspection" button (details only).
  final VoidCallback? onStartInspection;

  const TobaccoPermitDetailsSheet({
    super.key,
    required this.permit,
    this.onStartInspection,
  });

  /// API keys already shown in the sections above "More details".
  static const _shownKeys = {
    'id', 'permit_number', 'establishment_name', 'business_name',
    'business_address', 'city', 'state', 'zip', 'phone', 'permit_email',
    'email', 'owner_name', 'applicant_name', 'applicant_address',
    'applicant_city', 'applicant_state', 'applicant_zip', 'inspection_date',
    'status', 'isDelete', 'created_at', 'updated_at', 'deleted_at', 'date',
    // internal / file names – not useful to the inspector
    'individual_signature', 'applicant_signature', 'social_security_number',
  };

  @override
  Widget build(BuildContext context) {
    final p = permit;
    final raw = p.raw;

    // Every other field the API sent (text values only).
    final more = <String, String>{
      for (final e in raw.entries)
        if (!_shownKeys.contains(e.key) &&
            e.value != null &&
            e.value is! Map &&
            e.value is! List &&
            e.value.toString().trim().isNotEmpty)
          _label(e.key): e.key.endsWith('_date') || e.key.endsWith('_at')
              ? _formatDate(e.value.toString())
              : e.value.toString(),
    };

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: _kBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 10, 12, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_kPrimaryLight, _kPrimary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.white54,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.storefront,
                            color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.businessName ?? 'Unnamed business',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                p.permitNumber ?? 'No permit #',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Details
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                children: [
                  _Section(
                    title: 'Permit',
                    icon: Icons.assignment_outlined,
                    rows: {
                      'Date': _permitDate(p),
                      'Status': p.status ?? '',
                      'Inspection date': _formatDate(p.inspectionDate),
                    },
                  ),
                  _Section(
                    title: 'Business',
                    icon: Icons.storefront_outlined,
                    rows: {
                      'Address': p.businessAddress ?? '',
                      'City / State / Zip':
                          _cityStateZip(p.city, p.state, p.zip),
                      'Phone': p.phone ?? '',
                      'Email': p.email ?? '',
                    },
                  ),
                  _Section(
                    title: 'Owner',
                    icon: Icons.person_outline,
                    rows: {
                      'Owner': p.ownerName ?? '',
                      'Applicant': p.applicantName ?? '',
                      'Applicant address': [
                        p.raw['applicant_address']?.toString() ?? '',
                        _cityStateZip(
                          p.raw['applicant_city']?.toString(),
                          p.raw['applicant_state']?.toString(),
                          p.raw['applicant_zip']?.toString(),
                        ),
                      ].where((e) => e.trim().isNotEmpty).join(', '),
                    },
                  ),
                  _Section(
                    title: 'More details',
                    icon: Icons.info_outline,
                    rows: more,
                  ),
                ],
              ),
            ),

            // Action
            if (onStartInspection != null)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: onStartInspection,
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text('Start New Inspection'),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Map<String, String> rows;

  const _Section({
    required this.title,
    required this.icon,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final visible = rows.entries.where((e) => e.value.trim().isNotEmpty);
    if (visible.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3EAF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: _kPrimary),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _kPrimary,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...visible.map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      e.key,
                      style: const TextStyle(
                        fontSize: 13,
                        color: _kTextMuted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      e.value,
                      style: const TextStyle(
                        fontSize: 14,
                        color: _kTextDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}