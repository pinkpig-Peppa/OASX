import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:oasx/api/api_client.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

part 'websocket_client.dart';

class WebSocketService extends GetxService {
  final Map<String, WebSocketClient> _clients = {};

  /// Builds a `ws://` or `wss://` endpoint URL from an HTTP/HTTPS/WS address.
  static String buildWsUrl(String rawAddress, String name) {
    final trimmed = rawAddress.trim();
    final withScheme = trimmed.isEmpty
        ? 'http://127.0.0.1:22288'
        : (trimmed.contains('://') ? trimmed : 'http://$trimmed');
    final parsed = Uri.parse(withScheme);
    final scheme =
        (parsed.scheme == 'https' || parsed.scheme == 'wss') ? 'wss' : 'ws';
    final segments = <String>[
      ...parsed.pathSegments.where((segment) => segment.isNotEmpty),
      'ws',
      name,
    ];
    return parsed.replace(scheme: scheme, pathSegments: segments).toString();
  }

  Future<WebSocketClient> connect({
    required String name,
    String? url,
    MessageListener? listener,
    bool force = false,
  }) async {
    final existing = _clients[name];
    if (!force &&
        existing != null &&
        existing.status.value == WsStatus.connected) {
      return existing._addListener(listener);
    }
    if (existing != null) {
      _clients.remove(name);
      await existing._close(
        WebSocketStatus.normalClosure,
        force ? 'force reconnect' : 'replace stale client',
      );
    }

    url ??= buildWsUrl(ApiClient().address, name);
    final client = WebSocketClient(name: name, url: url)._addListener(listener);
    _clients[name] = client;
    await client._connect();
    return client;
  }

  Future<void> send(String name, String message) async {
    final client = _clients[name];
    if (client != null) {
      await client.send(message);
    } else {
      printInfo(info: 'ws[$name] want to send, but not connected');
    }
  }

  Future<void> close(
    String name, {
    int code = WebSocketStatus.normalClosure,
    String reason = 'normal close',
    bool reconnect = false,
  }) async {
    final client = _clients.remove(name);
    if (client != null) {
      await client._close(code, reason, reconnect: reconnect);
    }
    printInfo(info: 'ws[$name] closed');
  }

  Future<void> closeAll() async {
    final clients = _clients.values.toList();
    _clients.clear();
    for (final client in clients) {
      await client._close(WebSocketStatus.normalClosure, 'global close');
    }
    printInfo(info: 'ws all closed');
  }

  void removeAllListeners(String name) {
    final client = _clients[name];
    if (client != null) {
      client._listeners.clear();
    }
    printInfo(info: 'ws[$name] listeners removed');
  }
}
