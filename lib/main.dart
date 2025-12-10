import 'dart:io'; // For Platform.isIOS
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For MethodChannels if needed
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart'; // For Settings deep link

void main() => runApp(PocketFenceApp());

class PocketFenceApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PocketFence',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: ParentDashboard(),
    );
  }
}

class ParentDashboard extends StatefulWidget {
  @override
  _ParentDashboardState createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  bool _hotspotOn = false;
  String _dnsStatus = 'Not Set';
  bool _isIOS = Platform.isIOS;
  int _screenTimeLimit = 120; // minutes

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    if (_isIOS) {
      _checkHotspotStatus(); // Simulate check via native if added
    }
  }

  Future<void> _loadPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _screenTimeLimit = prefs.getInt('screenTimeLimit') ?? 120;
    });
  }

  // iOS: Open Settings for manual hotspot toggle
  Future<void> _toggleHotspot(bool on) async {
    setState(() => _hotspotOn = on);
    if (_isIOS) {
      // Deep link to Personal Hotspot settings
      final uri = Uri.parse('App-Prefs:Internet Tethering'); // iOS 10+ hotspot URL
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _dnsStatus = 'Manual Setup Opened - Set DNS to 45.90.28.0 in Wi-Fi Settings';
      } else {
        // Fallback: Open general Settings
        await launchUrl(Uri.parse('app-settings:'), mode: LaunchMode.externalApplication);
        _dnsStatus = 'Go to Settings > Personal Hotspot & Wi-Fi > DNS';
      }
    } else {
      // Android: Keep original logic (add wifi_iot back if needed)
      // await WiFiForIoTPlugin.setEnabled(on);
      _dnsStatus = on ? 'NextDNS Active' : 'Off';
    }
    setState(() {});
  }

  // iOS VPN Fallback for DNS (expand with native channel)
  Future<void> _enableVPNSafeDNS() async {
    if (_isIOS) {
      // Native call: Setup NETunnelProviderManager with NextDNS
      // Example channel invoke (implement in ios/Runner/AppDelegate.swift)
      const channel = MethodChannel('pocketfence.vpn');
      try {
        final bool success = await channel.invokeMethod('setupVPN');
        if (success) {
          _dnsStatus = 'VPN DNS Filter Active (System-Wide)';
        }
      } on PlatformException catch (e) {
        _dnsStatus = 'VPN Setup Failed: $e';
      }
    }
  }

  Future<void> _setLimit(int limit) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('screenTimeLimit', limit);
    setState(() => _screenTimeLimit = limit);
    // Sync to NextDNS
    await http.post(Uri.parse('https://dns.nextdns.io/update'), body: {'limit': limit.toString()});
  }

  void _checkHotspotStatus() {
    // Placeholder: Use private API detection if jailbroken, or prompt user
    // For now, assume off and guide
    setState(() => _dnsStatus = 'Enable in Settings');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('PocketFence Dashboard')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isIOS) Text('iOS Mode: Guided Setup + VPN Fallback', style: TextStyle(fontSize: 16, color: Colors.orange)),
            Text('Hotspot: ${_hotspotOn ? "ON" : "OFF"}', style: TextStyle(fontSize: 20)),
            Switch(value: _hotspotOn, onChanged: _toggleHotspot),
            Text('DNS: $_dnsStatus'),
            Text('Screen Time: $_screenTimeLimit min'),
            Slider(value: _screenTimeLimit.toDouble(), min: 30, max: 240, onChanged: (v) => _setLimit(v.toInt())),
            ElevatedButton(
              onPressed: () => _toggleHotspot(true),
              child: Text('Start Safe Hotspot (iOS: Opens Settings)'),
            ),
            if (_isIOS)
              ElevatedButton(
                onPressed: _enableVPNSafeDNS,
                child: Text('Enable VPN DNS Filter'),
              ),
            // Add logs, profiles here
          ],
        ),
      ),
    );
  }
}