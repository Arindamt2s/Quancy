import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:quincy/Inspections/Tobacco/View/widgets/TobaccoTheme.dart';

/// Signature box without extra packages.
///
/// Path: lib/Inspections/Tobacco/View/widgets/TobaccoSignaturePad.dart
///
/// * Shows the saved PNG ([savedFilePath]) with a "Clear" button.
/// * Otherwise lets the user draw; each finished stroke is exported as a
///   PNG and passed to [onSaved].
/// * [onDrawing] tells the parent to lock its scrolling while drawing.
class TobaccoSignaturePad extends StatefulWidget {
  const TobaccoSignaturePad({
    super.key,
    required this.label,
    required this.savedFilePath,
    required this.onSaved,
    required this.onCleared,
    this.onDrawing,
    this.height = 160,
  });

  final String label;
  final String? savedFilePath;
  final Future<void> Function(Uint8List png) onSaved;
  final Future<void> Function() onCleared;
  final ValueChanged<bool>? onDrawing;
  final double height;

  @override
  State<TobaccoSignaturePad> createState() => _TobaccoSignaturePadState();
}

class _TobaccoSignaturePadState extends State<TobaccoSignaturePad> {
  final List<List<Offset>> _strokes = [];
  Size _size = Size.zero;
  bool _exporting = false;

  bool get _hasSaved {
    final p = widget.savedFilePath;
    return p != null && File(p).existsSync();
  }

  void _start(Offset p) {
    widget.onDrawing?.call(true);
    setState(() => _strokes.add([p]));
  }

  void _move(Offset p) {
    if (_strokes.isEmpty) return;
    final inside = p.dx >= 0 && p.dy >= 0 && p.dx <= _size.width && p.dy <= _size.height;
    if (!inside) return;
    setState(() => _strokes.last.add(p));
  }

  Future<void> _end() async {
    widget.onDrawing?.call(false);
    if (_strokes.isEmpty || _exporting) return;
    _exporting = true;
    try {
      final png = await _toPng();
      if (png != null) await widget.onSaved(png);
    } finally {
      _exporting = false;
    }
  }

  Future<Uint8List?> _toPng() async {
    if (_size.isEmpty) return null;
    const scale = 2.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(scale);
    canvas.drawRect(Offset.zero & _size, Paint()..color = Colors.white);
    _SignaturePainter.paintStrokes(canvas, _strokes);
    final image = await recorder.endRecording().toImage(
        (_size.width * scale).round(), (_size.height * scale).round());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  Future<void> _clear() async {
    setState(() => _strokes.clear());
    await widget.onCleared();
  }

  @override
  Widget build(BuildContext context) {
    final showSaved = _hasSaved && _strokes.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(widget.label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13)),
            ),
            TextButton.icon(
              onPressed: (showSaved || _strokes.isNotEmpty) ? _clear : null,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Clear'),
            ),
          ],
        ),
        Container(
          height: widget.height,
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: TbColors.fieldBorder),
          ),
          child: showSaved
              ? Image.file(File(widget.savedFilePath!), fit: BoxFit.contain)
              : LayoutBuilder(builder: (context, c) {
                  _size = Size(c.maxWidth, c.maxHeight);
                  return Listener(
                    onPointerDown: (e) => _start(e.localPosition),
                    onPointerMove: (e) => _move(e.localPosition),
                    onPointerUp: (_) => _end(),
                    onPointerCancel: (_) => _end(),
                    child: Stack(
                      children: [
                        if (_strokes.isEmpty)
                          const Center(
                            child: Text('Sign here',
                                style: TextStyle(color: Colors.black26)),
                          ),
                        Positioned.fill(
                          child: CustomPaint(
                              painter: _SignaturePainter(_strokes)),
                        ),
                      ],
                    ),
                  );
                }),
        ),
        if (_exporting)
          const LinearProgressIndicator(minHeight: 2, color: TbColors.teal),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.strokes);
  final List<List<Offset>> strokes;

  static void paintStrokes(Canvas canvas, List<List<Offset>> strokes) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final s in strokes) {
      if (s.length == 1) {
        canvas.drawCircle(s.first, 1.4, paint..style = PaintingStyle.fill);
        paint.style = PaintingStyle.stroke;
        continue;
      }
      final path = Path()..moveTo(s.first.dx, s.first.dy);
      for (final p in s.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) => paintStrokes(canvas, strokes);

  @override
  bool shouldRepaint(covariant _SignaturePainter old) => true;
}
