import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:bgn/distribusi/widgets/common/foto_bukti_widget.dart';

Future<String> applyWatermark(String imagePath, FotoBuktiData data) async {
  if (kIsWeb) return imagePath;
  final file = File(imagePath);
  final bytes = await file.readAsBytes();
  final codec = await ui.instantiateImageCodec(
    Uint8List.fromList(bytes),
    targetWidth: 1280,
  );
  final frame = await codec.getNextFrame();
  final original = frame.image;

  final w = original.width.toDouble();
  final h = original.height.toDouble();

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);

  canvas.drawImage(original, ui.Offset.zero, ui.Paint());

  // semi-transparent dark bar at the bottom
  final barH = h * 0.26;
  canvas.drawRect(
    ui.Rect.fromLTWH(0, h - barH, w, barH),
    ui.Paint()..color = const ui.Color(0xBB000000),
  );

  final pad = w / 35;
  final fontSizeLg = w / 30;
  final fontSizeSm = w / 38;
  final fontSizeXs = w / 42;
  double y = h - barH + pad * 0.3;

  // ── Row 1: date + jam (left/right) ──
  final r1Left = _makePara(data.tanggal, fontSizeLg, ui.FontWeight.w500, const ui.Color(0xFFFFFFFF));
  final r1Right = _makePara(data.jam, fontSizeLg, ui.FontWeight.w500, const ui.Color(0xFFFFFFFF));
  r1Left.layout(ui.ParagraphConstraints(width: w * 0.6));
  r1Right.layout(const ui.ParagraphConstraints(width: 9999));
  canvas.drawParagraph(r1Left, ui.Offset(pad, y));
  canvas.drawParagraph(r1Right, ui.Offset(w - pad - r1Right.width, y));
  y += r1Left.height + pad * 0.3;

  // ── Row 2: coordinates ──
  final coord = _formatCoord(data.latitude, data.longitude);
  final r2 = _makePara(coord, fontSizeXs, ui.FontWeight.normal, const ui.Color(0xCCFFFFFF));
  r2.layout(ui.ParagraphConstraints(width: w - pad * 2));
  canvas.drawParagraph(r2, ui.Offset(pad, y));
  y += r2.height + pad * 0.3;

  // ── Row 3: full address ──
  final r3 = _makePara(data.alamatLengkap, fontSizeSm, ui.FontWeight.normal, const ui.Color(0xFFFFFFFF));
  r3.layout(ui.ParagraphConstraints(width: w - pad * 2));
  canvas.drawParagraph(r3, ui.Offset(pad, y));
  y += r3.height + pad * 0.3;

  // ── Row 4: petugas + BGN badge ──
  final badgeW = w / 12;
  final badgeH = w / 24;
  final badgeY = y + pad * 0.05;

  final r4 = _makePara(data.petugas, fontSizeLg, ui.FontWeight.w500, const ui.Color(0xFFFFFFFF));
  r4.layout(ui.ParagraphConstraints(width: w - pad * 2 - badgeW - 8));
  canvas.drawParagraph(r4, ui.Offset(pad, y));

  // BGN badge background
  final badgeRect = ui.RRect.fromRectAndRadius(
    ui.Rect.fromLTWH(w - pad - badgeW, badgeY, badgeW, badgeH),
    const ui.Radius.circular(4),
  );
  canvas.drawRRect(badgeRect, ui.Paint()..color = const ui.Color(0xD91A7A34));

  // BGN badge text
  final badgeText = _makePara('BGN', fontSizeXs, ui.FontWeight.w700, const ui.Color(0xFFFFFFFF));
  badgeText.layout(ui.ParagraphConstraints(width: badgeW));
  canvas.drawParagraph(badgeText, ui.Offset(w - pad - badgeW, badgeY + 2));

  final picture = recorder.endRecording();
  final resultImage = await picture.toImage(original.width, original.height);
  final byteData = await resultImage.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) return imagePath;

  // Convert PNG ke JPEG supaya ukuran file kecil (server limit 10MB)
  final pngBytes = byteData.buffer.asUint8List();
  final decoded = img.decodeImage(pngBytes);
  if (decoded != null) {
    final jpegBytes = img.encodeJpg(decoded, quality: 85);
    await file.writeAsBytes(jpegBytes);
  } else {
    await file.writeAsBytes(pngBytes);
  }
  return imagePath;
}

ui.Paragraph _makePara(String text, double size, ui.FontWeight weight, ui.Color color) {
  final builder = ui.ParagraphBuilder(
    ui.ParagraphStyle(textDirection: ui.TextDirection.ltr, maxLines: 1, ellipsis: '...'),
  );
  builder.pushStyle(ui.TextStyle(color: color, fontSize: size, fontWeight: weight));
  builder.addText(text);
  return builder.build();
}

String _formatCoord(double lat, double lng) {
  final latDir = lat >= 0 ? 'S' : 'U';
  final lngDir = lng >= 0 ? 'T' : 'B';
  return '${lat.abs().toStringAsFixed(6)}$latDir  ${lng.abs().toStringAsFixed(6)}$lngDir';
}
