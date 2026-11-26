abstract class PlatformEngineTransport {
  Future<bool> init();
  Future<dynamic> callMethod(String method, [Map<String, dynamic>? params]);
  void dispose() {}
}
