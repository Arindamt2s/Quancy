import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:quincy/Inspections/Tobacco/View/widgets/TobaccoTheme.dart';
import 'package:quincy/Inspections/Tobacco/View/widgets/TobaccoUi.dart';
import 'package:quincy/Inspections/Tobacco/ViewModel/TobaccoInspectionViewModel.dart';
import 'package:quincy/PDF/TobaccoInspectionPdf.dart';

/// Step 4 – Email: the inspection PDF shown inside the screen (under the
/// tabs, like the other tabs) with Print and Share / Email.
///
/// Path: lib/Inspections/Tobacco/View/widgets/TobaccoEmailTab.dart
///
/// Built once each time the tab opens (TobaccoDetailsScreen only builds
/// this widget while the Email tab is selected).
class TobaccoEmailTab extends StatefulWidget {
  const TobaccoEmailTab({super.key, required this.vm});
  final TobaccoInspectionViewModel vm;

  @override
  State<TobaccoEmailTab> createState() => _TobaccoEmailTabState();
}

class _TobaccoEmailTabState extends State<TobaccoEmailTab> {
  Future<Uint8List>? _pdf;
  int _version = 0;

  TobaccoInspectionViewModel get vm => widget.vm;

  String get _fileName {
    final name = vm.inspection?.businessName ?? 'inspection';
    return 'Tobacco_${name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}.pdf';
  }

  /// Same PDF for every page format request (built once per opening).
  Future<Uint8List> _build(PdfPageFormat format) => _pdf ??= () async {
        await vm.flush();
        // Let the Final Submit text boxes finish saving (400 ms debounce).
        await Future.delayed(const Duration(milliseconds: 450));
        return TobaccoInspectionPdf.build(vm, format: PdfPageFormat.a4);
      }();

  void _refresh() => setState(() {
        _pdf = null;
        _version++;
      });

  Future<void> _share() async {
    final bytes = await _build(PdfPageFormat.a4);
    await Printing.sharePdf(bytes: bytes, filename: _fileName);
  }

  Future<void> _print() async {
    final bytes = await _build(PdfPageFormat.a4);
    await Printing.layoutPdf(onLayout: (_) => bytes, name: _fileName);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5EAF2)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: TbColors.iconTile,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.picture_as_pdf_outlined,
                            size: 20, color: TbColors.brand),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Inspection Report',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: TbColors.textDark)),
                            Text('Store Inspection Form (Tobacco)',
                                style: TextStyle(
                                    fontSize: 11, color: TbColors.textMuted)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh, color: TbColors.brand),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFEDF1F6)),
                Expanded(
                  child: PdfPreview(
                    key: ValueKey(_version),
                    build: _build,
                    initialPageFormat: PdfPageFormat.a4,
                    pdfFileName: _fileName,
                    // Our own buttons below.
                    useActions: false,
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    canDebug: false,
                    pdfPreviewPageDecoration: const BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(color: Color(0x22000000), blurRadius: 6),
                      ],
                    ),
                    scrollViewDecoration:
                        const BoxDecoration(color: TbColors.page),
                    loadingWidget: const Center(
                        child: CircularProgressIndicator(
                            color: TbColors.brand)),
                  ),
                ),
              ],
            ),
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
                        vm.goToStep(TobaccoInspectionViewModel.stepFinal),
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Previous'),
                  ),
                  OutlinedButton.icon(
                    style: tbSecondaryButton(),
                    onPressed: _print,
                    icon: const Icon(Icons.print_outlined, size: 18),
                    label: const Text('Print'),
                  ),
                  FilledButton.icon(
                    style: tbPrimaryButton(),
                    onPressed: _share,
                    icon: const Icon(Icons.email_outlined, size: 18),
                    label: const Text('Share / Email'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
