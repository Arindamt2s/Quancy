import 'dart:async';

import 'package:flutter/material.dart';
import 'package:quincy/Inspections/Tobacco/Model/TobaccoInspectionModel.dart';
import 'package:quincy/Inspections/Tobacco/Model/TobaccoJson.dart';
import 'package:quincy/Inspections/Tobacco/View/widgets/TobaccoSignaturePad.dart';
import 'package:quincy/Inspections/Tobacco/View/widgets/TobaccoTheme.dart';
import 'package:quincy/Inspections/Tobacco/View/widgets/TobaccoUi.dart';
import 'package:quincy/Inspections/Tobacco/ViewModel/TobaccoInspectionViewModel.dart';

/// Step 3 – Final Submit (same fields as the web form):
///   Date of Reinspection · Purpose of Inspection · Operations Types
///   Discussion with Person-in-Charge · Other Information
///   Signature of Person-in-Charge + date · Signature of Inspector + date
///
/// Path: lib/Inspections/Tobacco/View/widgets/TobaccoFinalSubmitTab.dart
///
/// Purpose list: kTobaccoPurposeOptions (TobaccoInspectionModel.dart).
/// Operations Types: mobile_food_operation_types table (Dashboard sync).
/// Everything is saved to SQLite as you go and printed on the PDF.
class TobaccoFinalSubmitTab extends StatefulWidget {
  const TobaccoFinalSubmitTab({super.key, required this.vm});
  final TobaccoInspectionViewModel vm;

  @override
  State<TobaccoFinalSubmitTab> createState() => _TobaccoFinalSubmitTabState();
}

class _TobaccoFinalSubmitTabState extends State<TobaccoFinalSubmitTab> {
  final _discussion = TextEditingController();
  final _other = TextEditingController();
  Timer? _debounce;
  String? _loadedFor;
  bool _lockScroll = false;

  TobaccoInspectionViewModel get vm => widget.vm;

  @override
  void initState() {
    super.initState();
    _fill();
  }

  @override
  void didUpdateWidget(covariant TobaccoFinalSubmitTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _fill();
  }

  void _fill() {
    final f = vm.finalSubmit;
    if (f == null || _loadedFor == f.inspectionId) return;
    _loadedFor = f.inspectionId;
    _discussion.text = f.discussion ?? '';
    _other.text = f.otherInformation ?? '';
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _saveText();
    _discussion.dispose();
    _other.dispose();
    super.dispose();
  }

  void _onTextChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _saveText);
  }

  void _saveText() {
    if (vm.finalSubmit == null || !vm.isSaved) return;
    vm.updateFinal(
      (f) => f.copyWith(
        discussion: _discussion.text,
        otherInformation: _other.text,
      ),
      notify: false,
    );
  }

  Future<void> _pickDate(
      String? current, void Function(String value) onPicked) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(current ?? '') ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) onPicked(tbDateOnly(picked));
  }

  /// Opens the Email tab (PDF inside the screen).
  Future<void> _previewPdf() async {
    _debounce?.cancel();
    _saveText();
    await vm.flush();
    await vm.goToStep(TobaccoInspectionViewModel.stepEmail);
  }

  Future<void> _submit() async {
    _debounce?.cancel();
    _saveText();
    await vm.flush();
    final msg = await vm.submit();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    if (vm.inspection?.isCompleted ?? false) Navigator.of(context).maybePop();
  }

  // ----------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final f = vm.finalSubmit ??
        TobaccoFinalSubmitModel(inspectionId: vm.inspection!.inspectionId);

    return Column(
      children: [
        Expanded(
          child: ListView(
            physics: _lockScroll
                ? const NeverScrollableScrollPhysics()
                : const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 16),
            children: [
              LayoutBuilder(builder: (context, c) {
                final visit = _visitCard(f);
                final discussion = _textCard(
                    'Discussion with Person-in-Charge:', _discussion,
                    hint: 'What was discussed with the person in charge');
                final other = _textCard('Other Information:', _other,
                    hint: 'Anything else to note');
                final picSig = _signatureCard(
                  title: 'Signature of Person-in-Charge:',
                  kind: TobaccoSignatureKind.pic,
                  path: vm.resolveFile(f.picSignature),
                  date: f.picSignDate,
                  onDate: (v) =>
                      vm.updateFinal((x) => x.copyWith(picSignDate: v)),
                );
                final inspSig = _signatureCard(
                  title: 'Signature of Inspector:',
                  kind: TobaccoSignatureKind.inspector,
                  path: vm.resolveFile(f.inspectorSignature),
                  date: f.inspectorSignDate,
                  onDate: (v) =>
                      vm.updateFinal((x) => x.copyWith(inspectorSignDate: v)),
                );

                const gap = SizedBox(width: 12, height: 12);
                // No IntrinsicHeight: the signature pad uses LayoutBuilder.
                Widget row(List<Widget> items) => Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < items.length; i++) ...[
                          if (i > 0) gap,
                          Expanded(child: items[i]),
                        ],
                      ],
                    );

                if (c.maxWidth >= 900) {
                  // Web layout: 3 cards, then 2 signature cards.
                  return Column(children: [
                    row([visit, discussion, other]),
                    const SizedBox(height: 16),
                    row([picSig, inspSig]),
                  ]);
                }
                if (c.maxWidth >= 600) {
                  return Column(children: [
                    row([visit, discussion]),
                    gap,
                    other,
                    const SizedBox(height: 16),
                    row([picSig, inspSig]),
                  ]);
                }
                return Column(children: [
                  visit, gap, discussion, gap, other, gap, picSig, gap, inspSig,
                ]);
              }),
            ],
          ),
        ),
        Container(
          color: Colors.white,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    style: tbSecondaryButton(),
                    onPressed: () =>
                        vm.goToStep(TobaccoInspectionViewModel.stepForm),
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Previous'),
                  ),
                  OutlinedButton.icon(
                    style: tbSecondaryButton(),
                    onPressed: _previewPdf,
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('Preview PDF'),
                  ),
                  FilledButton.icon(
                    style: tbPrimaryButton(TbColors.yes),
                    onPressed: vm.submitting ? null : _submit,
                    icon: vm.submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.cloud_upload_outlined, size: 18),
                    label: const Text('Submit'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------- cards

  Widget _visitCard(TobaccoFinalSubmitModel f) {
    // Keep a saved purpose even if it isn't in the list any more.
    final purposes = [
      ...vm.purposeOptions,
      if ((f.purpose ?? '').isNotEmpty && !vm.purposeOptions.contains(f.purpose))
        f.purpose!,
    ];
    final types = vm.operationTypes;
    final typeSelected = types.any((t) => t.id == f.operationTypeId);

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TbLabel('Date of Reinspection'),
          _DateField(
            value: f.reinspectionDate,
            hint: 'Select Date',
            onTap: () => _pickDate(f.reinspectionDate,
                (v) => vm.updateFinal((x) => x.copyWith(reinspectionDate: v))),
            onClear: (f.reinspectionDate ?? '').isEmpty
                ? null
                : () => vm.updateFinal(
                    (x) => x.copyWith(clearReinspectionDate: true)),
          ),
          const SizedBox(height: 14),
          const TbLabel('Purpose of Inspection'),
          DropdownButtonFormField<String>(
            value: (f.purpose ?? '').isEmpty ? null : f.purpose,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down, color: TbColors.brand),
            decoration: tbInputDecoration(),
            hint: const Text('Select purpose', style: TextStyle(fontSize: 14)),
            items: [
              for (final p in purposes)
                DropdownMenuItem(value: p, child: Text(p)),
            ],
            onChanged: (v) {
              if (v != null) vm.updateFinal((x) => x.copyWith(purpose: v));
            },
          ),
          const SizedBox(height: 14),
          const TbLabel('Operations Types'),
          DropdownButtonFormField<int>(
            value: typeSelected ? f.operationTypeId : null,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down, color: TbColors.brand),
            decoration: tbInputDecoration(),
            hint: Text(
              types.isEmpty
                  ? 'No operation types saved – sync on Dashboard'
                  : 'Select operation type',
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
            items: [
              for (final t in types)
                DropdownMenuItem(
                  value: t.id,
                  child: Text(t.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: types.isEmpty
                ? null
                : (id) {
                    final t = types.firstWhere((e) => e.id == id);
                    vm.updateFinal((x) => x.copyWith(
                        operationTypeId: t.id, operationTypeName: t.name));
                  },
          ),
        ],
      ),
    );
  }

  Widget _textCard(String title, TextEditingController c, {String? hint}) =>
      _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TbLabel(title),
            TextField(
              controller: c,
              minLines: 5,
              maxLines: 8,
              onChanged: _onTextChanged,
              style: const TextStyle(fontSize: 14),
              decoration: tbInputDecoration(hint: hint),
            ),
          ],
        ),
      );

  Widget _signatureCard({
    required String title,
    required TobaccoSignatureKind kind,
    required String? path,
    required String? date,
    required void Function(String value) onDate,
  }) =>
      _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TobaccoSignaturePad(
              label: title,
              savedFilePath: path,
              height: 150,
              onSaved: (png) => vm.saveSignature(kind, png),
              onCleared: () => vm.clearSignature(kind),
              onDrawing: (d) => setState(() => _lockScroll = d),
            ),
            const SizedBox(height: 14),
            _DateField(
              value: date,
              hint: 'MM-DD-YYYY',
              locked: true,
              onTap: () => _pickDate(date, onDate),
            ),
          ],
        ),
      );
}

// ------------------------------------------------------------- Pieces

/// White card like the web form.
class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5EAF2)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0F000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: child,
      );
}

/// Calendar field: "Select Date" / "05-06-2024".
class _DateField extends StatelessWidget {
  const _DateField({
    required this.value,
    required this.hint,
    required this.onTap,
    this.onClear,
    this.locked = false,
  });
  final String? value;
  final String hint;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  /// Grey look (signature dates), still tappable.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final text = tbFormatDateUs(value);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: locked || text.isEmpty
              ? TbColors.fieldFill
              : Colors.white,
          prefixIcon: const Icon(Icons.calendar_month_outlined,
              size: 18, color: TbColors.brand),
          suffixIcon: onClear == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClear),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: TbColors.fieldBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: TbColors.fieldBorder),
          ),
        ),
        child: Text(
          text.isEmpty ? hint : text,
          style: TextStyle(
            fontSize: 14,
            color: text.isEmpty ? const Color(0xFF9AA5B4) : TbColors.textDark,
          ),
        ),
      ),
    );
  }
}
