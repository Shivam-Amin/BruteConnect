// import 'dart:convert';
// import 'dart:io';

// import 'package:brute_connect/Services/utils/fileMetaData.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:path_provider/path_provider.dart';

// class SocketServer {
//   ServerSocket? _serverSocket;
//   int? _port;

//   /// Starts the socket server on a free port and returns the port.
//   Future<int?> start() async {
//     try {
//       // Try binding to a free port by passing port 0
//       _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
//       _port = _serverSocket!.port;

//       print('🚀 Socket server started on port $_port');

//       // Handle incoming client connections
//       _serverSocket!.listen((Socket client) {
//           final remote = client.remoteAddress.address;
//           final port = client.remotePort;
//           debugPrint('🔌 Client connected from $remote:$port');
//           _handleClient(client);
//       },
//         onDone: () {
//           // debugPrint('❌ Server closed connection');
//           debugPrint('❌ ServerSocket Connection Finished!');
//           _serverSocket?.close();
//         },
//         onError: (e) {
//           debugPrint('⚠️ Server socket error: $e');
//         },
//         cancelOnError: true,
//       );

//       return _port;
//     } catch (e) {
//       debugPrint('🚫 Failed to start socket server: $e');
//       return null;
//     }
//   }

//   /// Handles data coming from a single client.
//   void _handleClient(Socket client) {
//     client.listen((data) async {
//       print('sldfjaldfjaldfjalsdjfklasjf---------------');
//       print(data);
//       final message = String.fromCharCodes(data);
//       print(message);
//       if (message.contains('<EOF>')) {
//         // Handle metadata
//         final metadataString = message.split('<EOF>').first;
//         final metadata = FileMetadata.fromJson(json.decode(metadataString));
        
//         // Prepare to receive file
//         final directory = await getApplicationDocumentsDirectory();
//         final file = File('${directory.path}/${metadata.name}');
//         final sink = file.openWrite();
        
//         // Send confirmation and start streaming
//         client.write('READY');
//         client.listen((data) {
//           if (String.fromCharCodes(data) == 'FILE_SENT') {
//             sink.close();
//             print('File saved to: ${file.path}');
//           } else {
//             sink.add(data);
//           }
//         });
//       }

//     });
//   }
  

//   /// Stops the socket server
//   Future<void> stop() async {
//     await _serverSocket?.close();
//     debugPrint('🛑 Socket server stopped');
//   }

//   int? get port => _port;
// }



import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:brute_connect/Services/utils/fileMetaData.dart';
import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';

class SocketServer {
  ServerSocket? _serverSocket;
  int? _port;
  
  // Track active file transfers per client
  final Map<Socket, _FileTransfer> _activeTransfers = {};

  /// Starts the socket server on a free port and returns the port.
  Future<int?> start() async {
    try {
      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
      _port = _serverSocket!.port;

      print('🚀 Socket server started on port $_port');

      _serverSocket!.listen((Socket client) {
          final remote = client.remoteAddress.address;
          final port = client.remotePort;
          debugPrint('🔌 Client connected from $remote:$port');
          _handleClient(client);
      },
        onDone: () {
          debugPrint('❌ ServerSocket Connection Finished!');
          _serverSocket?.close();
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

  /// Handles data coming from a single client
  void _handleClient(Socket client) {
    Uint8List buffer = Uint8List(0);

    client.listen((data) async {
      buffer = Uint8List.fromList(buffer + data);
      await _processBuffer(buffer, client);
    },
    onDone: () {
      debugPrint('❌ Client disconnected');
      _cleanupClient(client);
    },
    onError: (e) {
      debugPrint('⚠️ Client error: $e');
      _cleanupClient(client);
    });
  }

  /// Process accumulated buffer data
  Future<void> _processBuffer(Uint8List buffer, Socket client) async {
    var message = String.fromCharCodes(buffer);
    
    // Check for complete JSON messages (enclosed in braces)
    if (message.startsWith('{') && message.contains('}')) {
      var endIndex = message.indexOf('}') + 1;
      var jsonString = message.substring(0, endIndex);
      
      try {
        var jsonData = json.decode(jsonString);
        print('----JSONDATA: ${jsonData}');
        await _handleMessage(jsonData, client);
      } catch (e) {
        debugPrint('⚠️ Failed to parse JSON: $e');
      }
    }
  }

  /// Handle different message types
  Future<void> _handleMessage(Map<String, dynamic> message, Socket client) async {
    var type = message['type'] as String?;
    print('--------TYPE: ${type}');
    switch (type) {
      case 'message':
        _handleRegularMessage(message['data'] as String);
        break;
        
      case 'file_metadata':
        await _handleFileMetadata(message, client);
        break;
        
      case 'file_chunk':
        await _handleFileChunk(message, client);
        break;
        
      case 'file_end':
        await _handleFileEnd(message, client);
        break;
        
      default:
        debugPrint('⚠️ Unknown message type: $type');
    }
  }

  /// Handle regular text messages
  void _handleRegularMessage(String messageData) {
    debugPrint('💬 Received message: $messageData');
    // Add your message handling logic here
  }

  /// Handle file metadata
  Future<void> _handleFileMetadata(Map<String, dynamic> message, Socket client) async {
    try {
      final metadata = FileMetadata.fromJson(message['metadata']);
      debugPrint('📄 Received file metadata: ${metadata.name} (${metadata.size} bytes)');
      
      // Prepare file for writing
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/${metadata.name}');
      final sink = file.openWrite();
      
      // Store transfer info
      _activeTransfers[client] = _FileTransfer(
        metadata: metadata,
        file: file,
        sink: sink,
        bytesReceived: 0,
      );
      
      // Send ready signal
      final response = json.encode({
        'type': 'file_ready',
        'status': 'ready'
      });
      client.write(response);
      
    } catch (e) {
      debugPrint('⚠️ Failed to handle file metadata: $e');
    }
  }

  /// Handle file chunk data
  Future<void> _handleFileChunk(Map<String, dynamic> message, Socket client) async {
    final transfer = _activeTransfers[client];
    if (transfer == null) {
      debugPrint('⚠️ Received file chunk without metadata');
      return;
    }

    try {
      // Decode base64 chunk data
      final chunkData = message['data'] as String;
      final bytes = base64.decode(chunkData);
      
      transfer.sink.add(bytes);
      transfer.bytesReceived += bytes.length;
      
      debugPrint('📦 Received chunk: ${transfer.bytesReceived}/${transfer.metadata.size} bytes');
      
    } catch (e) {
      debugPrint('⚠️ Failed to handle file chunk: $e');
    }
  }

  /// Handle file transfer completion
  Future<void> _handleFileEnd(Map<String, dynamic> message, Socket client) async {
    final transfer = _activeTransfers[client];
    if (transfer == null) {
      debugPrint('⚠️ Received file end without active transfer');
      return;
    }

    try {
      await transfer.sink.close();
      debugPrint('✅ File saved successfully: ${transfer.metadata.name}');
      
      // Send completion acknowledgment
      final response = json.encode({
        'type': 'file_received',
        'status': 'success',
        'filename': transfer.metadata.name
      });
      client.write(response);
      
      // Clean up transfer
      _activeTransfers.remove(client);
      
    } catch (e) {
      debugPrint('⚠️ Failed to complete file transfer: $e');
    }
  }

  /// Clean up client resources
  void _cleanupClient(Socket client) {
    final transfer = _activeTransfers[client];
    if (transfer != null) {
      transfer.sink.close();
      _activeTransfers.remove(client);
    }
  }

  /// Stops the socket server
  Future<void> stop() async {
    // Clean up all active transfers
    for (final transfer in _activeTransfers.values) {
      await transfer.sink.close();
    }
    _activeTransfers.clear();
    
    await _serverSocket?.close();
    debugPrint('🛑 Socket server stopped');
  }

  int? get port => _port;
}

/// Helper class to track file transfer state
class _FileTransfer {
  final FileMetadata metadata;
  final File file;
  final IOSink sink;
  int bytesReceived;

  _FileTransfer({
    required this.metadata,
    required this.file,
    required this.sink,
    required this.bytesReceived,
  });
}