import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'rust_engine_transport_interface.dart';

class IoEngineTransport implements PlatformEngineTransport {
  static const String _httpEndpoint = 'http://127.0.0.1:8787';

  Process? _process;
  int _requestId = 0;
  final Map<String, Completer<dynamic>> _pendingRequests = {};
  bool _httpAvailable = false;

  String? get _enginePath {
    final candidates = [
      'rapih_engine.exe',
      '../rapih_engine/target/release/rapih_engine.exe',
      '../rapih_engine/target/debug/rapih_engine.exe',
      '../rapih_engine/target/x86_64-pc-windows-gnu/release/rapih_engine.exe',
      '../rapih_engine/target/x86_64-pc-windows-gnu/debug/rapih_engine.exe',
      'target/release/rapih_engine.exe',
      'target/debug/rapih_engine.exe',
    ];

    for (final c in candidates) {
      if (File(c).existsSync()) {
        return c;
      }
    }
    return null;
  }

  @override
  Future<bool> init() async {
    final path = _enginePath;
    if (path != null) {
      try {
        _process = await Process.start(path, []);
        _process!.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(_handleStdoutLine);

        _process!.stderr
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((_) {});

        // Verify live ping
        await callMethod('ping');
        return true;
      } catch (_) {
        _process = null;
      }
    }

    // Fallback: check if HTTP daemon is running locally
    try {
      final resp = await http
          .get(Uri.parse('$_httpEndpoint/health'))
          .timeout(const Duration(seconds: 2));
      if (resp.statusCode == 200) {
        _httpAvailable = true;
        return true;
      }
    } catch (_) {}

    return false;
  }

  void _handleStdoutLine(String line) {
    if (line.trim().isEmpty) return;
    try {
      final json = jsonDecode(line) as Map<String, dynamic>;
      final id = json['id'] as String?;
      if (id != null && _pendingRequests.containsKey(id)) {
        final completer = _pendingRequests.remove(id)!;
        if (json['error'] != null) {
          completer.completeError(json['error']);
        } else {
          completer.complete(json['result']);
        }
      }
    } catch (_) {}
  }

  @override
  Future<dynamic> callMethod(String method, [Map<String, dynamic>? params]) async {
    if (_process != null) {
      final id = 'req_${++_requestId}';
      final completer = Completer<dynamic>();
      _pendingRequests[id] = completer;

      final payload = {
        'id': id,
        'method': method,
        if (params != null) 'params': params,
      };

      _process!.stdin.writeln(jsonEncode(payload));
      await _process!.stdin.flush();

      return completer.future.timeout(const Duration(seconds: 60), onTimeout: () {
        _pendingRequests.remove(id);
        throw TimeoutException('Request to Rust engine timed out');
      });
    }

    if (_httpAvailable) {
      return _callHttp(method, params);
    }

    final engineBinary = _enginePath;
    if (engineBinary != null) {
      final args = ['--cmd', method];
      if (params != null) {
        args.add(jsonEncode(params));
      }
      final result = await Process.run(engineBinary, args);
      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        final json = jsonDecode(output) as Map<String, dynamic>;
        if (json['success'] == true) {
          return json['data'];
        }
        throw Exception(json['message'] ?? 'Engine execution failed');
      }
      throw Exception(result.stderr.toString());
    }

    throw StateError('Rust engine binary not found');
  }

  Future<dynamic> _callHttp(String method, [Map<String, dynamic>? params]) async {
    final id = 'http_${++_requestId}';
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

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    if (json['error'] != null) {
      throw Exception(json['error']);
    }
    return json['result'];
  }

  @override
  void dispose() {
    _process?.kill();
    _process = null;
  }
}

PlatformEngineTransport createEngineTransport() => IoEngineTransport();
