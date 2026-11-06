import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:quincy/Inspections/Tobacco/Model/TobaccoInspectionModel.dart';
import 'package:quincy/Inspections/Tobacco/Model/TobaccoSectionModel.dart';
import 'package:quincy/Inspections/Tobacco/ViewModel/TobaccoInspectionViewModel.dart';

// =====================================================================
//  Store Inspection Form (Tobacco) – A4 PDF, same layout as the web:
//  City of Quincy letterhead (same as the Mobile Food / Food report),
//  store info box, grey section bars, YES / NO / N/A check columns,
//  checkbox lists, product sub-sections, re-inspection / discussion
//  table and signatures.
//
//  Path: lib/PDF/TobaccoInspectionPdf.dart
// =====================================================================
class TobaccoInspectionPdf {
  TobaccoInspectionPdf._();

  /// Same letterhead assets as MobileFoodReportPdf (pubspec → assets).
  static const String headerAsset = 'assets/images/quincy_report_header.png';
  static const String logoAsset = 'assets/images/newlogo.png';
  static const double _logoSize = 62;

  static const _grey = PdfColor.fromInt(0xFFD9D9D9);
  static const _black = PdfColors.black;
  static const double _fs = 7.5; // normal text
  static const double _fsItem = 6.8; // question rows
  static const double _line = 0.6; // border width
  static const double _checkCol = 26; // YES / NO / N/A columns
  static const double _rowH = 12.5;

  static const _side = pw.BorderSide(color: _black, width: _line);

  /// Bold check mark (vector, sharp at any zoom) – same as Mobile Food.
  static const _checkSvg =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
      '<path d="M1.5 13.4 L4.7 10.2 L9.3 14.7 L19.7 2.4 L22.7 5.2 '
      'L9.5 21 Z" fill="#000000"/></svg>';

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  // ------------------------------------------------------------ preview

  /// Opens a preview page with print / share.
  static Future<void> preview(
      BuildContext context, TobaccoInspectionViewModel vm) async {
    final name = vm.inspection?.businessName ?? 'inspection';
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E53B4),
          foregroundColor: Colors.white,
          title: const Text('Store Inspection Form (Tobacco)'),
        ),
        body: PdfPreview(
          build: (format) => build(vm, format: format),
          initialPageFormat: PdfPageFormat.a4,
          pdfFileName:
              'Tobacco_${name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}.pdf',
          canChangeOrientation: false,
          canChangePageFormat: false,
          canDebug: false,
        ),
      ),
    ));
  }

  // -------------------------------------------------------------- build

  static Future<Uint8List> build(TobaccoInspectionViewModel vm,
      {PdfPageFormat format = PdfPageFormat.a4}) async {
    final ins = vm.inspection!;
    final f = vm.finalSubmit;

    final letterhead = await _asset(headerAsset);
    final logo = await _asset(logoAsset);
    final picSig = await _file(vm.resolveFile(f?.picSignature));
    final inspSig = await _file(vm.resolveFile(f?.inspectorSignature));

    final doc = pw.Document(
      title: 'Store Inspection Form (Tobacco) - ${ins.businessName}',
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
    );

    doc.addPage(pw.MultiPage(
      pageFormat: format,
      margin: const pw.EdgeInsets.fromLTRB(34, 30, 34, 30),
      build: (ctx) => [
        _letterhead(letterhead, logo),
        pw.SizedBox(height: 6),
        pw.Text(
          'SSC 105 CMR 410.000: Chapter II, Minimum Standards of Fitness for '
          'Human Habitation',
          style: pw.TextStyle(font: pw.Font.timesBold(), fontSize: 11),
        ),
        pw.SizedBox(height: 3),
        _titleBox('Store Inspection Form (Tobacco)'),
        _infoTable(vm),
        for (final s in vm.sections) ..._section(vm, s),
        pw.SizedBox(height: 0),
        _finalTable(vm),
        pw.SizedBox(height: 12),
        _signatures(
          picName: f?.picName ?? ins.personInCharge ?? '',
          picSig: picSig,
          picDate: _date(f?.picSignDate),
          inspName: f?.inspectorName ?? ins.inspector ?? '',
          inspSig: inspSig,
          inspDate: _date(f?.inspectorSignDate),
        ),
      ],
    ));
    return doc.save();
  }

  // ------------------------------------------------------------ helpers

  static Future<pw.MemoryImage?> _asset(String path) async {
    try {
      final bytes = await rootBundle.load(path);
      return pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      return null; // asset missing → text letterhead / no logo
    }
  }

  static Future<pw.MemoryImage?> _file(String? path) async {
    if (path == null) return null;
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      return pw.MemoryImage(await file.readAsBytes());
    } catch (_) {
      return null;
    }
  }

  /// "2024-05-06" → "06-May-2024"
  static String _date(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    return '${d.day.toString().padLeft(2, '0')}-${_months[d.month - 1]}-${d.year}';
  }

  static pw.TextStyle _text({double size = _fs, bool bold = false}) =>
      pw.TextStyle(
        fontSize: size,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      );

  static pw.Widget _check({double size = 9}) =>
      pw.SvgImage(svg: _checkSvg, width: size, height: size);

  /// Box with left / right / bottom border (rows stack into one table).
  static const _rowBorder =
      pw.Border(left: _side, right: _side, bottom: _side);

  // --------------------------------------------------------- letterhead

  /// Same as MobileFoodReportPdf: image letterhead if the asset exists,
  /// otherwise logo + City of Quincy text.
  static pw.Widget _letterhead(pw.MemoryImage? image, pw.MemoryImage? logo) {
    if (image != null) {
      return pw.Center(child: pw.Image(image, width: 475));
    }
    final times = pw.Font.timesBold();
    final timesRegular = pw.Font.times();

    final heading = pw.Column(children: [
      pw.Text('City of Quincy, Massachusetts',
          style: pw.TextStyle(font: times, fontSize: 15)),
      pw.SizedBox(height: 6),
      pw.Text('THOMAS P. KOCH, MAYOR',
          style: pw.TextStyle(font: times, fontSize: 10)),
      pw.SizedBox(height: 6),
      pw.Text('DEPARTMENT OF HEALTH',
          style: pw.TextStyle(font: times, fontSize: 10)),
      pw.Text('440 East Squantum Street',
          style: pw.TextStyle(font: timesRegular, fontSize: 9)),
      pw.Text('Quincy, MA 02171',
          style: pw.TextStyle(font: timesRegular, fontSize: 9)),
    ]);

    return pw.Column(children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.SizedBox(
            width: _logoSize,
            height: _logoSize,
            child: logo == null
                ? null
                : pw.Image(logo, fit: pw.BoxFit.contain),
          ),
          pw.Expanded(child: heading),
          pw.SizedBox(width: _logoSize),
        ],
      ),
      pw.SizedBox(height: 4),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Commissioner of Public Health',
              style: pw.TextStyle(font: times, fontSize: 9)),
          pw.Text('Telephone: (617) 376-1275   Fax: (617) 376-1271',
              style: pw.TextStyle(font: times, fontSize: 9)),
        ],
      ),
    ]);
  }

  // ------------------------------------------------------- top of form

  static pw.Widget _titleBox(String title) => pw.Container(
        height: 16,
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _black, width: _line)),
        child: pw.Text(title, style: _text(size: 10, bold: true)),
      );

  /// Inspector / Store Name / Store Address | Date / Permit # / Purpose.
  static pw.Widget _infoTable(TobaccoInspectionViewModel vm) {
    final ins = vm.inspection!;

    pw.Widget cell(String label, String value, {bool bottom = true}) =>
        pw.Container(
          constraints: const pw.BoxConstraints(minHeight: 13),
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          alignment: pw.Alignment.centerLeft,
          decoration: pw.BoxDecoration(
            border: pw.Border(bottom: bottom ? _side : pw.BorderSide.none),
          ),
          child: pw.RichText(
            text: pw.TextSpan(children: [
              pw.TextSpan(text: '$label: ', style: _text(bold: true)),
              pw.TextSpan(text: value, style: _text(bold: true)),
            ]),
          ),
        );

    return pw.Container(
      decoration: const pw.BoxDecoration(border: _rowBorder),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Container(
              decoration:
                  const pw.BoxDecoration(border: pw.Border(right: _side)),
              child: pw.Column(children: [
                cell('Inspector', ins.inspector ?? ''),
                cell('Store Name', ins.businessName),
                cell('Store Address', ins.address ?? '', bottom: false),
              ]),
            ),
          ),
          pw.SizedBox(
            width: 112,
            child: pw.Column(children: [
              cell('Date', _date(ins.inspectionDate)),
              cell('Permit #', ins.permitNumber ?? ''),
              cell('Purpose of Inspection', _purpose(vm), bottom: false),
            ]),
          ),
        ],
      ),
    );
  }

  /// Purpose chosen on Final Submit; if none, the checked options of the
  /// "Purpose of visit" question ("Routine" …).
  static String _purpose(TobaccoInspectionViewModel vm) {
    final chosen = (vm.finalSubmit?.purpose ?? '').trim();
    if (chosen.isNotEmpty) return chosen;
    for (final s in vm.sections) {
      for (final item in s.activeItems) {
        if (item.kind != TobaccoItemKind.checkboxes ||
            !item.name.toLowerCase().contains('purpose')) {
          continue;
        }
        final picked = item.activeChildren
            .where((o) => vm.isOptionSelected(item.id, o.id))
            .map((o) {
          if (o.isOtherOption) {
            final t = vm.textFor(item.id).trim();
            return t.isEmpty ? 'Other' : t;
          }
          // "Routine inspection" → "Routine"
          return o.name.replaceAll(RegExp(r'\s+inspection$', caseSensitive: false), '');
        }).toList();
        return picked.join(', ');
      }
    }
    return '';
  }

  // ----------------------------------------------------------- sections

  static pw.Widget _sectionBar(String title) => pw.Container(
        height: 12,
        alignment: pw.Alignment.center,
        decoration: const pw.BoxDecoration(color: _grey, border: _rowBorder),
        child: pw.Text(title.toUpperCase(), style: _text(size: 7, bold: true)),
      );

  /// All rows of one section. YES / NO (/ N/A) headers are repeated only
  /// when the column set changes (like the web report).
  static List<pw.Widget> _section(
      TobaccoInspectionViewModel vm, TobaccoSectionModel s) {
    final rows = <pw.Widget>[_sectionBar(s.name)];
    int? cols; // 2 = YES/NO, 3 = YES/NO/N/A, null = no header shown

    for (final item in s.activeItems) {
      final n = vm.numbers[item.id];
      final title = n == null ? item.name : '$n. ${item.name}';

      switch (item.kind) {
        case TobaccoItemKind.yesNo:
          final need = item.hasNa ? 3 : 2;
          if (cols != need) {
            rows.add(_answerHeader(need));
            cols = need;
          }
          final a = vm.answerValue(item.id);
          rows.add(_answerRow(title, a, need));
          if (a == TobaccoInspectionAnswerModel.no &&
              item.activeChildren.isNotEmpty) {
            rows.add(_checkList(vm, item, item.activeChildren));
            cols = null;
          }
          break;

        case TobaccoItemKind.checkboxes:
          rows.add(_questionRow(title));
          rows.add(_checkList(vm, item, item.activeChildren));
          cols = null;
          break;

        case TobaccoItemKind.text:
          rows.add(_questionRow(title, value: vm.textFor(item.id).trim()));
          cols = null;
          break;

        case TobaccoItemKind.productGroups:
          final groupCols =
              item.activeChildren.any((c) => c.hasNa) ? 3 : 2;
          // "24. Are any of the following products sold here? | YES | NO"
          rows.add(_answerRow(title, null, groupCols, headerLabels: true));
          for (final g in item.productGroups) {
            if (g.title.isNotEmpty) rows.add(_subSectionRow(g.title));
            for (final c in g.items) {
              final label =
                  c.itemLabel == null ? c.name : '${c.itemLabel}. ${c.name}';
              if (c.kind == TobaccoItemKind.text) {
                rows.add(_questionRow(label, value: vm.textFor(c.id).trim()));
              } else {
                rows.add(_answerRow(label, vm.answerValue(c.id), groupCols));
              }
            }
          }
          cols = null;
          break;
      }
    }
    return rows;
  }

  static List<String> _labels(int cols) =>
      cols == 3 ? const ['YES', 'NO', 'N/A'] : const ['YES', 'NO'];

  static Map<int, pw.TableColumnWidth> _widths(int cols) => {
        0: const pw.FlexColumnWidth(),
        for (var i = 1; i <= cols; i++) i: const pw.FixedColumnWidth(_checkCol),
      };

  static const _tableBorder = pw.TableBorder(
    left: _side,
    right: _side,
    bottom: _side,
    verticalInside: _side,
  );

  /// Empty question cell + YES / NO (/ N/A).
  static pw.Widget _answerHeader(int cols) => pw.Table(
        border: _tableBorder,
        columnWidths: _widths(cols),
        children: [
          pw.TableRow(children: [
            pw.SizedBox(height: _rowH),
            for (final l in _labels(cols))
              pw.Container(
                height: _rowH,
                alignment: pw.Alignment.center,
                child: pw.Text(l, style: _text(size: 6.5)),
              ),
          ]),
        ],
      );

  /// Question + check columns. [headerLabels] prints YES / NO in the
  /// columns instead of checks (product question header).
  static pw.Widget _answerRow(String text, String? answer, int cols,
      {bool headerLabels = false}) {
    final values = cols == 3
        ? const [
            TobaccoInspectionAnswerModel.yes,
            TobaccoInspectionAnswerModel.no,
            TobaccoInspectionAnswerModel.na,
          ]
        : const [TobaccoInspectionAnswerModel.yes, TobaccoInspectionAnswerModel.no];
    final labels = _labels(cols);

    return pw.Table(
      border: _tableBorder,
      columnWidths: _widths(cols),
      children: [
        pw.TableRow(
          verticalAlignment: pw.TableCellVerticalAlignment.full,
          children: [
            pw.Container(
              constraints: const pw.BoxConstraints(minHeight: _rowH),
              padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(text, style: _text(size: _fsItem)),
            ),
            for (var i = 0; i < cols; i++)
              pw.Container(
                alignment: pw.Alignment.center,
                child: headerLabels
                    ? pw.Text(labels[i], style: _text(size: 6.5))
                    : (answer == values[i] ? _check() : null),
              ),
          ],
        ),
      ],
    );
  }

  /// Full-width question line (checkbox questions, text questions).
  static pw.Widget _questionRow(String text, {String? value}) => pw.Container(
        constraints: const pw.BoxConstraints(minHeight: _rowH),
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        alignment: pw.Alignment.centerLeft,
        decoration: const pw.BoxDecoration(border: _rowBorder),
        child: pw.RichText(
          text: pw.TextSpan(children: [
            pw.TextSpan(text: text, style: _text(size: _fsItem)),
            if (value != null && value.isNotEmpty)
              pw.TextSpan(text: '  $value', style: _text(size: _fsItem, bold: true)),
          ]),
        ),
      );

  /// Centered product sub-section name ("Cigarettes", "Vape Products").
  static pw.Widget _subSectionRow(String title) => pw.Container(
        height: _rowH,
        alignment: pw.Alignment.center,
        decoration: const pw.BoxDecoration(border: _rowBorder),
        child: pw.Text(title, style: _text(size: _fsItem)),
      );

  /// Vertical list of ☐ / ☑ options inside one bordered box.
  static pw.Widget _checkList(TobaccoInspectionViewModel vm,
      TobaccoItemModel parent, List<TobaccoItemModel> options) {
    final other = vm.textFor(parent.id).trim();
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(22, 3, 6, 4),
      decoration: const pw.BoxDecoration(border: _rowBorder),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (final o in options)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 1.6),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  _checkbox(vm.isOptionSelected(parent.id, o.id)),
                  pw.SizedBox(width: 4),
                  pw.Expanded(
                    child: pw.Text(
                      o.isOtherOption &&
                              vm.isOptionSelected(parent.id, o.id) &&
                              other.isNotEmpty
                          ? '${o.name} $other'
                          : o.name,
                      style: _text(size: _fsItem),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _checkbox(bool checked) => pw.Container(
        width: 9,
        height: 9,
        decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _black, width: 0.8)),
        child: checked ? pw.Center(child: _check(size: 8)) : null,
      );

  // -------------------------------------------------------------- final

  /// Date of Re-inspection | Purpose of Inspection / Operations Type
  /// Discussion with Person-in-Charge | Other Information
  static pw.Widget _finalTable(TobaccoInspectionViewModel vm) {
    final f = vm.finalSubmit;

    pw.Widget cell(String label, String value) => pw.Container(
          constraints: const pw.BoxConstraints(minHeight: 13),
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          alignment: pw.Alignment.topLeft,
          child: pw.RichText(
            text: pw.TextSpan(children: [
              pw.TextSpan(text: '$label: ', style: _text(bold: true)),
              pw.TextSpan(text: value, style: _text(bold: true)),
            ]),
          ),
        );

    return pw.Table(
      border: const pw.TableBorder(
        left: _side,
        right: _side,
        bottom: _side,
        verticalInside: _side,
        horizontalInside: _side,
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(1),
        1: pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(children: [
          cell('Date of Re-inspection', _date(f?.reinspectionDate)),
          pw.Row(children: [
            pw.Expanded(child: cell('Purpose of Inspection', _purpose(vm))),
            pw.Container(width: _line, height: 13, color: _black),
            pw.Expanded(
              child: cell('Operations Type', f?.operationTypeName ?? ''),
            ),
          ]),
        ]),
        pw.TableRow(
          verticalAlignment: pw.TableCellVerticalAlignment.full,
          children: [
            pw.Container(
              constraints: const pw.BoxConstraints(minHeight: 40),
              child: cell('Discussion with Person-in-Charge',
                  (f?.discussion ?? '').trim()),
            ),
            pw.Container(
              constraints: const pw.BoxConstraints(minHeight: 40),
              alignment: pw.Alignment.centerLeft,
              child: cell('Other Information',
                  (f?.otherInformation ?? '').trim()),
            ),
          ],
        ),
      ],
    );
  }

  // --------------------------------------------------------- signatures

  static pw.Widget _signatures({
    required String picName,
    required pw.MemoryImage? picSig,
    required String picDate,
    required String inspName,
    required pw.MemoryImage? inspSig,
    required String inspDate,
  }) {
    pw.Widget row(String label, String name, pw.MemoryImage? sig, String date,
            {required bool bottom}) =>
        pw.Container(
          height: 78,
          decoration: pw.BoxDecoration(
            border: pw.Border(bottom: bottom ? _side : pw.BorderSide.none),
          ),
          child: pw.Row(children: [
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.all(3),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(label, style: _text(bold: true)),
                    pw.SizedBox(height: 4),
                    if (sig != null)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 12),
                        child: pw.Image(sig,
                            width: 160,
                            height: 46,
                            fit: pw.BoxFit.contain,
                            alignment: pw.Alignment.centerLeft),
                      ),
                    pw.Spacer(),
                    if (name.isNotEmpty)
                      pw.Text('Name: $name', style: _text()),
                  ],
                ),
              ),
            ),
            pw.SizedBox(
              width: 103,
              child: pw.RichText(
                text: pw.TextSpan(children: [
                  pw.TextSpan(text: 'Date: ', style: _text(bold: true)),
                  pw.TextSpan(text: date, style: _text()),
                ]),
              ),
            ),
          ]),
        );

    return pw.Container(
      decoration:
          pw.BoxDecoration(border: pw.Border.all(color: _black, width: _line)),
      child: pw.Column(children: [
        row('Signature of Person-in-Charge:', picName, picSig, picDate,
            bottom: true),
        row('Signature of Inspector:', inspName, inspSig, inspDate,
            bottom: false),
      ]),
    );
  }
}
