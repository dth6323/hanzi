// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;

Future<String> postJson(String url, String body) async {
  final isLocalhost = html.window.location.hostname == 'localhost' ||
      html.window.location.hostname == '127.0.0.1';

  // When running on localhost with python sqlite_bridge.py, try local bridge first
  if (isLocalhost) {
    try {
      final req = await html.HttpRequest.request(
        url,
        method: 'POST',
        sendData: body,
        requestHeaders: {'Content-Type': 'application/json'},
      );
      if (req.responseText != null && req.responseText!.isNotEmpty) {
        return req.responseText!;
      }
    } catch (_) {
      // Fallback to in-browser WASM SQLite / Web Speech below
    }
  }

  if (url.endsWith('/tts')) {
    final map = jsonDecode(body) as Map<String, dynamic>;
    final text = (map['text'] as String?) ?? '';
    final slow = map['slow'] == true;
    js.context.callMethod('__hanziWebSpeak', [text, slow]);
    return '{"ok":true}';
  }

  if (url.endsWith('/sql')) {
    final completer = Completer<String>();
    final promise = js.context.callMethod('__hanziExecSql', [body]);
    promise.callMethod('then', [
      (dynamic res) {
        if (!completer.isCompleted) completer.complete(res?.toString() ?? '{}');
      }
    ]);
    promise.callMethod('catch', [
      (dynamic err) {
        if (!completer.isCompleted) {
          completer.complete(jsonEncode({'error': err.toString()}));
        }
      }
    ]);
    return completer.future;
  }

  return '{"error":"Chức năng này chỉ hỗ trợ trên ứng dụng cài đặt"}';
}
