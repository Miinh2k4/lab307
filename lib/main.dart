import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IoT Device Dashboard',
      home: const IoTDeviceDashboard(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class IoTDeviceDashboard extends StatefulWidget {
  const IoTDeviceDashboard({super.key});
  @override
  State<IoTDeviceDashboard> createState() => _IoTDeviceDashboardState();
}

class _IoTDeviceDashboardState extends State<IoTDeviceDashboard> {
  final _baseUrl = 'http://172.20.10.3:8080';

  List<Device> _devices = [];
  final Map<int, TextEditingController> _payloadControllers = {};

  final _deviceNameController = TextEditingController();
  final _deviceTopicController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchDevices();
  }

  // ====================== FETCH DEVICES ======================
  Future<void> fetchDevices() async {
    print(">>> [FETCH DEVICES] CALL: $_baseUrl/devices");

    try {
      final response = await http.get(Uri.parse('$_baseUrl/devices'));

      print(">>> [FETCH DEVICES] STATUS = ${response.statusCode}");
      print(">>> [FETCH DEVICES] BODY = ${response.body}");

      if (response.statusCode == 200) {
        final List list = json.decode(response.body);
        setState(() {
          _devices = list.map((json) => Device.fromJson(json)).toList();

          for (var d in _devices) {
            _payloadControllers[d.id] ??= TextEditingController();
          }
        });
      }
    } catch (e) {
      print(">>> [FETCH DEVICES] ERROR = $e");
    }
  }

  // ====================== CREATE DEVICE ======================
  Future<void> createDevice() async {
    if (_deviceNameController.text.isEmpty ||
        _deviceTopicController.text.isEmpty) return;

    print(">>> [CREATE DEVICE] CALLING");

    final response = await http.post(
      Uri.parse('$_baseUrl/devices'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'name': _deviceNameController.text,
        'topic': _deviceTopicController.text,
      }),
    );

    print(">>> [CREATE DEVICE] STATUS = ${response.statusCode}");
    print(">>> [CREATE DEVICE] BODY = ${response.body}");

    if (response.statusCode == 200 || response.statusCode == 201) {
      _deviceNameController.clear();
      _deviceTopicController.clear();
      fetchDevices();
    }
  }

  // ====================== CONTROL DEVICE ======================
  Future<void> controlDevice(int id) async {
    final payload = _payloadControllers[id]?.text ?? "";

    print(">>> [CONTROL] DEVICE ID = $id");
    print(">>> PAYLOAD = $payload");

    final response = await http.post(
      Uri.parse('$_baseUrl/devices/$id/control'),
      headers: {'Content-Type': 'text/plain'},
      body: payload,
    );

    print(">>> [CONTROL] STATUS = ${response.statusCode}");

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lệnh đã được gửi')),
      );
    }
  }

  // ====================== FETCH TELEMETRY ======================
  Future<List<Telemetry>> fetchTelemetry(int deviceId) async {
    final url = '$_baseUrl/telemetry/$deviceId';

    print(">>> [FETCH TELEMETRY] CALLED FOR ID = $deviceId");
    print(">>> [FETCH TELEMETRY] URL = $url");

    try {
      final response = await http.get(Uri.parse(url));

      print(">>> [FETCH TELEMETRY] STATUS = ${response.statusCode}");
      print(">>> [FETCH TELEMETRY] BODY = ${response.body}");

      if (response.statusCode == 200) {
        final List list = json.decode(response.body);
        return list.map((json) => Telemetry.fromJson(json)).toList();
      }
    } catch (e) {
      print(">>> [FETCH TELEMETRY] ERROR = $e");
    }

    return [];
  }

  // ====================== TELEMETRY POPUP ======================
  Future<void> _showTelemetryDialog(int deviceId, String deviceName) async {
    print(">>> [SHOW POPUP] CLICKED FOR DEVICE = $deviceId");

    List<Telemetry> telemetries = await fetchTelemetry(deviceId);

    print(">>> [SHOW POPUP] RECEIVED ${telemetries.length} ITEMS");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Dữ liệu - $deviceName'),
        content: SizedBox(
          width: double.maxFinite,
          child: telemetries.isEmpty
              ? const Text('Không có dữ liệu')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: telemetries.length,
                  itemBuilder: (context, index) {
                    final t = telemetries[index];
                    return ListTile(
                      title: Text(t.value),
                      subtitle: Text(t.timestamp),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          )
        ],
      ),
    );
  }

  // ====================== UI ======================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IoT Device Dashboard'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: ListView(
          children: [
            const Text(
              '📋 Danh sách thiết bị',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            ..._devices.map(
              (d) => Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.name,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      Text("MQTT Topic: ${d.topic}"),

                      const SizedBox(height: 10),

                      TextField(
                        controller: _payloadControllers[d.id],
                        decoration:
                            const InputDecoration(hintText: 'Lệnh điều khiển'),
                      ),

                      const SizedBox(height: 10),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => controlDevice(d.id),
                            icon: const Icon(Icons.send),
                            label: const Text("Gửi lệnh"),
                          ),

                          TextButton(
                            onPressed: () {
                              print(
                                  ">>> [BUTTON] XEM DỮ LIỆU pressed for device ${d.id}");
                              _showTelemetryDialog(d.id, d.name);
                            },
                            child: const Text("Xem dữ liệu"),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              '➕ Thêm thiết bị mới',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _deviceNameController,
              decoration: const InputDecoration(labelText: 'Tên thiết bị'),
            ),
            TextField(
              controller: _deviceTopicController,
              decoration: const InputDecoration(labelText: 'Topic MQTT'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: createDevice,
              child: const Text('Tạo thiết bị'),
            ),
          ],
        ),
      ),
    );
  }
}

// ====================== MODELS ======================
class Device {
  final int id;
  final String name;
  final String topic;

  Device({required this.id, required this.name, required this.topic});

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'],
      name: json['name'],
      topic: json['topic'],
    );
  }
}

class Telemetry {
  final String timestamp;
  final String value;

  Telemetry({required this.timestamp, required this.value});

  factory Telemetry.fromJson(Map<String, dynamic> json) {
    return Telemetry(
      timestamp: json['timestamp'] ?? "No time",
      value: json['value'],
    );
  }
}
