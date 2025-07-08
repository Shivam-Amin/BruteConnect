import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:brute_connect/pages/home.dart';

class DeviceDiscoveryScreen extends StatefulWidget {
  const DeviceDiscoveryScreen({super.key});

  @override
  State<DeviceDiscoveryScreen> createState() => _DeviceDiscoveryScreen();
}

class _DeviceDiscoveryScreen extends State<DeviceDiscoveryScreen> {
  static const platform = MethodChannel('com.example.brute_connect/mdns');

  final List<Map<String, dynamic>> _discoveredDevices = [];
  bool _isDiscovering = false;
  String _statusMessage = 'Starting service...';
  Timer? _discoveryTimer;
  final int _discoveryDuration = 10; // seconds to run discovery


  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          backgroundColor: const Color.fromARGB(48, 26, 26, 26),
          title: const Text('Brute Connect')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _statusMessage,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                _isDiscovering
                    ? ElevatedButton.icon(
                  onPressed: null,
                  icon: const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  label: const Text('Scanning...'),
                )
                    : ElevatedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Discover Devices'),
                ),
              ],
            ),
          ),
          Expanded(
            child:
            _discoveredDevices.isEmpty
                ? const Center(child: Text('No devices discovered yet'))
                : ListView.builder(
              itemCount: _discoveredDevices.length,
              itemBuilder: (context, index) {
                final device = _discoveredDevices[index];
                return ListTile(
                  title: Text(device['name'].toString()),
                  subtitle: Text(
                    'IP: ${device['address']} | Port: ${device['port']}',
                  ),
                  trailing: const Icon(Icons.devices),
                  onTap: () {
                    // We'll implement connection functionality in the next step
                    if (Platform.isAndroid || Platform.isIOS) {
                      final String deviceName = device['name']?.toString() ?? 'Unknown Device';
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => Home(deviceName: deviceName)),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Connecting to ${device['name']} will be implemented next',
                          ),
                        ),
                      );
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
