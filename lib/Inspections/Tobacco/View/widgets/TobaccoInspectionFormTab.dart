import 'package:flutter/material.dart';
import 'package:quincy/Inspections/Tobacco/Model/TobaccoInspectionModel.dart';
import 'package:quincy/Inspections/Tobacco/Model/TobaccoSectionModel.dart';
import 'package:quincy/Inspections/Tobacco/View/widgets/TobaccoTheme.dart';
import 'package:quincy/Inspections/Tobacco/View/widgets/TobaccoUi.dart';
import 'package:quincy/Inspections/Tobacco/ViewModel/TobaccoInspectionViewModel.dart';

/// Step 2 – Inspection Form (Food-style design).
///
/// Path: lib/Inspections/Tobacco/View/widgets/TobaccoInspectionFormTab.dart
///
/// Progress card on top, then one collapsible tile per section
/// ("SIGNAGE  3/10 ˅"). The open section is vm.sectionIndex, so
/// Next / Previous and the AI Guide open the right one.
/// Question types: YES/NO(/NA) chips, checkbox options (+ "Other" text),
/// product sub-sections (A, B … YES/NO), free text.
class TobaccoInspectionFormTab extends StatefulWidget {
  const TobaccoInspectionFormTab({super.key, required this.vm});
  final TobaccoInspectionViewModel vm;

  @override
  State<TobaccoInspectionFormTab> createState() =>
      _TobaccoInspectionFormTabState();
}

class _TobaccoInspectionFormTabState extends State<TobaccoInspectionFormTab> {
  final _scroll = ScrollController();
  final Map<int, GlobalKey> _keys = {};
  int? _shownIndex;
  bool _collapsed = false;

  TobaccoInspectionViewModel get vm => widget.vm;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(int sectionId) =>
      _keys.putIfAbsent(sectionId, () => GlobalKey());

  /// Brings the open section to the top when it changes (Next, voice …).
  void _scrollToOpen() {
    if (_shownIndex == vm.sectionIndex) return;
    final first = _shownIndex == null;
    _shownIndex = vm.sectionIndex;
    _collapsed = false;
    if (first || vm.sections.isEmpty) return;
    final id = vm.sections[vm.sectionIndex].id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[id]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: 0.02);
      }
    });
  }

  void _onHeaderTap(int i) {
    setState(() {
      if (i == vm.sectionIndex) {
        _collapsed = !_collapsed;
      } else {
        _collapsed = false;
      }
    });
    if (i != vm.sectionIndex) vm.selectSection(i);
  }

  @override
  Widget build(BuildContext context) {
    if (vm.sections.isEmpty) {
      if (vm.checklistLoading) {
        return const Center(
            child: CircularProgressIndicator(color: TbColors.brand));
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(vm.checklistError ?? 'No checklist saved yet.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: tbPrimaryButton(),
                onPressed: () => vm.loadChecklist(forceSync: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Download checklist'),
              ),
            ],
          ),
        ),
      );
    }

    _scrollToOpen();
    final overall = vm.overallProgress;

    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 24),
            children: [
              _ProgressCard(answered: overall.answered, total: overall.total),
              const SizedBox(height: 12),
              for (var i = 0; i < vm.sections.length; i++)
                _SectionTile(
                  key: _keyFor(vm.sections[i].id),
                  vm: vm,
                  section: vm.sections[i],
                  expanded: i == vm.sectionIndex && !_collapsed,
                  onTap: () => _onHeaderTap(i),
                ),
            ],
          ),
        ),
        _BottomBar(vm: vm),
      ],
    );
  }
}

// ------------------------------------------------------------ Top / bottom

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.answered, required this.total});
  final int answered;
  final int total;

  @override
  Widget build(BuildContext context) {
    final value = total == 0 ? 0.0 : answered / total;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: TbColors.brand,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TOBACCO RETAILER INSPECTION CHECKLIST',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3)),
          const SizedBox(height: 4),
          Text('$answered / $total answered',
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 5,
              backgroundColor: Colors.white24,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.vm});
  final TobaccoInspectionViewModel vm;

  @override
  Widget build(BuildContext context) {
    final s = vm.currentSection;
    final p = s == null ? null : vm.progressOf(s);
    return Container(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  s == null ? '' : '${s.name}  ·  ${p!.answered}/${p.total}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: TbColors.textMuted, fontSize: 12),
                ),
              ),
              OutlinedButton.icon(
                style: tbSecondaryButton(),
                onPressed: vm.previousSection,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Previous'),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                style: tbPrimaryButton(),
                onPressed: vm.nextSection,
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: Text(vm.isLastSection ? 'Final Submit' : 'Next'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Section

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    super.key,
    required this.vm,
    required this.section,
    required this.expanded,
    required this.onTap,
  });

  final TobaccoInspectionViewModel vm;
  final TobaccoSectionModel section;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = vm.progressOf(section);
    final done = p.total > 0 && p.answered == p.total;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: expanded ? TbColors.sectionBg : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE3EAF5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onTap,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 4,
                    color: expanded ? TbColors.brand : const Color(0xFFBFD0EE),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 14, 10, 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _title(section.name),
                              style: const TextStyle(
                                  color: TbColors.brandText,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: done
                                  ? TbColors.yes.withOpacity(0.12)
                                  : TbColors.brandSoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('${p.answered}/${p.total}',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: done
                                        ? TbColors.yes
                                        : TbColors.brandText)),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            expanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: TbColors.brandText,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final item in section.activeItems) ...[
                    _Question(vm: vm, item: item),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// "SIGNAGE" → "Signage" (keeps words like "(21+)").
  static String _title(String name) {
    if (name != name.toUpperCase()) return name;
    return name
        .toLowerCase()
        .split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}

// --------------------------------------------------------------- Question

class _Question extends StatelessWidget {
  const _Question({required this.vm, required this.item});
  final TobaccoInspectionViewModel vm;
  final TobaccoItemModel item;

  @override
  Widget build(BuildContext context) {
    final n = vm.numbers[item.id];
    final title = n == null ? item.name : '$n. ${item.name}';

    late final Widget body;
    switch (item.kind) {
      case TobaccoItemKind.yesNo:
        final value = vm.answerValue(item.id);
        final reasons = item.activeChildren;
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AnswerChips(
              value: value,
              withNa: item.hasNa,
              onTap: (v) => vm.setAnswer(item, v),
            ),
            if (reasons.isNotEmpty &&
                value == TobaccoInspectionAnswerModel.no) ...[
              const SizedBox(height: 10),
              const Text('Reason',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: TbColors.textMuted)),
              const SizedBox(height: 6),
              _Options(vm: vm, parent: item, options: reasons),
            ],
          ],
        );
        break;
      case TobaccoItemKind.checkboxes:
        body = _Options(vm: vm, parent: item, options: item.activeChildren);
        break;
      case TobaccoItemKind.text:
        body = _TextAnswer(
            vm: vm, itemId: item.id, hint: 'Enter ${_hint(item.name)}');
        break;
      case TobaccoItemKind.productGroups:
        body = _ProductGroups(vm: vm, item: item);
        break;
    }
    return _QuestionCard(title: title, child: body);
  }

  static String _hint(String name) =>
      name.replaceAll(':', '').trim().toLowerCase();
}

/// Dark-blue header + white body, like the Food question cards.
class _QuestionCard extends StatelessWidget {
  const _QuestionCard(
      {required this.title, required this.child, this.compact = false});
  final String title;
  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDCE4F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: compact ? const Color(0xFF3A66C4) : TbColors.brand,
            padding: EdgeInsets.symmetric(
                horizontal: 12, vertical: compact ? 9 : 11),
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 13 : 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.all(10), child: child),
        ],
      ),
    );
  }
}

/// YES / NO / NA chips (outlined; filled when selected).
class _AnswerChips extends StatelessWidget {
  const _AnswerChips(
      {required this.value, required this.withNa, required this.onTap});
  final String? value;
  final bool withNa;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    Widget chip(String v, String label, Color color) {
      final selected = value == v;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Material(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => onTap(v),
            child: Container(
              constraints: const BoxConstraints(minWidth: 52, minHeight: 36),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: selected ? color : const Color(0xFFD5DCE6)),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : color,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Wrap(
      runSpacing: 6,
      children: [
        chip(TobaccoInspectionAnswerModel.yes, 'YES', TbColors.yes),
        chip(TobaccoInspectionAnswerModel.no, 'NO', TbColors.no),
        if (withNa) chip(TobaccoInspectionAnswerModel.na, 'NA', TbColors.na),
      ],
    );
  }
}

/// Option tiles; "Choose one" questions use radio icons.
/// "Other" shows a text box when checked.
class _Options extends StatelessWidget {
  const _Options(
      {required this.vm, required this.parent, required this.options});
  final TobaccoInspectionViewModel vm;
  final TobaccoItemModel parent;
  final List<TobaccoItemModel> options;

  @override
  Widget build(BuildContext context) {
    final single = parent.isSingleChoice;
    final otherSelected = options
        .any((o) => o.isOtherOption && vm.isOptionSelected(parent.id, o.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in options)
              Builder(builder: (context) {
                final selected = vm.isOptionSelected(parent.id, o.id);
                return Material(
                  color: selected ? TbColors.brandSoft : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => vm.toggleOption(parent, o),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: selected
                                ? TbColors.brand
                                : const Color(0xFFD5DCE6)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            single
                                ? (selected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked)
                                : (selected
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank),
                            size: 18,
                            color: selected
                                ? TbColors.brand
                                : const Color(0xFF9AA5B4),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(o.name,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: selected
                                        ? TbColors.brandText
                                        : TbColors.textDark)),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
        if (otherSelected) ...[
          const SizedBox(height: 8),
          _TextAnswer(vm: vm, itemId: parent.id, hint: 'Please specify'),
        ],
      ],
    );
  }
}

/// Product sub-sections: light-blue header per group, lettered cards.
class _ProductGroups extends StatelessWidget {
  const _ProductGroups({required this.vm, required this.item});
  final TobaccoInspectionViewModel vm;
  final TobaccoItemModel item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final g in item.productGroups) ...[
          if (g.title.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 2, bottom: 8),
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
              decoration: BoxDecoration(
                color: TbColors.subSection,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_outlined,
                      size: 16, color: TbColors.brand),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(g.title,
                        style: const TextStyle(
                            color: TbColors.brandText,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ),
                  Text(
                      '${g.items.where(vm.isAnswered).length}/${g.items.length}',
                      style: const TextStyle(
                          fontSize: 11, color: TbColors.brandText)),
                ],
              ),
            ),
          for (final child in g.items) ...[
            _QuestionCard(
              compact: true,
              title: child.itemLabel == null
                  ? child.name
                  : '${child.itemLabel}. ${child.name}',
              child: child.kind == TobaccoItemKind.text
                  ? _TextAnswer(vm: vm, itemId: child.id, hint: '')
                  : _AnswerChips(
                      value: vm.answerValue(child.id),
                      withNa: child.hasNa,
                      onTap: (v) => vm.setAnswer(child, v),
                    ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

/// Text answer with its own controller (kept while the item is shown).
class _TextAnswer extends StatefulWidget {
  const _TextAnswer({required this.vm, required this.itemId, required this.hint});
  final TobaccoInspectionViewModel vm;
  final int itemId;
  final String hint;

  @override
  State<_TextAnswer> createState() => _TextAnswerState();
}

class _TextAnswerState extends State<_TextAnswer> {
  late final TextEditingController _c =
      TextEditingController(text: widget.vm.textFor(widget.itemId));
  final FocusNode _focus = FocusNode();

  /// Picks up text set by the AI Guide (or cleared by unchecking "Other")
  /// while the user isn't typing in this box.
  @override
  void didUpdateWidget(covariant _TextAnswer old) {
    super.didUpdateWidget(old);
    final saved = widget.vm.textFor(widget.itemId);
    if (old.itemId != widget.itemId || (!_focus.hasFocus && saved != _c.text)) {
      _c.text = saved;
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      focusNode: _focus,
      onChanged: (v) => widget.vm.setText(widget.itemId, v),
      style: const TextStyle(fontSize: 14),
      decoration: tbInputDecoration(hint: widget.hint),
    );
  }
}
