// import 'dart:io';
// import 'dart:convert';

// import 'package:brute_connect/Services/utils/fileMetaData.dart';
// import 'package:flutter/cupertino.dart';

// class SocketClient {
//   late Socket _socket;
//   late File? fileToSend = null;

//   /// Connect to the server using IP and port
//   Future<void> connect(String ip, int port) async {
//     try {
//       _socket = await Socket.connect(ip, port);
//       debugPrint('✅ Connected to $ip:$port');

//       // Listen to incoming data
//       _socket.listen((data) {
//           final response = utf8.decode(data);
//           debugPrint('📥 Server says: $response');
//           if (response == 'READY') {
//             debugPrint('yooooO!!!!!');
//             sendFileChunks();
//           }
//         },
//         onDone: () {
//           // debugPrint('❌ Server closed connection');
//           debugPrint('❌ Connection Finished!');
//           _socket.destroy();
//         },
//         onError: (e) {
//           debugPrint('⚠️ Socket error: $e');
//           _socket.destroy();
//         },
//       );
//     } catch (e) {
//       debugPrint('❌ Failed to connect: $e');
//     }
//   }

//   Future<void> sendMessage(String msg) async {
//     _socket.writeln(jsonEncode({"type": "message", "data": msg}));
//   }

//   Future<void> sendFile(FileMetadata metaData, File file) async {
//     // Send metadata as JSON
//     fileToSend = file;
//     _socket.write(json.encode(metaData.toJson()) + '<EOF>'); // Using a delimiter
//     print('METAA DATA SENTT');

//     // Listen for server confirmation before sending file
//     // await _socket.firstWhere((data) => String.fromCharCodes(data) == 'READY');
//     // print('READDYYYYY');
    
//     // // Stream file contents
//     // await for (var chunk in file.openRead()) {
//     //   _socket.add(chunk);
//     // }

//     // // Send completion signal
//     // _socket.write('FILE_SENT');
//     // // await socket.close();
    
//     // print('File sent successfully!');
//   }

//   Future<void> sendFileChunks() async {
//     print('READDYYYYY');
    
//     // Stream file contents
//     await for (var chunk in fileToSend!.openRead()) {
//       _socket.add(chunk);
//     }

//     // Send completion signal
//     _socket.write('FILE_SENT');
//     // await socket.close();
    
//     print('File sent successfully!');
//   }

//   /// Close the socket connection
//   void disconnect() {
//     _socket.close();
//     debugPrint('🔌 Disconnected');
//   }

// }
import 'dart:io';
import 'dart:convert';

import 'package:brute_connect/Services/utils/fileMetaData.dart';
import 'package:flutter/cupertino.dart';

class SocketClient {
  Socket? _socket;
  bool _isConnected = false;
  File? fileToSend = null;

  /// Connect to the server using IP and port
  Future<void> connect(String ip, int port) async {
    try {
      _socket = await Socket.connect(ip, port);
      _isConnected = true;
      debugPrint('✅ Connected to $ip:$port');

      // Listen to incoming data
      _socket!.listen((data) {
          final response = utf8.decode(data);
          debugPrint('🔥 Server says: $response');
          
          // Handle server responses
          try {
            final jsonResponse = json.decode(response);
            _handleServerResponse(jsonResponse);
          } catch (e) {
            debugPrint('📝 Server message (non-JSON): $response');
          }
        },
        onDone: () {
          debugPrint('❌ Connection Finished!');
          _isConnected = false;
          _socket?.destroy();
        },
        onError: (e) {
          debugPrint('⚠️ Socket error: $e');
          _isConnected = false;
          _socket?.destroy();
        },
      );
    } catch (e) {
      debugPrint('❌ Failed to connect: $e');
      _isConnected = false;
    }
  }

  /// Handle different responses from server
  void _handleServerResponse(Map<String, dynamic> response) {
    final type = response['type'] as String?;
    
    switch (type) {
      case 'file_ready':
        debugPrint('🟢 Server ready to receive file');
        // File sending will be handled externally when this response is received
        _sendFileChunks(fileToSend);
        break;
        
      case 'file_received':
        debugPrint('✅ File received by server successfully: ${response['filename']}');
        break;
        
      default:
        debugPrint('📝 Server response: $response');
        break;
    }
  }

  /// Send a regular text message
  Future<void> sendMessage(String msg) async {
    if (!_isConnected || _socket == null) {
      debugPrint('⚠️ Cannot send message: Not connected');
      return;
    }

    final message = json.encode({
      "type": "message",
      "data": msg,
      "timestamp": DateTime.now().millisecondsSinceEpoch
    });
    
    _socket!.write(message);
    debugPrint('📤 Sent message: $msg');
  }

  /// Send file metadata and then send file chunks
  Future<void> sendFile(FileMetadata metaData, File file) async {
    if (!_isConnected || _socket == null) {
      debugPrint('⚠️ Cannot send file: Not connected');
      return;
    }

    try {
      // 1. Send file metadata
      final metadataMessage = json.encode({
        "type": "file_metadata",
        "metadata": metaData.toJson(),
        "timestamp": DateTime.now().millisecondsSinceEpoch
      });
      
      _socket!.write(metadataMessage);
      fileToSend = file;
      debugPrint('📤 Sent file metadata: ${metaData.name} (${metaData.size} bytes)');
      
      // 2. Wait for server ready signal and then send file
      // _socket!.listen((data) {
      //   final response = utf8.decode(data);
      //   try {
      //     final jsonResponse = json.decode(response);
      //     if (jsonResponse['type'] == 'file_ready') {
      //       _sendFileChunks(file);
      //     }
      //   } catch (e) {
      //     // Ignore non-JSON responses for now
      //   }
      // });
      
    } catch (e) {
      debugPrint('⚠️ Failed to send file metadata: $e');
    }
  }

  /// Send file in chunks using message protocol
  Future<void> _sendFileChunks(File? file) async {
    if (!_isConnected || _socket == null) {
      debugPrint('⚠️ Cannot send file chunks: Not connected');
      return;
    }

    try {
      final fileToSend = this.fileToSend;
      if (fileToSend != null) {
        debugPrint('📤 Starting file transfer...');
        
        const int chunkSize = 8192; // 8KB chunks
        final fileStream = fileToSend.openRead();
        
        await for (var chunk in fileStream) {
          // Encode chunk as base64 for JSON transmission
          final base64Chunk = base64.encode(chunk);
          
          final chunkMessage = json.encode({
            "type": "file_chunk",
            "data": base64Chunk,
            "size": chunk.length,
            "timestamp": DateTime.now().millisecondsSinceEpoch
          });
          
          _socket!.write(chunkMessage);
          
          // Small delay to prevent overwhelming the receiver
          await Future.delayed(Duration(milliseconds: 1));
        }

        // Send completion signal
        final endMessage = json.encode({
          "type": "file_end",
          "timestamp": DateTime.now().millisecondsSinceEpoch
        });
        
        _socket!.write(endMessage);
        debugPrint('✅ File chunks sent successfully!');
      } else {
        debugPrint('📤 No file to transfer...');
      }
      
    } catch (e) {
      debugPrint('⚠️ Failed to send file: $e');
    }
  }

  /// Check if client is connected
  bool get isConnected => _isConnected;

  /// Close the socket connection
  void disconnect() {
    if (_socket != null) {
      _socket!.close();
      _isConnected = false;
      debugPrint('🔌 Disconnected');
    }
  }
}