// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:js' as js;

Future<String>? webListenSpeech() {
  final completer = Completer<String>();
  final promise = js.context.callMethod('__hanziWebListen', []);
  promise.callMethod('then', [
    (dynamic res) {
      if (!completer.isCompleted) {
        completer.complete((res?.toString() ?? '').trim());
      }
    }
  ]);
  promise.callMethod('catch', [
    (dynamic err) {
      if (!completer.isCompleted) {
        completer.completeError(err?.toString() ?? 'Lỗi nhận diện giọng nói');
      }
    }
  ]);
  return completer.future;
}

void webStopSpeech() {
  try {
    js.context.callMethod('__hanziWebStopListen', []);
  } catch (_) {}
}
