import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:http/http.dart' as http;

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
  int _screenTimeLimit = 120; // minutes

  @override
  void initState() {
    super.initState();
    _initHotspot();
    _loadPrefs();
  }

  Future<void> _initHotspot() async {
    await WiFiForIoTPlugin.loadWifiList();
  }

  Future<void> _loadPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _screenTimeLimit = prefs.getInt('screenTimeLimit') ?? 120;
    });
  }

  Future<void> _toggleHotspot(bool on) async {
    setState(() => _hotspotOn = on);
    if (on) {
      await WiFiForIoTPlugin.setEnabled(true); // Android hotspot on
      // Set DNS to NextDNS (e.g., 45.90.28.0)
      await WiFiForIoTPlugin.setDNS('45.90.28.0');
      _dnsStatus = 'NextDNS Active';
    } else {
      await WiFiForIoTPlugin.setEnabled(false);
      _dnsStatus = 'Off';
    }
    setState(() {});
  }

  Future<void> _setLimit(int limit) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('screenTimeLimit', limit);
    setState(() => _screenTimeLimit = limit);
    // TODO: Sync to NextDNS API
    await http.post(Uri.parse('https://dns.nextdns.io/update'), body: {'limit': limit.toString()});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('PocketFence Dashboard')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Hotspot: ${_hotspotOn ? "ON" : "OFF"}', style: TextStyle(fontSize: 20)),
            Switch(value: _hotspotOn, onChanged: _toggleHotspot),
            Text('DNS: $_dnsStatus'),
            Text('Screen Time: $_screenTimeLimit min'),
            Slider(value: _screenTimeLimit.toDouble(), min: 30, max: 240, onChanged: (v) => _setLimit(v.toInt())),
            ElevatedButton(
              onPressed: () => _toggleHotspot(true),
              child: Text('Start Safe Hotspot'),
            ),
            // Add child profiles, logs here
          ],
        ),
      ),
    );
  }
}