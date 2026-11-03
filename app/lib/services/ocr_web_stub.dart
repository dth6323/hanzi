import 'dart:typed_data';

class OcrCaptureResult {
  final String text;
  final Uint8List? imageBytes;
  const OcrCaptureResult({required this.text, this.imageBytes});
}

Future<OcrCaptureResult?> pickWebImageAndOcr() async => null;

Future<OcrCaptureResult?> runBrowserOcrOnBytes(Uint8List bytes) async => null;
