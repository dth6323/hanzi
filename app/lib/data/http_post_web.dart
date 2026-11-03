// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

Future<String> postJson(String url, String body) async {
  final req = await html.HttpRequest.request(
    url,
    method: 'POST',
    sendData: body,
    requestHeaders: {'Content-Type': 'application/json'},
  );
  return req.responseText ?? '{}';
}
