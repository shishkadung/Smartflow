import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../widgets/sf_qr_display.dart';

/// The native print bridge deliberately disables scripts/network loads. Embed
/// the freshly issued label payload as a PNG, retaining its physical quiet zone.
Future<String> preparePrintableLabel(String html) async {
  final data = RegExp(
    r'<script type="application/json" id="qr-label-data">([\s\S]*?)</script>',
  ).firstMatch(html);
  if (data == null) {
    throw const FormatException('Printable label QR data is unavailable.');
  }
  final label = jsonDecode(data.group(1)!) as Map<String, dynamic>;
  final payload = label['payload'] as String;
  if (payload.isEmpty) {
    throw const FormatException('Printable label QR is empty.');
  }
  final recorder = ui.PictureRecorder();
  SfFlowQrPainter(payload).paint(Canvas(recorder), const Size(600, 600));
  final picture = recorder.endRecording();
  final image = await picture.toImage(600, 600);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  if (bytes == null) throw StateError('Could not prepare the printable QR.');
  final qr = RegExp(r'<div class="qr"[^>]*>[\s\S]*?</div>');
  if (!qr.hasMatch(html)) {
    throw const FormatException('Printable label QR container is unavailable.');
  }
  return html
      .replaceFirst(
        qr,
        '<div class="qr"><img alt="Secured QR code" style="width:100%;height:auto" src="data:image/png;base64,${base64Encode(bytes.buffer.asUint8List())}"></div>',
      )
      .replaceAll(RegExp(r'<script\b[^>]*>[\s\S]*?</script>'), '')
      .trimLeft();
}
