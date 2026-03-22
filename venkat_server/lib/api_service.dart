import 'dart:convert';
import 'package:http/http.dart' as http;

// ── Data Models ──────────────────────────────────────────────────────────────

class SystemData {
  final String hostname, os, osVersion;
  final double cpuPercent, cpuFreqMhz;
  final int cpuCores;
  final double uptime, currentTime;

  SystemData({
    required this.hostname,
    required this.os,
    required this.osVersion,
    required this.cpuPercent,
    required this.cpuCores,
    required this.cpuFreqMhz,
    required this.uptime,
    required this.currentTime,
  });

  factory SystemData.fromJson(Map<String, dynamic> j) => SystemData(
        hostname: j['hostname'] ?? '—',
        os: j['os'] ?? '—',
        osVersion: j['os_version'] ?? '',
        cpuPercent: (j['cpu_percent'] ?? 0).toDouble(),
        cpuCores: j['cpu_cores'] ?? 0,
        cpuFreqMhz: (j['cpu_freq_mhz'] ?? 0).toDouble(),
        uptime: (j['uptime'] ?? 0).toDouble(),
        currentTime: (j['current_time'] ?? 0).toDouble(),
      );
}

class MemoryData {
  final int total, used, available, swapTotal, swapUsed;
  final double percent, swapPercent;

  MemoryData({
    required this.total,
    required this.used,
    required this.available,
    required this.swapTotal,
    required this.swapUsed,
    required this.percent,
    required this.swapPercent,
  });

  factory MemoryData.fromJson(Map<String, dynamic> j) => MemoryData(
        total: j['total'] ?? 0,
        used: j['used'] ?? 0,
        available: j['available'] ?? 0,
        swapTotal: j['swap_total'] ?? 0,
        swapUsed: j['swap_used'] ?? 0,
        percent: (j['percent'] ?? 0).toDouble(),
        swapPercent: (j['swap_percent'] ?? 0).toDouble(),
      );
}

class DiskData {
  final int total, used, free, readBytes, writeBytes;
  final double percent;

  DiskData({
    required this.total,
    required this.used,
    required this.free,
    required this.readBytes,
    required this.writeBytes,
    required this.percent,
  });

  factory DiskData.fromJson(Map<String, dynamic> j) => DiskData(
        total: j['total'] ?? 0,
        used: j['used'] ?? 0,
        free: j['free'] ?? 0,
        readBytes: j['read_bytes'] ?? 0,
        writeBytes: j['write_bytes'] ?? 0,
        percent: (j['percent'] ?? 0).toDouble(),
      );
}

class NetworkData {
  final int bytesSent, bytesRecv, packetsSent, packetsRecv;
  final String ipAddress, activeInterface;

  NetworkData({
    required this.bytesSent,
    required this.bytesRecv,
    required this.packetsSent,
    required this.packetsRecv,
    required this.ipAddress,
    required this.activeInterface,
  });

  factory NetworkData.fromJson(Map<String, dynamic> j) => NetworkData(
        bytesSent: j['bytes_sent'] ?? 0,
        bytesRecv: j['bytes_recv'] ?? 0,
        packetsSent: j['packets_sent'] ?? 0,
        packetsRecv: j['packets_recv'] ?? 0,
        ipAddress: j['ip_address'] ?? '—',
        activeInterface: j['active_interface'] ?? '—',
      );
}

class ProcessInfo {
  final int pid;
  final String name, status;
  final double cpuPercent, memoryPercent;

  ProcessInfo({
    required this.pid,
    required this.name,
    required this.status,
    required this.cpuPercent,
    required this.memoryPercent,
  });

  factory ProcessInfo.fromJson(Map<String, dynamic> j) => ProcessInfo(
        pid: j['pid'] ?? 0,
        name: j['name'] ?? '?',
        status: j['status'] ?? 'unknown',
        cpuPercent: (j['cpu_percent'] ?? 0).toDouble(),
        memoryPercent: (j['memory_percent'] ?? 0).toDouble(),
      );
}

class TemperatureSensor {
  final String label;
  final double current;
  final double? high;
  final double? critical;

  TemperatureSensor({
    required this.label,
    required this.current,
    this.high,
    this.critical,
  });

  factory TemperatureSensor.fromJson(Map<String, dynamic> j) => TemperatureSensor(
        label: j['label']?.toString() ?? '',
        current: (j['current'] ?? 0).toDouble(),
        high: j['high'] != null ? (j['high'] as num).toDouble() : null,
        critical: j['critical'] != null ? (j['critical'] as num).toDouble() : null,
      );
}

class TemperatureData {
  final Map<String, List<TemperatureSensor>> sensors;

  TemperatureData({required this.sensors});

  factory TemperatureData.fromJson(Map<String, dynamic> j) {
    final Map<String, List<TemperatureSensor>> map = {};
    j.forEach((key, value) {
      if (value is List) {
        map[key] = value.map((e) => TemperatureSensor.fromJson(e)).toList();
      }
    });
    return TemperatureData(sensors: map);
  }
}

// ── API Service ──────────────────────────────────────────────────────────────

class ApiService {
  /// Set this before making any API calls (done from the URL entry screen).
  static String baseUrl = '';

  static Future<T> _get<T>(String path, T Function(dynamic) parser) async {
    final res = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: {'ngrok-skip-browser-warning': 'true'},
    ).timeout(const Duration(seconds: 10));
    return parser(jsonDecode(res.body));
  }

  static Future<SystemData>       fetchSystem()   => _get('/api/system',    (j) => SystemData.fromJson(j));
  static Future<MemoryData>       fetchMemory()   => _get('/api/memory',    (j) => MemoryData.fromJson(j));
  static Future<DiskData>         fetchDisk()     => _get('/api/disk',      (j) => DiskData.fromJson(j));
  static Future<NetworkData>      fetchNetwork()  => _get('/api/network',   (j) => NetworkData.fromJson(j));
  static Future<List<ProcessInfo>> fetchProcesses() =>
      _get('/api/processes', (j) => (j as List).map((e) => ProcessInfo.fromJson(e)).toList());
  static Future<TemperatureData>  fetchTemperature() => _get('/temperature', (j) => TemperatureData.fromJson(j));
}
