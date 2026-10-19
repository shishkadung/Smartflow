import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// One renderer for the screen and exported PNG, with four quiet modules.
class SfFlowQrPainter extends CustomPainter {
  SfFlowQrPainter(this.payload)
    : matrix = QrImage(
        QrCode.fromData(
          data: payload,
          errorCorrectLevel: QrErrorCorrectLevel.H,
        ),
      );
  final String payload;
  final QrImage matrix;

  @override
  void paint(Canvas canvas, Size size) {
    final n = matrix.moduleCount;
    final unit = math.min(size.width, size.height) / (n + 8);
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final ink = Paint()..color = const Color(0xFF122840);
    final blue = Paint()..color = const Color(0xFF1D4ED8);
    bool finder(int x, int y) =>
        (x < 7 && y < 7) || (x >= n - 7 && y < 7) || (x < 7 && y >= n - 7);
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        if (matrix.isDark(y, x) && !finder(x, y)) {
          canvas.drawCircle(
            Offset((x + 4.5) * unit, (y + 4.5) * unit),
            unit * .46,
            ink,
          );
        }
      }
    }
    for (final point in [
      const math.Point(0, 0),
      math.Point(n - 7, 0),
      math.Point(0, n - 7),
    ]) {
      final rect = Rect.fromLTWH(
        (point.x + 4) * unit,
        (point.y + 4) * unit,
        7 * unit,
        7 * unit,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(unit * 1.2)),
        blue,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.deflate(unit),
          Radius.circular(unit * .65),
        ),
        Paint()..color = Colors.white,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.deflate(2 * unit),
          Radius.circular(unit * .55),
        ),
        ink,
      );
    }
  }

  @override
  bool shouldRepaint(SfFlowQrPainter oldDelegate) =>
      oldDelegate.payload != payload;
}

/// Printable tracking QR shown after document registration.
class SfQrDisplay extends StatelessWidget {
  const SfQrDisplay({super.key, required this.payload, this.size = 220});

  final String payload;
  final double size;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(
          size,
          constraints.maxWidth.isFinite ? constraints.maxWidth : size,
        );
        return Center(
          child: Semantics(
            label: 'SmartFlow secured tracking QR',
            image: true,
            child: CustomPaint(
              size: Size.square(width),
              painter: SfFlowQrPainter(payload),
            ),
          ),
        );
      },
    );
  }
}
