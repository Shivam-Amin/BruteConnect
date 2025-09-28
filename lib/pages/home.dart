import 'package:brute_connect/Services/file_sharing.dart';
import 'package:brute_connect/Services/socket_client.dart';
import 'package:brute_connect/pages/presentation_mode_screen.dart';
import 'package:brute_connect/pages/remote_cursor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Home extends StatefulWidget {
  final String deviceName;
  final String deviceIp;
  final int deviceSocketPort;
  const Home({super.key, required this.deviceName, required this.deviceIp, required, required this.deviceSocketPort});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  static final socketClient = SocketClient();
  String _statusMessage = "Default Text...";
  final double squareSize = 60;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      await socketClient.connect(widget.deviceIp, widget.deviceSocketPort);
      setState(() {
        _statusMessage = 'Socket Connected!!';
      });
      socketClient.sendMessage('Hello, Something.////////////////////////');
    } on PlatformException catch (e) {
      setState(() {
        _statusMessage = 'Failed to connect to device: ${e.message}';
      });
    }
  }

  @override
  void dispose() {
    socketClient.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          backgroundColor: const Color.fromARGB(48, 26, 26, 26),
          titleSpacing: 0,
          title: Column(
            children: [
              Text(
                widget.deviceName,
                style: TextStyle(
                  fontSize: 18,
                ),
              ),
              Text (
                _statusMessage,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black45
                ),
              )
            ],
          )
      ),
      body: Column(
        children: [
          // Top row
          Expanded(
            child: Row(
              children: [
                // Top-left
                FeatureTile(
                  icon: Icons.present_to_all,
                  label: 'Presentation\n remote',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PresentationModeScreen(
                        deviceName: widget.deviceName,
                        deviceIp: widget.deviceIp,
                        socketClient: socketClient,
                      ),
                    ),
                  ),
                ),
                // Top-right
                FeatureTile(
                  icon: Icons.insert_drive_file,
                  label: 'Send files',
                  // onTap: () => print('Send files tapped'),
                  onTap: () => selectFile(socketClient),
                ),
              ],
            ),
          ),
          // Bottom row
          Expanded(
            child: Row(
              children: [
                // Bottom-left
                FeatureTile(
                  icon: Icons.touch_app,
                  label: 'Remote input',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RemoteCursorScreen(
                        deviceName: widget.deviceName,
                        deviceIp: widget.deviceIp,
                        socketClient: socketClient,
                      ),
                    ),
                  ),
                ),
                //Bottom-right
                FeatureTile(
                  icon: Icons.code,
                  label: 'Run Command',
                  onTap: () => print('Run command tapped'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// class CornerBox extends StatelessWidget {
//   final Color color;
//
//   const CornerBox({super.key, required this.color});
//
//   @override
//   Widget build(BuildContext context) {
//     return Expanded(
//       child: Container(
//         margin: const EdgeInsets.all(2),
//         decoration: BoxDecoration(
//           color: color,
//           borderRadius: BorderRadius.circular(15), // Rounded all corners
//         ),
//       ),
//     );
//   }
// }

class FeatureTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const FeatureTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Material(
            color: Colors.grey.shade700,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              // splashColor: Colors.white24,
              // highlightColor: Colors.white10,
              child: Container(
                // Ensures full size for ripple effect
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(icon, color: Colors.white, size: 28),
                    const SizedBox(height: 12),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
    );
  }
}