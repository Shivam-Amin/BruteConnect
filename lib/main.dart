import 'package:flutter/material.dart';
import 'package:brute_connect/pages/device_discovery_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'mDNS Connect App',
      home: DeviceDiscoveryScreen(),
      theme: ThemeData(primarySwatch: Colors.blue),
    );
  }
}
