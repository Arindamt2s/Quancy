import 'package:flutter/material.dart';
// VoiceReply: whichever of these declares / exports it (same as Dashboard).
import 'package:quincy/AI/AIBrain.dart' show VoiceReply;
import 'package:quincy/AI/SubmitFlowReply.dart' show VoiceReply;
import 'package:quincy/AI/TobaccoVoiceCommands.dart';
import 'package:quincy/Dashboard/View/AIGuidePanel.dart';
import 'package:quincy/Dashboard/ViewModel/VoiceAssistantViewModel.dart';
import 'package:quincy/Inspections/Tobacco/Model/TobaccoPermitModel.dart';
import 'package:quincy/Inspections/Tobacco/View/Widgets/TobaccoEstablishmentTab.dart';
import 'package:quincy/Inspections/Tobacco/View/Widgets/TobaccoInspectionFormTab.dart';
import 'package:quincy/Inspections/Tobacco/View/widgets/TobaccoFinalSubmitTab.dart';
import 'package:quincy/Inspections/Tobacco/View/widgets/TobaccoEmailTab.dart';

import 'package:quincy/Inspections/Tobacco/View/widgets/TobaccoTheme.dart';
import 'package:quincy/Inspections/Tobacco/ViewModel/TobaccoInspectionViewModel.dart';



/// Tobacco inspection: 1. Establishment → 2. Inspection Form → 3. Final Submit
/// (no Temperature tab).
///
/// Path: lib/Inspections/Tobacco/View/TobaccoDetailsScreen.dart
///
/// * From the permit list   → scheduleId 0.
/// * From the schedule list → scheduleId = schedule.id.
/// * [inspectionId]         → resume a saved inspection.
/// * [enableVoice]          → AI Guide (AI mode): "question 5 yes",
///   "24 B no", "next", "submit" … see [TobaccoVoiceCommands].
class TobaccoDetailsScreen extends StatefulWidget {
  const TobaccoDetailsScreen({
    super.key,
    this.mode = TobaccoInspectionEntryMode.newInspection,
    this.permit,
    this.permitId,
    this.scheduleId = 0,
    this.inspectionId,
    this.inspectorId,
    this.enableVoice = false,
  });

  final TobaccoInspectionEntryMode mode;
  final TobaccoPermitModel? permit;
  final int? permitId;
  final int scheduleId;
  final String? inspectionId;

  /// Pre-selects this inspector (e.g. the schedule's inspector).
  final int? inspectorId;

  /// AI Guide on this screen (Dashboard passes true in AI mode).
  final bool enableVoice;

  @override
  State<TobaccoDetailsScreen> createState() => _TobaccoDetailsScreenState();
}

class _TobaccoDetailsScreenState extends State<TobaccoDetailsScreen> {
  late final TobaccoInspectionViewModel _vm;
  VoiceAssistantViewModel? _voiceVM;
  late final TobaccoVoiceCommands _voice;

  static const _steps = [
    'Establishment',
    'Inspection Form',
    'Final Submit',
    'Email',
  ];

  @override
  void initState() {
    super.initState();
    _vm = TobaccoInspectionViewModel(
      permit: widget.permit,
      permitId: widget.permitId,
      scheduleId: widget.scheduleId,
      inspectionId: widget.inspectionId,
      preferredInspectorId: widget.inspectorId,
      resume: widget.mode == TobaccoInspectionEntryMode.resume,
    );
    _voice = TobaccoVoiceCommands(_vm);
    _vm.init();

    if (widget.enableVoice) {
      final voice = _voiceVM = VoiceAssistantViewModel();
      voice.onCommand = _handleVoice;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await voice.init();
      });
    }
  }

  @override
  void dispose() {
    _voiceVM?.dispose();
    _vm.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ AI Guide

  Future<VoiceReply> _handleVoice(String text) async {
    final r = await _voice.handle(text);
    if (!mounted) return const VoiceReply('');
    switch (r.action) {
      case TobaccoVoiceAction.none:
        return VoiceReply(r.say, keepListening: r.keepListening);
      case TobaccoVoiceAction.closePanel:
        return VoiceReply(r.say,
            keepListening: false, afterSpeak: () async => _voiceVM?.closePanel());
      case TobaccoVoiceAction.previewPdf:
        return VoiceReply(r.say, keepListening: false, afterSpeak: () async {
          await _voiceVM?.closePanel();
          await _vm.flush();
          await _vm.goToStep(TobaccoInspectionViewModel.stepEmail);
        });
      case TobaccoVoiceAction.submit:
        return VoiceReply(r.say, keepListening: false, afterSpeak: _submit);
    }
    // ignore: dead_code
    return VoiceReply(r.say);
  }

  /// Leaving Establishment (any tab tap) first checks the 4 required
  /// fields – red "is required" lines appear on the tab – and saves.
  Future<bool> _leaveEstablishment() async {
    if (_vm.step != TobaccoInspectionViewModel.stepEstablishment) return true;
    final err = await _vm.validateAndSaveEstablishment();
    if (err == null || !mounted) return err == null;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(err)));
    return false;
  }

  Future<void> _goToTab(int i) async {
    if (i == _vm.step) return;
    if (!await _leaveEstablishment()) return;
    await _vm.goToStep(i);
  }

  Future<void> _submit() async {
    await _vm.flush();
    final msg = await _vm.submit();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    if (_vm.inspection?.isCompleted ?? false) Navigator.of(context).maybePop();
  }

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    final voice = _voiceVM;
    return Scaffold(
      backgroundColor: TbColors.page,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [TbColors.appBarStart, TbColors.appBarEnd],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        title: ListenableBuilder(
          listenable: _vm,
          builder: (_, __) {
            final ins = _vm.inspection;
            final sub = ins == null
                ? ''
                : _vm.isSaved
                    ? 'Incomplete · ${ins.inspectionId}'
                    : 'New · ${ins.businessName}';
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Tobacco Inspection',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                if (sub.isNotEmpty)
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.white70)),
              ],
            );
          },
        ),
        actions: [
          ListenableBuilder(
            listenable: _vm,
            builder: (_, __) => (_vm.inspection?.scheduleId ?? _vm.scheduleId) > 0
                ? Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Chip(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.white24,
                      side: BorderSide.none,
                      label: Text('Schedule #${_vm.submitScheduleId}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          // AI Guide in the app bar so it never covers Next / Submit.
          if (voice != null)
            ListenableBuilder(
              listenable: voice,
              builder: (_, __) => voice.isPanelOpen
                  ? const SizedBox.shrink()
                  : TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                      onPressed: voice.openPanel,
                      icon: const Icon(Icons.support_agent),
                      label: const Text('AI Guide'),
                    ),
            ),
        ],
      ),
      body: Stack(
        children: [
          ListenableBuilder(
            listenable: _vm,
            builder: (context, _) {
              if (_vm.loading) {
                return const Center(
                    child: CircularProgressIndicator(color: TbColors.teal));
              }
              if (_vm.inspection == null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_vm.error ?? 'Inspection not found.',
                        textAlign: TextAlign.center),
                  ),
                );
              }
              return Column(
                children: [
                  _StepHeader(
                    titles: _steps,
                    current: _vm.step,
                    enabled: _vm.isSaved,
                    onTap: _goToTab,
                    isDone: _vm.isStepDone,
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: _vm.step,
                      children: [
                        TobaccoEstablishmentTab(vm: _vm),
                        TobaccoInspectionFormTab(vm: _vm),
                        TobaccoFinalSubmitTab(vm: _vm),
                        // Built only while selected → fresh PDF each time.
                        _vm.step == TobaccoInspectionViewModel.stepEmail
                            ? TobaccoEmailTab(vm: _vm)
                            : const SizedBox.shrink(),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          if (voice != null)
            ListenableBuilder(
              listenable: voice,
              builder: (_, __) => voice.isPanelOpen
                  ? Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12 + MediaQuery.paddingOf(context).bottom,
                      child: AIGuidePanel(vm: voice),
                    )
                  : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}

/// Pill tabs exactly like the Food inspection:
/// 1 Establishment · 2 Inspection Form · 3 Final Submit · 4 Email.
/// Current tab dark blue; others light blue with a white number circle;
/// done tabs show a blue check circle. Email shows the PDF below.
class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.titles,
    required this.current,
    required this.enabled,
    required this.onTap,
    required this.isDone,
  });

  final List<String> titles;
  final int current;
  final bool enabled;
  final ValueChanged<int> onTap;
  final bool Function(int step) isDone;

  @override
  Widget build(BuildContext context) {
    final tabs = titles;
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      padding: const EdgeInsets.all(6),
      color: Colors.white,
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              _tab(i, tabs[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tab(int i, String title) {
    final active = i == current;
    final done = isDone(i);

    Widget badge;
    if (done) {
      badge = Container(
        width: 20,
        height: 20,
        decoration: const BoxDecoration(
            shape: BoxShape.circle, color: TbColors.stepDone),
        child: const Icon(Icons.check, size: 13, color: Colors.white),
      );
    } else {
      badge = Container(
        width: 20,
        height: 20,
        alignment: Alignment.center,
        decoration:
            const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
        child: Text('${i + 1}',
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: TbColors.brand)),
      );
    }

    return Material(
      color: active ? TbColors.brand : TbColors.brandSoft,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        // Every tab is tappable; leaving Establishment validates it first.
        onTap: () => onTap(i),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 7, 14, 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              badge,
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      color: active ? Colors.white : TbColors.brand,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
