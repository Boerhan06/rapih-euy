import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'rust_engine_transport_interface.dart';

class WebEngineTransport implements PlatformEngineTransport {
  static const String _httpEndpoint = 'http://127.0.0.1:8787';
  int _requestId = 0;

  @override
  Future<bool> init() async {
    try {
      final resp = await http
          .get(Uri.parse('$_httpEndpoint/health'))
          .timeout(const Duration(seconds: 3));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<dynamic> callMethod(String method, [Map<String, dynamic>? params]) async {
    final id = 'web_${++_requestId}';
    final resp = await http
        .post(
          Uri.parse('$_httpEndpoint/rpc'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'id': id,
            'method': method,
            if (params != null) 'params': params,
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (resp.statusCode >= 400) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    if (json['error'] != null) {
      throw Exception(json['error']);
    }
    return json['result'];
  }

  @override
  void dispose() {}
}

PlatformEngineTransport createEngineTransport() => WebEngineTransport();
