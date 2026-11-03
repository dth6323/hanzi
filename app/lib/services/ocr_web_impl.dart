// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:typed_data';

import 'ocr_web_stub.dart';

export 'ocr_web_stub.dart' show OcrCaptureResult;

Future<OcrCaptureResult?> pickWebImageAndOcr() async {
  final completer = Completer<Uint8List?>();
  final input = html.FileUploadInputElement()..accept = 'image/*';
  input.onChange.listen((_) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      completer.complete(null);
      return;
    }
    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) {
      final res = reader.result;
      if (res is Uint8List) {
        completer.complete(res);
      } else if (res is ByteBuffer) {
        completer.complete(res.asUint8List());
      } else {
        completer.complete(null);
      }
    });
    reader.readAsArrayBuffer(files.first);
  });
  input.click();
  final bytes = await completer.future;
  if (bytes == null) return null;
  return runBrowserOcrOnBytes(bytes);
}

Future<OcrCaptureResult?> runBrowserOcrOnBytes(Uint8List bytes) async {
  final completer = Completer<String>();
  final dataUrl = 'data:image/png;base64,${base64Encode(bytes)}';

  js.context['__onHanziOcrDone'] = (String text) {
    if (!completer.isCompleted) completer.complete(text);
  };
  js.context['__onHanziOcrErr'] = (String err) {
    if (!completer.isCompleted) completer.complete('');
  };

  final script = html.ScriptElement()
    ..text = '''
      (async function() {
        try {
          if (!window.Tesseract) {
            await new Promise((resolve, reject) => {
              var s = document.createElement('script');
              s.src = 'https://cdn.jsdelivr.net/npm/tesseract.js@5/dist/tesseract.min.js';
              s.onload = resolve;
              s.onerror = reject;
              document.head.appendChild(s);
            });
          }
          var res = await window.Tesseract.recognize('$dataUrl', 'chi_sim+chi_tra');
          window.__onHanziOcrDone((res && res.data && res.data.text) ? res.data.text : '');
        } catch (e) {
          window.__onHanziOcrErr(String(e));
        }
      })();
    ''';
  html.document.body!.append(script);
  script.remove();

  final text = (await completer.future).trim();
  return OcrCaptureResult(text: text, imageBytes: bytes);
}
