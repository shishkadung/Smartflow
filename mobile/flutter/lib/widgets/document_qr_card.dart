import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'sf_qr_display.dart';

/// Digital QR export uses Android's file picker; no storage permission is needed.
class DocumentQrCard extends StatefulWidget {
  const DocumentQrCard({
    super.key,
    required this.id,
    required this.payload,
    this.showId = true,
  });
  final String id;
  final String payload;
  final bool showId;
  @override
  State<DocumentQrCard> createState() => _DocumentQrCardState();
}

class _DocumentQrCardState extends State<DocumentQrCard> {
  bool _saving = false;
  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // White quiet zone stays in the exported PNG, independent of screen styling.
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 600, 600),
        Paint()..color = Colors.white,
      );
      SfFlowQrPainter(widget.payload).paint(canvas, const Size(600, 600));
      final picture = recorder.endRecording();
      final image = await picture.toImage(600, 600);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      picture.dispose();
      if (bytes == null) throw StateError('Could not render QR image');
      final saved = await const MethodChannel('smartflow/qr_export')
          .invokeMethod<bool>('savePng', {
            'filename': '${widget.id}-QR.png',
            'bytes': bytes.buffer.asUint8List(),
          });
      if (mounted && saved == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR image saved for folder identification.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save QR image. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SfQrDisplay(payload: widget.payload),
      const SizedBox(height: 10),
      if (widget.showId) ...[
        Text(widget.id, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
      ],
      const Text(
        'Your QR stays with the document in SmartFlow. Printing is optional.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _saving ? null : _save,
        icon: const Icon(Icons.download_rounded),
        label: Text(_saving ? 'Saving…' : 'Download QR image'),
      ),
    ],
  );
}
