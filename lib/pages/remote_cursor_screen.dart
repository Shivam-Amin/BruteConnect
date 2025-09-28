import 'package:brute_connect/Services/socket_client.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

class RemoteCursorScreen extends StatefulWidget {
  final String deviceName;
  final String deviceIp;
  final SocketClient socketClient;

  const RemoteCursorScreen({
    super.key,
    required this.deviceName,
    required this.deviceIp,
    required this.socketClient,
  });

  @override
  State<RemoteCursorScreen> createState() => _RemoteCursorScreenState();
}

class _RemoteCursorScreenState extends State<RemoteCursorScreen> {
  Offset? _lastPanPosition;
  bool _showFeedbackOverlay = false;
  String _feedbackText = '';
  bool _isScaling = false;
  int _pointerCount = 0;

  void _sendCursorCommand(Map<String, dynamic> command) {
    if (!widget.socketClient.isConnected) {
      _showConnectionError();
      return;
    }

    try {
      final message = json.encode({
        ...command,
        "timestamp": DateTime.now().millisecondsSinceEpoch
      });
      
      widget.socketClient.sendMessage(message);
    } catch (e) {
      _showError('Failed to send cursor command');
    }
  }

  void _handleTap() {
    _sendCursorCommand({
      "type": "cursor",
      "action": "left_click"
    });
    _showFeedback('Left Click');
  }

  void _handleTwoFingerTap() {
    _sendCursorCommand({
      "type": "cursor", 
      "action": "right_click"
    });
    _showFeedback('Right Click');
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _lastPanPosition = details.localFocalPoint;
    _pointerCount = details.pointerCount;
    _isScaling = false;
    
    // Detect two-finger tap
    if (details.pointerCount == 2) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!_isScaling && _pointerCount == 2) {
          _handleTwoFingerTap();
        }
      });
    }
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (_lastPanPosition == null) return;
    
    _isScaling = true; // Mark that we're in a scaling/dragging gesture
    
    if (details.pointerCount == 1) {
      // Single finger - cursor movement
      final deltaX = (details.localFocalPoint.dx - _lastPanPosition!.dx).round();
      final deltaY = (details.localFocalPoint.dy - _lastPanPosition!.dy).round();
      
      if (deltaX.abs() > 1 || deltaY.abs() > 1) {
        _sendCursorCommand({
          "type": "cursor",
          "action": "move",
          "deltaX": deltaX,
          "deltaY": deltaY
        });
        
        _lastPanPosition = details.localFocalPoint;
      }
    } else if (details.pointerCount == 2) {
      // Two fingers - scrolling
      final deltaY = (details.localFocalPoint.dy - _lastPanPosition!.dy).round();
      
      if (deltaY.abs() > 5) {
        final direction = deltaY > 0 ? "down" : "up";
        final delta = (deltaY.abs() * 2).clamp(20, 200);
        
        _sendCursorCommand({
          "type": "cursor",
          "action": "scroll",
          "direction": direction,
          "delta": delta
        });
        
        _lastPanPosition = details.localFocalPoint;
      }
    }
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    _lastPanPosition = null;
    _isScaling = false;
    _pointerCount = 0;
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showFeedback(String action) {
    setState(() {
      _showFeedbackOverlay = true;
      _feedbackText = action;
    });
    
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _showFeedbackOverlay = false;
        });
      }
    });
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
              widget.socketClient.isConnected ? 'Remote Cursor Active' : 'Disconnected',
              style: TextStyle(
                fontSize: 15,
                color: widget.socketClient.isConnected ? Colors.green : Colors.red,
              ),
            )
          ],
        ),
      ),
      body: Stack(
        children: [
          // Main touch area
          GestureDetector(
            onTap: _handleTap,
            onScaleStart: _handleScaleStart,
            onScaleUpdate: _handleScaleUpdate,
            onScaleEnd: _handleScaleEnd,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black12,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.touch_app,
                      size: 64,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Remote Cursor Control',
                      style: TextStyle(
                        fontSize: 24,
                        color: Colors.grey,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    SizedBox(height: 32),
                    Text(
                      '• Single tap: Left click\n• Two finger tap: Right click\n• Drag: Move cursor\n• Two finger drag: Scroll',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          

          
          // Feedback overlay
          if (_showFeedbackOverlay)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _feedbackText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}