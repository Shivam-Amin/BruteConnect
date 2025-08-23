// import 'dart:convert';
import 'dart:io';

import 'package:brute_connect/Services/socket_client.dart';
import 'package:file_picker/file_picker.dart';

// class FileSharing {
//   late final SocketClient socketClient;
//   FileSharing(SocketClient socketClient) {
//     this.socketClient = socketClient;
//   }
  
//   static Future<void> selectFile() async {
//     FilePickerResult? result = await FilePicker.platform.pickFiles(
//       type: FileType.any,
//       allowMultiple: false,
//     );
//     if (result != null) {
//       final filePath = result.files.single.path!;
//       final fileName = result.files.single.name;
//       final file = File(filePath);
//       final fileSize = await file.length();
//       // Handle the selected file path
//       print('Selected file: $filePath');

//       // 1. Send metadata
//       final meta = jsonEncode({
//         'type': 'file',
//         'name': fileName,
//         'size': fileSize,
//       });

//       socketClient.writeln(meta);

//     } else {
//       // User canceled the picker
//       print('No file selected');
//     }
//   }
// }


Future<void> selectFile(SocketClient socketClient) async {
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.any,
    allowMultiple: false,
  );
  if (result != null) {
    final filePath = result.files.single.path!;
    final fileName = result.files.single.name;
    final file = File(filePath);
    final fileSize = await file.length();
    // Handle the selected file path
    print('Selected file: $filePath');

    // 1. Send metadata
    final metaData = {
      'type': 'file',
      'name': fileName,
      'size': fileSize,
    };

    socketClient.sendFile(metaData, file);

  } else {
    // User canceled the picker
    print('No file selected');
  }
}