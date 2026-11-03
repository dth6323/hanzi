import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/db_bridge.dart';
import '../data/http_post_stub.dart'
    if (dart.library.io) '../data/http_post_io.dart'
    if (dart.library.html) '../data/http_post_web.dart';
import 'ocr_web_stub.dart'
    if (dart.library.html) 'ocr_web_impl.dart';

export 'ocr_web_stub.dart' show OcrCaptureResult;

/// Cross-platform Chinese OCR service:
/// - Android: Google ML Kit Chinese Text Recognition V2 (Offline)
/// - iOS Native: Apple Vision VNRecognizeTextRequest zh-Hans/zh-Hant (Offline)
/// - iOS/Android Web PWA: Native HTML5 Camera capture (`capture="environment"`) + Tesseract.js
/// - Linux Desktop preview: Screen region snipping (`slurp`+`grim`) & image upload
class OcrService {
  OcrService._();
  static final OcrService instance = OcrService._();

  static const _channel = MethodChannel('com.hadz.hanzi_app/ocr');

  Future<OcrCaptureResult?> scanFromCamera() async {
    if (kIsWeb) {
      return pickWebImageAndOcr(useCamera: true);
    }
    if (useHttpBridge) {
      return captureScreenRegion();
    }
    final res = await _channel.invokeMapMethod<String, dynamic>('scanCamera');
    if (res == null) return null;
    return OcrCaptureResult(
      text: (res['text'] as String?) ?? '',
      imageBytes: res['image'] as Uint8List?,
    );
  }

  Future<OcrCaptureResult?> scanFromGallery() async {
    if (kIsWeb || useHttpBridge) {
      return pickWebImageAndOcr(useCamera: false);
    }
    final res = await _channel.invokeMapMethod<String, dynamic>('scanGallery');
    if (res == null) return null;
    return OcrCaptureResult(
      text: (res['text'] as String?) ?? '',
      imageBytes: res['image'] as Uint8List?,
    );
  }

  /// Captures a rectangular region of the Linux desktop screen via the local bridge.
  Future<OcrCaptureResult?> captureScreenRegion() async {
    final resp = await postJson('http://127.0.0.1:43821/screenshot', '{}');
    final map = jsonDecode(resp) as Map<String, dynamic>;
    if (map['error'] != null) {
      throw Exception(map['error']);
    }
    final b64 = map['image_base64'] as String?;
    if (b64 == null || b64.isEmpty) return null;
    final bytes = base64Decode(b64);
    final ocr = await runBrowserOcrOnBytes(bytes);
    return ocr ?? OcrCaptureResult(text: '', imageBytes: bytes);
  }
}
