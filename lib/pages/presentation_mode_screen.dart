import 'package:brute_connect/Services/socket_client.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

class PresentationModeScreen extends StatefulWidget {
  final String deviceName;
  final String deviceIp;
  final SocketClient socketClient;

  const PresentationModeScreen({
    super.key,
    required this.deviceName,
    required this.deviceIp,
    required this.socketClient,
  });

  @override
  State<PresentationModeScreen> createState() => _PresentationModeScreenState();
}

class _PresentationModeScreenState extends State<PresentationModeScreen> {
  
  void _sendPresentationCommand(String action) {
    if (!widget.socketClient.isConnected) {
      _showConnectionError();
      return;
    }

    try {
      final message = json.encode({
        "type": "presentation",
        "action": action,
        "timestamp": DateTime.now().millisecondsSinceEpoch
      });
      
      widget.socketClient.sendMessage(message);
      // _showCommandSent(action);
    } catch (e) {
      _showError('Failed to send $action command');
    }
  }

  void _sendLeftCommand() {
    _sendPresentationCommand("left");
  }

  void _sendRightCommand() {
    _sendPresentationCommand("right");
  }

  void _showConnectionError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Not connected to device'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showCommandSent(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$action command sent'),
        backgroundColor: Colors.green,
        duration: const Duration(milliseconds: 800),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
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
              style: const TextStyle(
                fontSize: 18,
              ),
            ),
            Text(
              widget.socketClient.isConnected ? 'Connected' : 'Disconnected',
              style: TextStyle(
                fontSize: 15,
                color: widget.socketClient.isConnected ? Colors.green : Colors.red,
              ),
            )
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Left Button
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Material(
                  color: Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _sendLeftCommand,
                    child: Container(
                      height: double.infinity,
                      padding: const EdgeInsets.all(24),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 48,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Previous',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Right Button
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Material(
                  color: Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _sendRightCommand,
                    child: Container(
                      height: double.infinity,
                      padding: const EdgeInsets.all(24),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.arrow_forward,
                            color: Colors.white,
                            size: 48,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Next',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}