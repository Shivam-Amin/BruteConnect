import 'dart:async';
import 'dart:io';

import 'package:brute_connect/Services/desktop_mdns_discovery.dart';
import 'package:brute_connect/Services/socket_server.dart';
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
  int SocketPort = 0;

  // Desktop mDNS discovery service
  late DesktopMDNSDiscovery _desktopMDNSDiscovery; // late caz, it'll get init. in initState()
  static final socketServer = SocketServer();


  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    setState(() {
      _statusMessage = "Starting Socket Server...";
    });

    await initSocketServer(); // ensure SocketPort is ready

    if (Platform.isAndroid || Platform.isIOS) {
      _isDiscovering = true;
      _setupMethodCallHandler();
      await _startBroadcastAndDiscovery(); // now safely passes the SocketPort
    } else {
      _setupDesktopDiscovery();
    }
  }

  void _setupMethodCallHandler() {
    platform.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onDevicesDiscovered':
          final List<dynamic> devices = call.arguments;
          setState(() {
            _discoveredDevices.clear();
            for (var device in devices) {
              _discoveredDevices.add(Map<String, dynamic>.from(device));
            }
          });
          break;
        case 'onServiceRegistered':

          _startDiscovery();
          break;
      }
    });
  }

  void _setupDesktopDiscovery() {
    _desktopMDNSDiscovery = DesktopMDNSDiscovery();

    // Initialize the desktop discovery service
    _desktopMDNSDiscovery!.initialize().then((_) {
      setState(() {
        _statusMessage = 'Ready to discover devices';
      });

      // Listen for device updates
      _desktopMDNSDiscovery!.devicesStream.listen((devices) {
        setState(() {
          _discoveredDevices.clear();
          for (var device in devices) {
            _discoveredDevices.add(device.toJson());
          }
        });
      });
    }).catchError((error) {
      setState(() {
        _statusMessage = 'Failed to initialize mDNS: $error';
      });
    });
  }

  Future<void> initSocketServer() async {
    SocketPort = (await socketServer.start())!;
  }

  Future<void> _startBroadcastAndDiscovery() async {
    setState(() {
      _statusMessage = 'Starting broadcast service...';
    });

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // Mobile platforms: use the platform channel
        // First start the broadcasting service
        await platform.invokeMethod('startBroadcast', SocketPort);
        setState(() {
          // _isBroadcasting = true;
          _statusMessage = 'Broadcast started, beginning discovery...';
        });

        // The start discovery for initial part will start when the service is registered,
        // from the onServiceRegister() method in android/app/src/main/java/com/example/brute_connect/MDNSService.java.
            // Add a small delay to ensure broadcast is properly started
            // await Future.delayed(const Duration(milliseconds: 500));

            // Then start discovery
            // _startDiscovery();
      }
    } on PlatformException catch (e) {
      setState(() {
        _statusMessage = 'Failed to start service: ${e.message}';
      });
    }
  }

  Future<void> _startDiscovery() async {
    // Cancel any existing timer
    _discoveryTimer?.cancel();

    setState(() {
      _statusMessage = 'Discovering devices...';
      _isDiscovering = true;
    });

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // Mobile platforms: use the platform channel
        await platform.invokeMethod('startDiscovery');
      } else {
        // Desktop platforms: use the Flutter mDNS discovery
        await _desktopMDNSDiscovery?.startDiscovery(duration: _discoveryDuration);
      }

      // Set timer to stop discovery after specified duration
      _discoveryTimer = Timer(Duration(seconds: _discoveryDuration), () {
        _stopDiscovery();
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to start discovery: $e';
        _isDiscovering = false;
      });
    }
  }

  Future<void> _stopDiscovery() async {
    _discoveryTimer?.cancel();

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // Mobile platforms: use the platform channel
        await platform.invokeMethod('stopDiscovery');
      } else {
        // Desktop platforms: use the Flutter mDNS discovery
        _desktopMDNSDiscovery?.stopDiscovery();
      }

      setState(() {
        _statusMessage = 'Discovery completed (${_discoveredDevices.length} devices found)';
        _isDiscovering = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to stop discovery: $e';
        _isDiscovering = false;
      });
    }
  }

  @override
  void dispose() {
    _discoveryTimer?.cancel();
    if (Platform.isAndroid || Platform.isIOS) {
      _stopDiscovery();
    } else {
      _desktopMDNSDiscovery?.dispose();
    }
    socketServer.stop();
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
                  onPressed: _startDiscovery,
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
                final String deviceName = device['deviceName']?.toString() ?? 'Unknown Device';
                final String deviceIp = device['deviceIp']?.toString() ?? 'Unknown IP';
                final String devicePort = device['devicePort']?.toString() ?? 'Unknown IP';
                final int deviceSocketPort = device['deviceSocketPort'] ?? -1;

                return ListTile(
                  title: Text(deviceName),
                  subtitle: Text(
                    'IP: $deviceIp | Port: $devicePort',
                  ),
                  trailing: const Icon(Icons.devices),
                  onTap: () {
                    // TODO: We'll implement connection functionality in the next step
                    if (Platform.isAndroid || Platform.isIOS) {

                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => Home(
                          deviceName: deviceName,
                          deviceIp: deviceIp,
                          deviceSocketPort: deviceSocketPort,
                        )),
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
