import 'dart:convert';
import 'dart:io';

Future<String> postJson(String url, String body) async {
  final client = HttpClient();
  final req = await client.postUrl(Uri.parse(url));
  req.headers.contentType = ContentType.json;
  req.write(body);
  final res = await req.close();
  return await utf8.decodeStream(res);
}
