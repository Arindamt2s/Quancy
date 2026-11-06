import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:quincy/Inspections/MobileFood/Model/MobileFoodSectionModel.dart';

// =====================================================================
//  Mobile Food / Food Establishment Inspection Report (A4 PDF)
//  (title + wording from MobileFoodReportData.reportType)
//  Same layout as the web report: letterhead, establishment table,
//  checklist in two columns per section, official order, re-inspection,
//  signatures, temperature observations, violation comments and
//  inspection photos (grouped by item number).
// =====================================================================

/// What the inspector selected for one checklist item.
class ReportItemAnswer {
  final String? result; // OUT / IN / NO / NA
  final bool cos;
  final bool repeat;
  final String comment;

  /// Photos taken for this item (image file bytes)
  final List<Uint8List> photos;

  const ReportItemAnswer({
    this.result,
    this.cos = false,
    this.repeat = false,
    this.comment = '',
    this.photos = const [],
  });
}

class ReportTemperature {
  final String itemLocation;
  final String temperature;

  const ReportTemperature(this.itemLocation, this.temperature);
}

/// Which inspection the report is for. Sets the report title and the
/// establishment wording in the official order.
enum ReportType {
  mobileFood('Mobile Food Establishment', 'mobile food establishment'),
  food('Food Establishment', 'food establishment');

  const ReportType(this.establishment, this.establishmentLower);

  /// "Mobile Food Establishment" / "Food Establishment"
  final String establishment;
  final String establishmentLower;

  /// "Mobile Food Establishment Inspection Report"
  String get title => '$establishment Inspection Report';
}

/// Everything the report shows. All dates/times are already formatted.
class MobileFoodReportData {
  /// Mobile Food (default) or Food → title and wording of the report.
  final ReportType reportType;

  // Establishment
  final String businessName;
  final String address;
  final String telephone;
  final String permitNumber;
  final String applicant;
  final String personInCharge;
  final String inspector;
  final String date; // MM/dd/yyyy
  final String timeIn; // HH:mm:ss
  final String timeOut; // HH:mm:ss

  // Inspection form
  final List<ChecklistSectionNode> checklist;
  final Map<int, ReportItemAnswer> answers; // itemId → answer

  // Temperature observations
  final List<ReportTemperature> temperatures;

  // Final submit
  final String reinspectionDate; // MM-dd-yyyy
  final String discussion;
  final String operationType;
  final String inspectionType;
  final String otherInformation;
  final Uint8List? picSignature;
  final String picSignDate; // MM-dd-yyyy
  final Uint8List? inspectorSignature;
  final String inspectorSignDate; // MM-dd-yyyy

  const MobileFoodReportData({
    this.reportType = ReportType.mobileFood,
    required this.businessName,
    required this.address,
    required this.telephone,
    required this.permitNumber,
    required this.applicant,
    required this.personInCharge,
    required this.inspector,
    required this.date,
    required this.timeIn,
    required this.timeOut,
    required this.checklist,
    required this.answers,
    required this.temperatures,
    required this.reinspectionDate,
    required this.discussion,
    required this.operationType,
    required this.inspectionType,
    required this.otherInformation,
    this.picSignature,
    required this.picSignDate,
    this.inspectorSignature,
    required this.inspectorSignDate,
  });
}

class MobileFoodReportPdf {
  /// Letterhead (seal, City of Quincy, Department of Health, phone/fax).
  /// Add it to pubspec.yaml under flutter → assets.
  static const String headerAsset = 'assets/images/quincy_report_header.png';

  /// City seal / logo shown left of "City of Quincy" in the text letterhead.
  /// Add it to pubspec.yaml under flutter → assets (PNG, square works best).
  static const String logoAsset = 'assets/images/newlogo.png';
  static const double _logoSize = 62;

  static const _grey = PdfColor.fromInt(0xFFD9D9D9);
  static const _black = PdfColors.black;
  static const double _fs = 7.5; // normal text
  static const double _fsItem = 6.2; // checklist items
  static const double _line = 0.6; // border width
  static const double _checkCol = 17; // IN / OUT / NA / NO / COS / R
  static const double _numCol = 21;

  /// Items 1–29 = Foodborne Illness Risk Factors and interventions
  static const int _riskFactorLastItem = 29;

  static const _side = pw.BorderSide(color: _black, width: _line);

  /// Bold check mark (vector, so it is sharp at any zoom)
  static const _checkSvg =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
      '<path d="M1.5 13.4 L4.7 10.2 L9.3 14.7 L19.7 2.4 L22.7 5.2 '
      'L9.5 21 Z" fill="#000000"/></svg>';

  /// Official order text; [est] = "mobile food establishment" /
  /// "food establishment".
  static String _officialOrder(String est) =>
      'Based on an inspection today, the items marked "OUT" indicated '
      'violations of 105 CMR 590.000 and applicable sections of the 2013 FDA '
      'Food Code. This report, when signed below by a Board of Health member '
      'or its agent constitutes an order of the Board of Health. Failure to '
      'correct violations cited in this report may result in suspension or '
      'revocation of the $est permit and cessation of '
      '$est operations. If you are subject to a notice '
      'of suspension, revocation, or non-renewal pursuant to 105 CMR 590.000 '
      'you may request a hearing before the board of health in accordance '
      'with 105 CMR 590.015(B).';

  // ------------------------------------------------------------------

  static Future<Uint8List> build(MobileFoodReportData d) async {
    pw.MemoryImage? letterhead;
    try {
      final bytes = await rootBundle.load(headerAsset);
      letterhead = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      letterhead = null; // asset missing → text letterhead
    }

    pw.MemoryImage? logo;
    try {
      final bytes = await rootBundle.load(logoAsset);
      logo = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      logo = null; // asset missing → letterhead without logo
    }

    final doc = pw.Document(
      title: d.reportType.title,
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(34, 34, 34, 30),
        build: (context) => [
          _letterhead(letterhead, logo),
          pw.SizedBox(height: 6),
          pw.Text(
            '${d.reportType.title} - City/Town of Quincy',
            style: pw.TextStyle(font: pw.Font.timesBold(), fontSize: 12.5),
          ),
          pw.SizedBox(height: 4),
          _infoTable(d),
          _legend(),
          pw.SizedBox(height: 12),
          for (final s in d.checklist) ...[
            _sectionBar(_s(s.section.name)),
            pw.SizedBox(height: 4),
            _sectionColumns(s, d),
            pw.SizedBox(height: 10),
          ],
          _officialOrderText(d.reportType),
          pw.SizedBox(height: 10),
          _reinspectionTable(d),
          pw.SizedBox(height: 10),
          _operationTable(d),
          pw.SizedBox(height: 10),
          pw.Container(height: _line, color: _black),
          pw.SizedBox(height: 14),
          _signatures(d),
          pw.SizedBox(height: 12),
          _temperatureTable(d),
          pw.SizedBox(height: 12),
          _violationComments(d),
          ..._inspectionPhotos(d),
        ],
      ),
    );

    return doc.save();
  }

  // ---------------- Helpers ----------------

  /// Works for String and String? model fields alike.
  static String _s(Object? v) => v?.toString() ?? '';

  static pw.TextStyle _text({double size = _fs, bool bold = false}) =>
      pw.TextStyle(
        fontSize: size,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      );

  static pw.Widget _check() =>
      pw.SvgImage(svg: _checkSvg, width: 9.5, height: 9.5);

  // ---------------- Letterhead ----------------

  static pw.Widget _letterhead(pw.MemoryImage? image, pw.MemoryImage? logo) {
    if (image != null) {
      return pw.Center(child: pw.Image(image, width: 475));
    }
    final times = pw.Font.timesBold();
    final timesRegular = pw.Font.times();

    // Heading lines, centred between the logo and an equal-width spacer
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
          // Logo on the left of "City of Quincy"
          pw.SizedBox(
            width: _logoSize,
            height: _logoSize,
            child: logo == null
                ? null
                : pw.Image(logo, fit: pw.BoxFit.contain),
          ),
          pw.Expanded(child: heading),
          // Same width on the right keeps the heading centred on the page
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

  // ---------------- Establishment table ----------------

  static pw.Widget _cell(
    String text, {
    double height = 16,
    bool right = false,
    bool bottom = true,
    double? width,
  }) {
    return pw.Container(
      width: width,
      height: height,
      padding: const pw.EdgeInsets.symmetric(horizontal: 3),
      alignment: pw.Alignment.centerLeft,
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: bottom ? _side : pw.BorderSide.none,
          right: right ? _side : pw.BorderSide.none,
        ),
      ),
      child: pw.Text(text, style: _text(), maxLines: 2),
    );
  }

  static pw.Widget _countCell(String label, int value,
      {required double height, bool bottom = true}) {
    return pw.Container(
      height: height,
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: bottom ? _side : pw.BorderSide.none),
      ),
      child: pw.Row(children: [
        pw.Expanded(
          child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 3),
            child: pw.Text(label, style: _text()),
          ),
        ),
        pw.Container(
          width: 56,
          height: height,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _black, width: 1.8),
          ),
          child: pw.Text('$value', style: _text(size: 12, bold: true)),
        ),
      ]),
    );
  }

  static pw.Widget _infoTable(MobileFoodReportData d) {
    // Counts for items 1–29
    var violated = 0;
    var repeat = 0;
    for (final s in d.checklist) {
      for (final p in s.parts) {
        for (final i in p.items) {
          final serial = int.tryParse(_s(i.serialNumber));
          if (serial == null || serial > _riskFactorLastItem) continue;
          final a = d.answers[i.id];
          if (a?.result != 'OUT') continue;
          violated++;
          if (a!.repeat) repeat++;
        }
      }
    }

    const riskText = 'Foodborn Illness Risk Factors and\n'
        'interventions(Items 1 to 29):';

    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(color: _black, width: _line)),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Left: establishment details
          pw.Container(
            width: 315,
            decoration: const pw.BoxDecoration(
              border: pw.Border(right: _side),
            ),
            child: pw.Column(children: [
              _cell('Business: ${d.businessName}'),
              _cell('Address: ${d.address}'),
              pw.Row(children: [
                _cell('Telephone: ${d.telephone}',
                    height: 20, width: 157, right: true),
                pw.Expanded(
                    child: _cell('Permit No: ${d.permitNumber}', height: 20)),
              ]),
              _cell('Applicant: ${d.applicant}', height: 21),
              _cell('Person-in-charge: ${d.personInCharge}', height: 21),
              _cell('Inspector: ${d.inspector}', height: 21, bottom: false),
            ]),
          ),
          // Right: date, time, violation counts
          pw.Expanded(
            child: pw.Column(children: [
              _cell('Date: ${d.date}'),
              _cell('Time In. ${d.timeIn} Time Out. ${d.timeOut}'),
              _countCell(
                'Number of Violated Provision Related to\n$riskText',
                violated,
                height: 41,
              ),
              _countCell(
                'Number of Repeat Violations Related to\n$riskText',
                repeat,
                height: 42,
                bottom: false,
              ),
            ]),
          ),
        ],
      ),
    );
  }

  static pw.Widget _legend() {
    pw.TextSpan b(String t) =>
        pw.TextSpan(text: t, style: _text(bold: true));
    pw.TextSpan n(String t) => pw.TextSpan(text: t, style: _text());

    return pw.Container(
      height: 16,
      alignment: pw.Alignment.center,
      decoration: const pw.BoxDecoration(
        border: pw.Border(left: _side, right: _side, bottom: _side),
      ),
      child: pw.RichText(
        text: pw.TextSpan(children: [
          b('IN'), n(' = in compliance '),
          b('OUT'), n(' = out of compliance '),
          b('N/O'), n(' = not observed '),
          b('N/A'), n(' = not applicable '),
          b('COS'), n(' = corrected on site during inspection '),
          b('R'), n(' = repeat violation'),
        ]),
      ),
    );
  }

  // ---------------- Checklist ----------------

  static pw.Widget _sectionBar(String title) {
    return pw.Container(
      height: 14,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        color: _grey,
        border: pw.Border.all(color: _black, width: _line),
      ),
      child: pw.Text(title, style: _text()),
    );
  }

  /// Items split evenly: first half left, second half right.
  static pw.Widget _sectionColumns(
      ChecklistSectionNode section, MobileFoodReportData d) {
    final entries = <_Entry>[
      for (final p in section.parts)
        for (final i in p.items) _Entry(p, i),
    ];
    final half = (entries.length + 1) ~/ 2;
    final left = entries.sublist(0, half);
    final right = entries.sublist(half);

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(child: _checkColumn(left, d, continuingPart: null)),
        pw.SizedBox(width: 14),
        pw.Expanded(
          child: _checkColumn(
            right,
            d,
            // Part that continues from the left column has no new header
            continuingPart: left.isEmpty ? null : left.last.part.part.id,
          ),
        ),
      ],
    );
  }

  static const _checkWidths = {
    0: pw.FixedColumnWidth(_numCol),
    1: pw.FlexColumnWidth(),
    2: pw.FixedColumnWidth(_checkCol),
    3: pw.FixedColumnWidth(_checkCol),
    4: pw.FixedColumnWidth(_checkCol),
    5: pw.FixedColumnWidth(_checkCol),
    6: pw.FixedColumnWidth(_checkCol),
    7: pw.FixedColumnWidth(_checkCol),
  };

  static pw.Widget _checkColumn(
    List<_Entry> entries,
    MobileFoodReportData d, {
    required Object? continuingPart,
  }) {
    if (entries.isEmpty) return pw.SizedBox();

    final rows = <pw.Widget>[_columnHeader()];
    Object? lastPart = continuingPart;

    for (final e in entries) {
      final partId = e.part.part.id;
      if (partId != lastPart) {
        rows.add(_partHeader(_s(e.part.part.name)));
        lastPart = partId;
      }
      rows.add(_itemRow(e.item, d.answers[e.item.id]));
    }
    return pw.Column(children: rows);
  }

  static pw.Widget _columnHeader() {
    pw.Widget label(String t) => pw.Container(
          height: 17,
          alignment: pw.Alignment.center,
          child: pw.Text(t, style: _text(size: _fsItem)),
        );

    return pw.Table(
      border: pw.TableBorder.all(color: _black, width: _line),
      columnWidths: const {
        0: pw.FlexColumnWidth(),
        1: pw.FixedColumnWidth(_checkCol),
        2: pw.FixedColumnWidth(_checkCol),
        3: pw.FixedColumnWidth(_checkCol),
        4: pw.FixedColumnWidth(_checkCol),
        5: pw.FixedColumnWidth(_checkCol),
        6: pw.FixedColumnWidth(_checkCol),
      },
      children: [
        pw.TableRow(children: [
          pw.Container(
            height: 17,
            alignment: pw.Alignment.center,
            child: pw.Text('Compliance Status', style: _text()),
          ),
          label('IN'),
          label('OUT'),
          label('NA'),
          label('NO'),
          label('COS'),
          label('R'),
        ]),
      ],
    );
  }

  static pw.Widget _partHeader(String name) {
    return pw.Container(
      constraints: const pw.BoxConstraints(minHeight: 16),
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      alignment: pw.Alignment.center,
      decoration: const pw.BoxDecoration(
        color: _grey,
        border: pw.Border(left: _side, right: _side, bottom: _side),
      ),
      child: pw.Text(name,
          style: _text(bold: true), textAlign: pw.TextAlign.center),
    );
  }

  static pw.Widget _itemRow(MobileFoodItemModel item, ReportItemAnswer? a) {
    bool on(String code) {
      if (a == null) return false;
      switch (code) {
        case 'COS':
          return a.cos;
        case 'R':
          return a.repeat;
        default:
          return a.result == code;
      }
    }

    pw.Widget checkCell(String code) => pw.Container(
          alignment: pw.Alignment.center,
          child: on(code) ? _check() : null,
        );

    return pw.Table(
      border: const pw.TableBorder(
        left: _side,
        right: _side,
        bottom: _side,
        verticalInside: _side,
      ),
      columnWidths: _checkWidths,
      children: [
        pw.TableRow(
          verticalAlignment: pw.TableCellVerticalAlignment.full,
          children: [
            pw.Container(
              constraints: const pw.BoxConstraints(minHeight: 16.5),
              padding: const pw.EdgeInsets.only(left: 3),
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(_s(item.serialNumber),
                  style: _text(size: _fsItem)),
            ),
            pw.Container(
              constraints: const pw.BoxConstraints(minHeight: 16.5),
              padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(_s(item.name),
                  style: _text(size: _fsItem).copyWith(lineSpacing: 1.5)),
            ),
            // Same column order as the web report
            checkCell('IN'),
            checkCell('OUT'),
            checkCell('NA'),
            checkCell('NO'),
            checkCell('COS'),
            checkCell('R'),
          ],
        ),
      ],
    );
  }

  // ---------------- Official order / re-inspection ----------------

  static pw.Widget _officialOrderText(ReportType type) {
    return pw.RichText(
      textAlign: pw.TextAlign.justify,
      text: pw.TextSpan(
        style: _text().copyWith(lineSpacing: 3),
        children: [
          pw.TextSpan(
              text: 'Official Order for Correction: ',
              style: _text(bold: true)),
          pw.TextSpan(text: _officialOrder(type.establishmentLower)),
        ],
      ),
    );
  }

  static pw.Widget _reinspectionTable(MobileFoodReportData d) {
    pw.Widget cell(String label, String value) => pw.Padding(
          padding: const pw.EdgeInsets.all(3),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label, style: _text(bold: true)),
              pw.SizedBox(height: 2),
              pw.Text(value, style: _text(bold: true)),
            ],
          ),
        );

    return pw.Table(
      border: pw.TableBorder.all(color: _black, width: _line),
      columnWidths: const {
        0: pw.FixedColumnWidth(131),
        1: pw.FlexColumnWidth(),
      },
      children: [
        pw.TableRow(children: [
          cell('Date of Re-inspection:', d.reinspectionDate),
          cell('Discussion with Person-in-Charge:', d.discussion),
        ]),
      ],
    );
  }

  static pw.Widget _operationTable(MobileFoodReportData d) {
    pw.Widget cell(String text) => pw.Container(
          constraints: const pw.BoxConstraints(minHeight: 26),
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          alignment: pw.Alignment.centerLeft,
          child: pw.Text(text, style: _text(bold: true)),
        );

    return pw.Table(
      border: pw.TableBorder.all(color: _black, width: _line),
      columnWidths: const {
        0: pw.FixedColumnWidth(173),
        1: pw.FixedColumnWidth(176),
        2: pw.FlexColumnWidth(),
      },
      children: [
        pw.TableRow(
          verticalAlignment: pw.TableCellVerticalAlignment.full,
          children: [
            cell('Type of Operation(s): ${d.operationType}'),
            cell('Type of Inspection: ${d.inspectionType}'),
            cell('Other Information: ${d.otherInformation}'),
          ],
        ),
      ],
    );
  }

  // ---------------- Signatures ----------------

  static pw.Widget _signatureRow(
    String label,
    Uint8List? signature,
    String date, {
    required bool bottomBorder,
  }) {
    return pw.Container(
      height: 90,
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: bottomBorder ? _side : pw.BorderSide.none),
      ),
      child: pw.Row(children: [
        pw.Expanded(
          child: pw.Padding(
            padding: const pw.EdgeInsets.all(3),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(label, style: _text(bold: true)),
                pw.SizedBox(height: 6),
                if (signature != null)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 12),
                    child: pw.Image(
                      pw.MemoryImage(signature),
                      width: 160,
                      height: 58,
                      fit: pw.BoxFit.contain,
                      alignment: pw.Alignment.centerLeft,
                    ),
                  ),
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
  }

  static pw.Widget _signatures(MobileFoodReportData d) {
    return pw.Container(
      decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _black, width: _line)),
      child: pw.Column(children: [
        _signatureRow('Signature of Person-in-Charge:', d.picSignature,
            d.picSignDate,
            bottomBorder: true),
        _signatureRow('Signature of Inspector:', d.inspectorSignature,
            d.inspectorSignDate,
            bottomBorder: false),
      ]),
    );
  }

  // ---------------- Temperature observations ----------------

  static pw.Widget _titleBar(String title) => pw.Container(
        height: 13,
        alignment: pw.Alignment.center,
        decoration: const pw.BoxDecoration(
          color: _grey,
          border: pw.Border(bottom: _side),
        ),
        child: pw.Text(title, style: _text(bold: true)),
      );

  static pw.Widget _tempTable(List<ReportTemperature?> rows) {
    pw.Widget cell(String t, {bool bold = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: pw.Text(t,
              style: _text(bold: bold), textAlign: pw.TextAlign.center),
        );

    return pw.Table(
      border: pw.TableBorder.all(color: _black, width: _line),
      columnWidths: const {
        0: pw.FlexColumnWidth(166),
        1: pw.FlexColumnWidth(97),
      },
      children: [
        pw.TableRow(children: [
          cell('Item / Location', bold: true),
          cell('Temp (°F)', bold: true),
        ]),
        for (final r in rows)
          pw.TableRow(children: [
            cell(r?.itemLocation ?? ''),
            cell(r?.temperature ?? ''),
          ]),
      ],
    );
  }

  static pw.Widget _temperatureTable(MobileFoodReportData d) {
    // Alternate left / right like the web report
    final left = <ReportTemperature?>[];
    final right = <ReportTemperature?>[];
    for (var i = 0; i < d.temperatures.length; i++) {
      (i.isEven ? left : right).add(d.temperatures[i]);
    }
    while (right.length < left.length) {
      right.add(null);
    }

    return pw.Container(
      decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _black, width: _line)),
      child: pw.Column(children: [
        _titleBar('Temperature Observations'),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _tempTable(left)),
            pw.SizedBox(width: 2),
            pw.Expanded(child: _tempTable(right)),
          ],
        ),
      ]),
    );
  }

  // ---------------- Violation comments ----------------

  static pw.Widget _violationComments(MobileFoodReportData d) {
    // OUT items, in checklist order
    final list = <List<String>>[];
    for (final s in d.checklist) {
      for (final p in s.parts) {
        for (final i in p.items) {
          final a = d.answers[i.id];
          if (a?.result == 'OUT') list.add([_s(i.name), a!.comment.trim()]);
        }
      }
    }

    pw.Widget cell(List<String>? v) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: v == null
              ? pw.SizedBox()
              : pw.Column(children: [
                  pw.Text(v[0],
                      style: _text(), textAlign: pw.TextAlign.center),
                  pw.SizedBox(height: 8),
                  pw.Text(v[1],
                      style: _text(), textAlign: pw.TextAlign.center),
                ]),
        );

    return pw.Container(
      decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _black, width: _line)),
      child: pw.Column(children: [
        _titleBar('Violation comments'),
        if (list.isNotEmpty)
          pw.Table(
            border: const pw.TableBorder(
              verticalInside: _side,
              horizontalInside: _side,
            ),
            children: [
              for (var i = 0; i < list.length; i += 2)
                pw.TableRow(children: [
                  cell(list[i]),
                  cell(i + 1 < list.length ? list[i + 1] : null),
                ]),
            ],
          ),
      ]),
    );
  }

  // ---------------- Inspection photos ----------------

  /// One block per item that has photos, in checklist order:
  /// "Item 8: Hands clean & properly washed" + up to 4 photos.
  /// Each block is its own widget so long lists flow onto new pages.
  static List<pw.Widget> _inspectionPhotos(MobileFoodReportData d) {
    final blocks = <pw.Widget>[];

    for (final s in d.checklist) {
      for (final p in s.parts) {
        for (final i in p.items) {
          final photos = d.answers[i.id]?.photos ?? const <Uint8List>[];
          if (photos.isEmpty) continue;

          blocks.add(pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(6, 5, 6, 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(left: _side, right: _side, bottom: _side),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.RichText(
                  text: pw.TextSpan(children: [
                    pw.TextSpan(
                      text: 'Item ${_s(i.serialNumber)}: ',
                      style: _text(bold: true),
                    ),
                    pw.TextSpan(text: _s(i.name), style: _text()),
                  ]),
                ),
                pw.SizedBox(height: 5),
                pw.Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final bytes in photos)
                      pw.Container(
                        width: 122,
                        height: 92,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(
                              color: PdfColors.grey600, width: 0.5),
                        ),
                        child: pw.Image(
                          pw.MemoryImage(bytes),
                          fit: pw.BoxFit.cover,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ));
        }
      }
    }

    if (blocks.isEmpty) return const [];

    return [
      pw.SizedBox(height: 12),
      pw.Container(
        height: 13,
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
          color: _grey,
          border: pw.Border.all(color: _black, width: _line),
        ),
        child: pw.Text('Inspection Photos', style: _text(bold: true)),
      ),
      ...blocks,
    ];
  }
}

class _Entry {
  final ChecklistPartNode part;
  final MobileFoodItemModel item;

  _Entry(this.part, this.item);
}