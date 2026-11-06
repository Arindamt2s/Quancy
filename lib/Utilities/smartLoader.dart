import 'package:flutter/material.dart';

import 'package:quincy/Utilities/SyncStatus.dart';

const _kPrimary = Color(0xFF1565C0);
const _kPrimaryLight = Color(0xFF1E88E5);
const _kTextDark = Color(0xFF1A2B3C);
const _kTextMuted = Color(0xFF6B7A90);
const _kSuccess = Color(0xFF2E7D32);
const _kWarning = Color(0xFFEF6C00);
const _kError = Color(0xFFD32F2F);

/// One row in the loader ("Permits • 25 saved").
class SyncTaskView {
  final String label;
  final IconData icon;
  final SyncStatus status;
  final int count;
  final String unit;

  const SyncTaskView({
    required this.label,
    required this.icon,
    required this.status,
    this.count = 0,
    this.unit = 'records',
  });
}

/// Smart loader for the API sync.
///
/// * [blocking] = true  → full-screen card (first sync, nothing saved yet)
/// * [blocking] = false → compact banner; the dashboard stays usable,
///   tap it to see each download.
class SmartSyncLoader extends StatefulWidget {
  final List<SyncTaskView> tasks;
  final bool blocking;
  final bool isRunning;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  const SmartSyncLoader({
    super.key,
    required this.tasks,
    required this.blocking,
    required this.isRunning,
    required this.onRetry,
    required this.onDismiss,
  });

  @override
  State<SmartSyncLoader> createState() => _SmartSyncLoaderState();
}

class _SmartSyncLoaderState extends State<SmartSyncLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  bool _expanded = false;

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  // ---------------- Derived state ----------------

  int get _finished => widget.tasks.where((t) => t.status.isFinished).length;
  double get _progress =>
      widget.tasks.isEmpty ? 0 : _finished / widget.tasks.length;
  bool get _hasFailed => widget.tasks.any((t) => t.status == SyncStatus.failed);
  bool get _hasOffline =>
      widget.tasks.any((t) => t.status == SyncStatus.offline);
  bool get _allDone =>
      !widget.isRunning && widget.tasks.every((t) => t.status == SyncStatus.done);

  String get _title {
    if (widget.isRunning) {
      return widget.blocking ? 'Preparing your inspections' : 'Syncing data';
    }
    if (_hasFailed) return 'Some data could not be downloaded';
    if (_hasOffline) return 'Working with saved data';
    return 'All data is up to date';
  }

  String get _subtitle {
    if (widget.isRunning) {
      final current = widget.tasks
          .firstWhere((t) => t.status == SyncStatus.loading,
              orElse: () => widget.tasks.last)
          .label;
      return 'Downloading $current • $_finished of ${widget.tasks.length}';
    }
    if (_hasFailed) return 'Check your connection and try again.';
    if (_hasOffline) return 'You are offline. Saved data will be used.';
    return '${widget.tasks.length} of ${widget.tasks.length} completed';
  }

  Color get _accent {
    if (widget.isRunning) return _kPrimary;
    if (_hasFailed) return _kError;
    if (_hasOffline) return _kWarning;
    return _kSuccess;
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return widget.blocking ? _buildBlocking() : _buildCompact();
  }

  Widget _buildBlocking() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.35),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Material(
            color: Colors.white,
            elevation: 12,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _statusIcon(size: 56),
                  const SizedBox(height: 16),
                  Text(
                    _title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _kTextDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: _kTextMuted),
                  ),
                  const SizedBox(height: 18),
                  _progressBar(height: 8),
                  const SizedBox(height: 16),
                  ...widget.tasks.map(_taskRow),
                  if (!widget.isRunning) ...[
                    const SizedBox(height: 14),
                    _actions(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompact() {
    return Positioned(
      left: 16,
      right: 16,
      top: 8,
      child: Material(
        color: Colors.white,
        elevation: 6,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _expanded = !_expanded),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _statusIcon(size: 34),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _kTextDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12, color: _kTextMuted),
                            ),
                          ],
                        ),
                      ),
                      if (!widget.isRunning && !_allDone)
                        TextButton(
                          onPressed: widget.onRetry,
                          child: const Text('Retry'),
                        ),
                      if (!widget.isRunning)
                        IconButton(
                          icon: const Icon(Icons.close,
                              size: 18, color: _kTextMuted),
                          onPressed: widget.onDismiss,
                          visualDensity: VisualDensity.compact,
                        )
                      else
                        Icon(
                          _expanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: _kTextMuted,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: _progressBar(height: 5),
                  ),
                  if (_expanded) ...[
                    const SizedBox(height: 10),
                    ...widget.tasks.map(_taskRow),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusIcon({required double size}) {
    final bg = _accent.withOpacity(0.12);

    Widget icon;
    if (widget.isRunning) {
      icon = RotationTransition(
        turns: _spin,
        child: Icon(Icons.sync, color: _kPrimary, size: size * 0.55),
      );
    } else if (_hasFailed) {
      icon = Icon(Icons.cloud_off, color: _kError, size: size * 0.55);
    } else if (_hasOffline) {
      icon = Icon(Icons.offline_pin_outlined, color: _kWarning, size: size * 0.55);
    } else {
      icon = Icon(Icons.check_rounded, color: _kSuccess, size: size * 0.6);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: KeyedSubtree(key: ValueKey(_title), child: icon),
      ),
    );
  }

  Widget _progressBar({required double height}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: _progress),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (_, value, __) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: LinearProgressIndicator(
          value: widget.isRunning && value == 0 ? null : value,
          minHeight: height,
          backgroundColor: const Color(0xFFE8F1FC),
          valueColor: AlwaysStoppedAnimation(
            widget.isRunning ? _kPrimaryLight : _accent,
          ),
        ),
      ),
    );
  }

  Widget _taskRow(SyncTaskView t) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(t.icon, size: 17, color: _kPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              t.label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _kTextDark,
              ),
            ),
          ),
          _statusTrailing(t),
        ],
      ),
    );
  }

  Widget _statusTrailing(SyncTaskView t) {
    switch (t.status) {
      case SyncStatus.pending:
        return const Text('Waiting',
            style: TextStyle(fontSize: 12, color: _kTextMuted));
      case SyncStatus.loading:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: _kPrimary),
        );
      case SyncStatus.done:
        return _pill('${t.count} ${t.unit}', Icons.check_circle, _kSuccess);
      case SyncStatus.offline:
        return _pill('Saved • ${t.count}', Icons.offline_pin, _kWarning);
      case SyncStatus.failed:
        return _pill('Failed', Icons.error_outline, _kError);
    }
  }

  Widget _pill(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions() {
    if (_allDone) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: widget.onDismiss,
          style: _primaryStyle(),
          child: const Text('Continue'),
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: widget.onDismiss,
            style: OutlinedButton.styleFrom(
              foregroundColor: _kPrimary,
              side: const BorderSide(color: _kPrimary),
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(_hasFailed ? 'Continue anyway' : 'Continue offline'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: widget.onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
            style: _primaryStyle(),
          ),
        ),
      ],
    );
  }

  ButtonStyle _primaryStyle() => ElevatedButton.styleFrom(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );
}