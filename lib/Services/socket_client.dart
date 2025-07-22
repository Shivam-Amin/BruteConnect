import 'dart:io';
import 'dart:convert';

import 'package:flutter/cupertino.dart';

class SocketClient {
  late Socket _socket;

  /// Connect to the server using IP and port
  Future<void> connect(String ip, int port) async {
    try {
      _socket = await Socket.connect(ip, port);
      debugPrint('✅ Connected to $ip:$port');

      // Listen to incoming data
      _socket.listen((data) {
          final response = utf8.decode(data);
          debugPrint('📥 Server says: $response');
        },
        onDone: () {
          // debugPrint('❌ Server closed connection');
          debugPrint('❌ Connection Finished!');
          _socket.destroy();
        },
        onError: (e) {
          debugPrint('⚠️ Socket error: $e');
          _socket.destroy();
        },
      );
    } catch (e) {
      debugPrint('❌ Failed to connect: $e');
    }
  }

  /// Send a message to the server
  void send(String message) {
    debugPrint('📤 Sending: $message');
    _socket.write(message);
  }

  /// Close the socket connection
  void disconnect() {
    _socket.close();
    debugPrint('🔌 Disconnected');
  }

}