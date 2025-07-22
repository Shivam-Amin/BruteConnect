import 'dart:io';

import 'package:flutter/cupertino.dart';

class SocketServer {
  ServerSocket? _serverSocket;
  int? _port;

  /// Starts the socket server on a free port and returns the port.
  Future<int?> start() async {
    try {
      // Try binding to a free port by passing port 0
      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
      _port = _serverSocket!.port;

      print('🚀 Socket server started on port $_port');

      // Handle incoming client connections
      _serverSocket!.listen((Socket client) {
          final remote = client.remoteAddress.address;
          final port = client.remotePort;
          debugPrint('🔌 Client connected from $remote:$port');

          client.listen((data) {
              final message = String.fromCharCodes(data);
              debugPrint('📥 Received: $message');
              client.write('Echo: $message');
            },
            onDone: () {
              debugPrint('❌ Client disconnected: $remote:$port');
              client.close();
            },
            onError: (e) {
              debugPrint('⚠️ Client error: $e');
            },
          );
        },
        onError: (e) {
          debugPrint('⚠️ Server socket error: $e');
        },
        cancelOnError: true,
      );

      return _port;
    } catch (e) {
      debugPrint('🚫 Failed to start socket server: $e');
      return null;
    }
  }

  /// Stops the socket server
  Future<void> stop() async {
    await _serverSocket?.close();
    debugPrint('🛑 Socket server stopped');
  }

  int? get port => _port;
}