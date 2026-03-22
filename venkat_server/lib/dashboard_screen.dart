import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'constants.dart';
import 'alarm_service.dart';
import 'api_service.dart';
import 'widgets.dart';
import 'url_entry_screen.dart';

// ── Formatters ───────────────────────────────────────────────────────────────

String fmtBytes(int b) {
  if (b >= 1073741824) return '${(b / 1073741824).toStringAsFixed(2)} GB';
  if (b >= 1048576)    return '${(b / 1048576).toStringAsFixed(1)} MB';
  return '${(b / 1024).toStringAsFixed(0)} KB';
}

String pad(int n) => n.toString().padLeft(2, '0');

// ═════════════════════════════════════════════════════════════════════════════
//  DASHBOARD SCREEN
// ═════════════════════════════════════════════════════════════════════════════

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  // Data
  SystemData?  _sys;
  MemoryData?  _mem;
  DiskData?    _disk;
  NetworkData? _net;
  TemperatureData? _temp;
  List<ProcessInfo> _procs = [];

  // State
  bool _loading = true;
  bool _error    = false;
  String _errorMsg = '';
  Timer? _timer;
  int _tabIndex  = 0;

  // Alarm
  final AlarmService _alarm = AlarmService();
  String? _alarmReason;

  // CPU sparkline history
  final List<double> _cpuHistory = List.filled(20, 0.0, growable: true);

  // Clock
  String _clockStr = '';
  Timer? _clockTimer;

  // Uptime live ticker
  int _uptimeSecs = 0;
  Timer? _uptimeTimer;

  @override
  void initState() {
    super.initState();
    _startClock();
    _fetchAll();
    _timer = Timer.periodic(kRefreshInterval, (_) => _fetchAll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _clockTimer?.cancel();
    _uptimeTimer?.cancel();
    super.dispose();
  }

  void _startClock() {
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
  }

  void _updateClock() {
    final n = DateTime.now();
    if (mounted) {
      setState(() {
        _clockStr = '${pad(n.hour)}:${pad(n.minute)}:${pad(n.second)}';
      });
    }
  }

  Future<void> _fetchAll() async {
    try {
      final results = await Future.wait([
        ApiService.fetchSystem(),
        ApiService.fetchMemory(),
        ApiService.fetchDisk(),
        ApiService.fetchNetwork(),
        ApiService.fetchProcesses(),
        ApiService.fetchTemperature(),
      ]);
      if (!mounted) return;
      final reason = await _alarm.evaluate(
        cpuPercent:  (results[0] as SystemData).cpuPercent,
        memPercent:  (results[1] as MemoryData).percent,
        diskPercent: (results[2] as DiskData).percent,
      );
      setState(() {
        _sys   = results[0] as SystemData;
        _mem   = results[1] as MemoryData;
        _disk  = results[2] as DiskData;
        _net   = results[3] as NetworkData;
        _procs = results[4] as List<ProcessInfo>;
        _temp  = results[5] as TemperatureData;
        _loading = false;
        _error   = false;
        // Update CPU sparkline
        _cpuHistory.add(_sys!.cpuPercent);
        _cpuHistory.removeAt(0);
        // Uptime
        _uptimeSecs = (DateTime.now().millisecondsSinceEpoch / 1000 - _sys!.uptime).floor();
        if (reason != null) _alarmReason = reason;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error   = true;
        _errorMsg = e.toString();
      });
    }
  }

  // ── Uptime segments ─────────────────────────────────────────────────────────
  int get _uptimeDays  => _uptimeSecs ~/ 86400;
  int get _uptimeHours => (_uptimeSecs % 86400) ~/ 3600;
  int get _uptimeMins  => (_uptimeSecs % 3600) ~/ 60;
  int get _uptimeSec   => _uptimeSecs % 60;

  double get _maxTemp {
    double m = 0.0;
    if (_temp != null) {
      for (var list in _temp!.sensors.values) {
        for (var s in list) {
          if (s.current > m) m = s.current;
        }
      }
    }
    return m;
  }

  // ── BUILD ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: _loading
          ? const _LoadingScreen()
          : _error
              ? _ErrorScreen(msg: _errorMsg, onRetry: _fetchAll)
              : _buildDashboard(),
    );
  }

  Widget _buildDashboard() {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          _buildTickerBar(),
          // Alarm triggered banner
          if (_alarmReason != null) _buildAlarmFiredBanner(),
          // Static threshold warning
          if ((_sys?.cpuPercent ?? 0) > 90 || (_mem?.percent ?? 0) > 90 || (_disk?.percent ?? 0) > 90)
            _buildAlertBanner(),
          // Tab bar
          _buildTabBar(),
          // Content
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              children: [
                _buildOverviewTab(),
                _buildMemoryDiskTab(),
                _buildNetworkTab(),
                _buildProcessesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── HEADER ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: kBorder)),
      ),
      child: Row(
        children: [
          // Logo — long press 1.5s to toggle alarm
          GestureDetector(
            onLongPress: _toggleAlarm,
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                border: Border.all(color: _alarm.enabled ? kGreen : kRed),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [BoxShadow(color: (_alarm.enabled ? kGreen : kRed).withOpacity(0.4), blurRadius: 12)],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Image.asset(
                  'venkat_server.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    _alarm.enabled ? Icons.memory : Icons.volume_off,
                    color: _alarm.enabled ? kGreen : kRed,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'venkat-server',
                  style: TextStyle(
                    fontFamily: 'Orbitron',
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    color: kGreen,
                    shadows: [Shadow(color: kGreen, blurRadius: 10)],
                  ),
                ),
                Text(
                  _sys != null ? '${_sys!.os} — ${_sys!.hostname}' : 'NEURAL GRID v3.1.4',
                  style: const TextStyle(fontSize: 9, letterSpacing: 2, color: kDim),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  _PingDot(),
                  const SizedBox(width: 6),
                  Text(
                    _clockStr,
                    style: const TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 11,
                      color: kBlue,
                      shadows: [Shadow(color: kBlue, blurRadius: 8)],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  GestureDetector(
                    onTap: _fetchAll,
                    child: const Text(
                      '↺ REFRESH',
                      style: TextStyle(
                        fontSize: 9,
                        color: kDim,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      _timer?.cancel();
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                            builder: (_) => const UrlEntryScreen()),
                      );
                    },
                    child: const Text(
                      '↗ URL',
                      style: TextStyle(
                        fontSize: 9,
                        color: kBlue,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── TICKER ──────────────────────────────────────────────────────────────────

  Widget _buildTickerBar() {
    if (_sys == null) return const SizedBox.shrink();
    final mt = _maxTemp;
    final ticker =
        'CPU: ${_sys!.cpuPercent.toStringAsFixed(1)}%   '
        'TEMP: ${mt > 0 ? mt.toStringAsFixed(1) + '°C' : '—'}   '
        'MEM: ${_mem?.percent.toStringAsFixed(1) ?? '—'}%   '
        'DISK: ${_disk?.percent.toStringAsFixed(1) ?? '—'}%   '
        'NET↑: ${fmtBytes(_net?.bytesSent ?? 0)}   '
        'NET↓: ${fmtBytes(_net?.bytesRecv ?? 0)}   '
        'HOST: ${_sys!.hostname}   '
        'CORES: ${_sys!.cpuCores}   '
        'FREQ: ${_sys!.cpuFreqMhz} MHz   ';

    return Container(
      height: 26,
      color: kGreen.withOpacity(0.04),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            color: kGreen,
            child: const Text(
              '// FEED',
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: kBg,
                letterSpacing: 1.5,
              ),
            ),
          ),
          Expanded(
            child: _ScrollingTicker(text: ticker),
          ),
        ],
      ),
    );
  }

  // ── ALARM TOGGLE (hidden — long-press logo) ──────────────────────────────────

  void _toggleAlarm() {
    setState(() => _alarm.toggle());
    // Stop any playing alarm if disabling
    if (!_alarm.enabled) _alarm.stop();

    final msg = _alarm.enabled
        ? '🔔 EMERGENCY ALARM: ENABLED'
        : '🔕 EMERGENCY ALARM: DISABLED';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _alarm.enabled ? kGreen.withOpacity(0.9) : kRed.withOpacity(0.9),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        content: Text(
          msg,
          style: const TextStyle(
            fontFamily: 'Orbitron',
            fontSize: 11,
            letterSpacing: 2,
            color: kBg,
          ),
        ),
      ),
    );
  }

  // ── ALARM FIRED BANNER ────────────────────────────────────────────────────────

  Widget _buildAlarmFiredBanner() {
    return GestureDetector(
      onTap: () => setState(() => _alarmReason = null),
      child: _AlarmFiredBanner(reason: _alarmReason ?? ''),
    );
  }

  // ── ALERT ───────────────────────────────────────────────────────────────────

  Widget _buildAlertBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: kRed.withOpacity(0.08),
        border: Border.all(color: kRed.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: kRed, size: 14),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '⚠ CRITICAL — RESOURCE THRESHOLD EXCEEDED',
              style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: kRed),
            ),
          ),
        ],
      ),
    );
  }

  // ── TAB BAR ─────────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    final tabs = ['OVERVIEW', 'MEM/DISK', 'NETWORK', 'PROCESSES'];
    return Container(
      height: 36,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: kBorder)),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final active = _tabIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tabIndex = i),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: active ? kGreen : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  color: active ? kGreen.withOpacity(0.05) : Colors.transparent,
                ),
                child: Text(
                  tabs[i],
                  style: TextStyle(
                    fontFamily: 'Orbitron',
                    fontSize: 9,
                    letterSpacing: 1.5,
                    color: active ? kGreen : kDim,
                    shadows: active ? [const Shadow(color: kGreen, blurRadius: 8)] : null,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ════════════════════════════════════════════════
  //  TAB 1: OVERVIEW
  // ════════════════════════════════════════════════

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Gauge row
          Row(
            children: [
              Expanded(child: HackerPanel(
                title: 'CPU',
                child: Column(
                  children: [
                    RadialGauge(
                      percent: _sys?.cpuPercent ?? 0,
                      color: kGreen,
                      label: 'CPU',
                      sublabel: 'CPU USAGE',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'CORES: ${_sys?.cpuCores ?? '—'}',
                      style: const TextStyle(fontSize: 9, color: kDim, letterSpacing: 1.5),
                    ),
                    Text(
                      '${_sys?.cpuFreqMhz ?? '—'} MHz',
                      style: const TextStyle(fontSize: 9, color: kDim, letterSpacing: 1.5),
                    ),
                  ],
                ),
              )),
              const SizedBox(width: 10),
              Expanded(child: HackerPanel(
                title: 'MEMORY',
                child: Column(
                  children: [
                    RadialGauge(
                      percent: _mem?.percent ?? 0,
                      color: kBlue,
                      label: 'MEM',
                      sublabel: 'RAM USAGE',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${((_mem?.used ?? 0) / 1073741824).toStringAsFixed(1)} / '
                      '${((_mem?.total ?? 0) / 1073741824).toStringAsFixed(1)} GB',
                      style: const TextStyle(fontSize: 9, color: kDim, letterSpacing: 1),
                    ),
                  ],
                ),
              )),
            ],
          ),
          const SizedBox(height: 10),

          // CPU sparkline
          HackerPanel(
            title: 'CPU HISTORY — 20 SAMPLES',
            child: SizedBox(
              height: 70,
              child: CustomPaint(
                painter: _SparklinePainter(data: _cpuHistory, color: kGreen),
                size: const Size(double.infinity, 70),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Uptime panel
          HackerPanel(
            title: 'SYSTEM UPTIME',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                UptimeSeg(value: '$_uptimeDays', label: 'DAYS'),
                const Text(':', style: TextStyle(color: kGreen, fontSize: 18, shadows: [Shadow(color: kGreen, blurRadius: 8)])),
                UptimeSeg(value: pad(_uptimeHours), label: 'HRS'),
                const Text(':', style: TextStyle(color: kGreen, fontSize: 18, shadows: [Shadow(color: kGreen, blurRadius: 8)])),
                UptimeSeg(value: pad(_uptimeMins), label: 'MIN'),
                const Text(':', style: TextStyle(color: kGreen, fontSize: 18, shadows: [Shadow(color: kGreen, blurRadius: 8)])),
                UptimeSeg(value: pad(_uptimeSec), label: 'SEC'),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // OS info
          HackerPanel(
            title: 'SYSTEM INFO',
            child: Column(
              children: [
                NetRow(label: 'HOSTNAME', value: _sys?.hostname ?? '—', valueColor: kGreen),
                const Divider(color: kBorder, height: 1),
                NetRow(label: 'OS', value: _sys?.os ?? '—', valueColor: kGreen),
                const Divider(color: kBorder, height: 1),
                if (_temp != null) ...[
                  NetRow(label: 'MAX TEMP', value: '${_maxTemp.toStringAsFixed(1)} °C', valueColor: _maxTemp > 80 ? kRed : (_maxTemp > 65 ? kYellow : kGreen)),
                  const Divider(color: kBorder, height: 1),
                ],
                NetRow(label: 'CPU CORES', value: '${_sys?.cpuCores ?? '—'}', valueColor: kGreen),
                const Divider(color: kBorder, height: 1),
                NetRow(label: 'FREQ', value: '${_sys?.cpuFreqMhz ?? '—'} MHz', valueColor: kGreen),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════
  //  TAB 2: MEMORY / DISK
  // ════════════════════════════════════════════════

  Widget _buildMemoryDiskTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          HackerPanel(
            title: 'DISK VOLUME',
            child: Column(
              children: [
                RadialGauge(
                  percent: _disk?.percent ?? 0,
                  color: kYellow,
                  label: 'DISK',
                  sublabel: 'DISK USAGE',
                ),
                const SizedBox(height: 12),
                Text(
                  '${((_disk?.used ?? 0) / 1073741824).toStringAsFixed(1)} GB'
                  ' / ${((_disk?.total ?? 0) / 1073741824).toStringAsFixed(1)} GB',
                  style: const TextStyle(fontSize: 10, color: kDim, letterSpacing: 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          HackerPanel(
            title: 'STORAGE DETAILS',
            child: Column(
              children: [
                HackerBar(
                  percent: _disk?.percent ?? 0,
                  label: 'DISK USAGE',
                  valueLabel: '${(_disk?.percent ?? 0).toStringAsFixed(1)}%',
                ),
                const SizedBox(height: 14),
                HackerBar(
                  percent: (100.0 - (_disk?.percent ?? 0.0)).clamp(0.0, 100.0),
                  label: 'FREE SPACE',
                  valueLabel: fmtBytes(_disk?.free ?? 0),
                ),
                const SizedBox(height: 14),
                HackerBar(
                  percent: _mem?.swapPercent ?? 0,
                  label: 'SWAP USAGE',
                  valueLabel: '${(_mem?.swapPercent ?? 0).toStringAsFixed(1)}%',
                ),
                const SizedBox(height: 14),
                NetRow(label: 'DISK READ', value: fmtBytes(_disk?.readBytes ?? 0)),
                const Divider(color: kBorder, height: 1),
                NetRow(label: 'DISK WRITE', value: fmtBytes(_disk?.writeBytes ?? 0)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          HackerPanel(
            title: 'MEMORY BREAKDOWN',
            child: Column(
              children: [
                HackerBar(
                  percent: _mem?.percent ?? 0,
                  label: 'RAM USAGE',
                  valueLabel: '${(_mem?.percent ?? 0).toStringAsFixed(1)}%',
                ),
                const SizedBox(height: 14),
                NetRow(label: 'TOTAL RAM', value: fmtBytes(_mem?.total ?? 0)),
                const Divider(color: kBorder, height: 1),
                NetRow(label: 'USED', value: fmtBytes(_mem?.used ?? 0)),
                const Divider(color: kBorder, height: 1),
                NetRow(label: 'AVAILABLE', value: fmtBytes(_mem?.available ?? 0)),
                const Divider(color: kBorder, height: 1),
                NetRow(label: 'SWAP TOTAL', value: fmtBytes(_mem?.swapTotal ?? 0)),
                const Divider(color: kBorder, height: 1),
                NetRow(label: 'SWAP USED', value: fmtBytes(_mem?.swapUsed ?? 0)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════
  //  TAB 3: NETWORK
  // ════════════════════════════════════════════════

  Widget _buildNetworkTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          HackerPanel(
            title: 'NETWORK I/O',
            child: Column(
              children: [
                NetRow(label: 'IP ADDRESS', value: _net?.ipAddress ?? '—'),
                const Divider(color: kBorder, height: 1),
                NetRow(label: 'INTERFACE', value: _net?.activeInterface ?? '—'),
                const Divider(color: kBorder, height: 1),
                NetRow(label: '↑ BYTES SENT', value: fmtBytes(_net?.bytesSent ?? 0), valueColor: kGreen),
                const Divider(color: kBorder, height: 1),
                NetRow(label: '↓ BYTES RECV', value: fmtBytes(_net?.bytesRecv ?? 0), valueColor: kBlue),
                const Divider(color: kBorder, height: 1),
                NetRow(label: 'PKTS SENT', value: (_net?.packetsSent ?? 0).toString(), valueColor: kGreen),
                const Divider(color: kBorder, height: 1),
                NetRow(label: 'PKTS RECV', value: (_net?.packetsRecv ?? 0).toString(), valueColor: kBlue),
              ],
            ),
          ),
          const SizedBox(height: 10),
          HackerPanel(
            title: 'BANDWIDTH RATIO',
            child: Column(
              children: [
                HackerBar(
                  percent: _net == null || _net!.bytesSent + _net!.bytesRecv == 0
                      ? 0
                      : (_net!.bytesSent / (_net!.bytesSent + _net!.bytesRecv) * 100),
                  label: '↑ SENT RATIO',
                  valueLabel: fmtBytes(_net?.bytesSent ?? 0),
                ),
                const SizedBox(height: 14),
                HackerBar(
                  percent: _net == null || _net!.bytesSent + _net!.bytesRecv == 0
                      ? 0
                      : (_net!.bytesRecv / (_net!.bytesSent + _net!.bytesRecv) * 100),
                  label: '↓ RECV RATIO',
                  valueLabel: fmtBytes(_net?.bytesRecv ?? 0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════
  //  TAB 4: PROCESSES
  // ════════════════════════════════════════════════

  Widget _buildProcessesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Row(
            children: [
              const Text(
                '// ACTIVE PROCESSES — TOP 50 BY CPU',
                style: TextStyle(fontFamily: 'Orbitron', fontSize: 9, letterSpacing: 2, color: kDim),
              ),
              const Spacer(),
              Text(
                '${_procs.length} PROCS',
                style: const TextStyle(fontFamily: 'Orbitron', fontSize: 9, color: kGreen),
              ),
            ],
          ),
        ),
        // Table header
        Container(
          color: kGreen.withOpacity(0.04),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: const Row(
            children: [
              SizedBox(width: 50, child: Text('PID', style: TextStyle(fontFamily: 'Orbitron', fontSize: 8, color: kDim, letterSpacing: 1.5))),
              Expanded(child: Text('PROCESS', style: TextStyle(fontFamily: 'Orbitron', fontSize: 8, color: kDim, letterSpacing: 1.5))),
              SizedBox(width: 55, child: Text('CPU%', style: TextStyle(fontFamily: 'Orbitron', fontSize: 8, color: kDim, letterSpacing: 1.5))),
              SizedBox(width: 55, child: Text('MEM%', style: TextStyle(fontFamily: 'Orbitron', fontSize: 8, color: kDim, letterSpacing: 1.5))),
              SizedBox(width: 60, child: Text('STATUS', style: TextStyle(fontFamily: 'Orbitron', fontSize: 8, color: kDim, letterSpacing: 1.5))),
            ],
          ),
        ),
        const Divider(color: kBorder, height: 1),
        // Table body
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: _procs.length,
            separatorBuilder: (_, __) => const Divider(color: kBorder, height: 1),
            itemBuilder: (ctx, i) {
              final p = _procs[i];
              return _ProcRow(proc: p, index: i);
            },
          ),
        ),
      ],
    );
  }
}

// ── Process Row ───────────────────────────────────────────────────────────────

class _ProcRow extends StatelessWidget {
  final ProcessInfo proc;
  final int index;
  const _ProcRow({required this.proc, required this.index});

  @override
  Widget build(BuildContext context) {
    final color = index % 2 == 0 ? Colors.transparent : kGreen.withOpacity(0.02);
    return Container(
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              '${proc.pid}',
              style: const TextStyle(fontFamily: 'Orbitron', fontSize: 9, color: kDim),
            ),
          ),
          Expanded(
            child: Text(
              proc.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: kText, letterSpacing: 0.3),
            ),
          ),
          SizedBox(
            width: 55,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${proc.cpuPercent.toStringAsFixed(1)}',
                  style: const TextStyle(fontSize: 10, color: kGreen),
                ),
                const SizedBox(height: 2),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: (proc.cpuPercent / 50).clamp(0.0, 1.0),
                    minHeight: 3,
                    backgroundColor: kGreen.withOpacity(0.08),
                    valueColor: const AlwaysStoppedAnimation(kGreen),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 55,
            child: Text(
              proc.memoryPercent.toStringAsFixed(1),
              style: const TextStyle(fontSize: 10, color: kBlue),
            ),
          ),
          SizedBox(
            width: 60,
            child: StatusPill(status: proc.status),
          ),
        ],
      ),
    );
  }
}

// ── Sparkline Painter ─────────────────────────────────────────────────────────

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  _SparklinePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    // Grid lines
    final gridPaint = Paint()
      ..color = color.withOpacity(0.06)
      ..strokeWidth = 0.5;
    for (int i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Fill
    final fillPath = Path();
    final linePath = Path();
    final maxVal = data.reduce(max).clamp(1.0, 100.0);

    for (int i = 0; i < data.length; i++) {
      final x = size.width * i / (data.length - 1);
      final y = size.height * (1 - data[i] / 100);
      if (i == 0) {
        fillPath.moveTo(x, y);
        linePath.moveTo(x, y);
      } else {
        fillPath.lineTo(x, y);
        linePath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.25), Colors.transparent],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill,
    );

    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Labels on Y
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final v in [0, 25, 50, 75, 100]) {
      final y = size.height * (1 - v / 100);
      tp.text = TextSpan(
        text: '$v',
        style: TextStyle(color: kDim, fontSize: 8, fontFamily: 'Courier'),
      );
      tp.layout();
      tp.paint(canvas, Offset(2, y - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.data != data;
}

// ── Scrolling Ticker ──────────────────────────────────────────────────────────

class _ScrollingTicker extends StatefulWidget {
  final String text;
  const _ScrollingTicker({required this.text});

  @override
  State<_ScrollingTicker> createState() => _ScrollingTickerState();
}

class _ScrollingTickerState extends State<_ScrollingTicker>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat();
    _anim = Tween<Offset>(
      begin: const Offset(1, 0),
      end: const Offset(-1, 0),
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.linear));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SlideTransition(
        position: _anim,
        child: Text(
          widget.text,
          maxLines: 1,
          style: const TextStyle(fontSize: 9, letterSpacing: 1.5, color: kDim),
        ),
      ),
    );
  }
}

// ── Ping Dot ──────────────────────────────────────────────────────────────────

class _PingDot extends StatefulWidget {
  @override
  State<_PingDot> createState() => _PingDotState();
}

class _PingDotState extends State<_PingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 7, height: 7,
              decoration: BoxDecoration(
                color: kGreen, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: kGreen, blurRadius: 6)],
              ),
            ),
            Container(
              width: 7 + 10 * t,
              height: 7 + 10 * t,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: kGreen.withOpacity((1 - t).clamp(0.0, 1.0)),
                  width: 1.5,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Loading Screen ────────────────────────────────────────────────────────────

class _LoadingScreen extends StatefulWidget {
  const _LoadingScreen();

  @override
  State<_LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<_LoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  int _msgIdx = 0;
  Timer? _msgTimer;

  static const _msgs = [
    'LOADING KERNEL MODULES',
    'MOUNTING FILE SYSTEMS',
    'CALIBRATING SENSORS',
    'ESTABLISHING NEURAL LINK',
    'DECRYPTING DATA FEEDS',
    'BOOTING HEURISTIC ENGINE',
    'SYSTEM READY',
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _msgTimer = Timer.periodic(const Duration(milliseconds: 350), (_) {
      if (mounted) setState(() => _msgIdx = (_msgIdx + 1) % _msgs.length);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _msgTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => Text(
                'SYS//MONITOR',
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 5,
                  color: kGreen,
                  shadows: [
                    Shadow(
                      color: kGreen.withOpacity(0.5 + 0.5 * _ctrl.value),
                      blurRadius: 16 + 14 * _ctrl.value,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'NEURAL GRID v3.1.4',
              style: TextStyle(fontSize: 10, letterSpacing: 4, color: kDim),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 240,
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) => LinearProgressIndicator(
                  value: _ctrl.value,
                  backgroundColor: kGreen.withOpacity(0.08),
                  valueColor: const AlwaysStoppedAnimation(kGreen),
                  minHeight: 3,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _msgs[_msgIdx],
              style: const TextStyle(fontSize: 10, letterSpacing: 2, color: kGreen),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error Screen ──────────────────────────────────────────────────────────────

class _ErrorScreen extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;
  const _ErrorScreen({required this.msg, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.link_off, color: kRed, size: 48),
              const SizedBox(height: 16),
              const Text(
                'CONNECTION FAILED',
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  fontSize: 16,
                  color: kRed,
                  letterSpacing: 3,
                  shadows: [Shadow(color: kRed, blurRadius: 12)],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                ApiService.baseUrl,
                style: const TextStyle(fontSize: 11, color: kDim, letterSpacing: 1.5),
              ),
              const SizedBox(height: 10),
              // Show the actual exception so we can debug
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kRed.withOpacity(0.06),
                  border: Border.all(color: kRed.withOpacity(0.2)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  msg,
                  style: const TextStyle(
                    fontSize: 9,
                    color: kRed,
                    letterSpacing: 0.5,
                    fontFamily: 'Courier',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: kGreen),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '↺ RETRY CONNECTION',
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 11,
                      color: kGreen,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Alarm Fired Banner ─────────────────────────────────────────────────────────

class _AlarmFiredBanner extends StatefulWidget {
  final String reason;
  const _AlarmFiredBanner({required this.reason});

  @override
  State<_AlarmFiredBanner> createState() => _AlarmFiredBannerState();
}

class _AlarmFiredBannerState extends State<_AlarmFiredBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Color.lerp(kRed.withOpacity(0.06), kRed.withOpacity(0.18), _ctrl.value),
          border: Border.all(color: kRed.withOpacity(0.4 + 0.4 * _ctrl.value)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_rounded,
              color: kRed,
              size: 16,
              shadows: [Shadow(color: kRed, blurRadius: 8 + 8 * _ctrl.value)],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '⚡ EMERGENCY ALARM TRIGGERED',
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 10,
                      letterSpacing: 2,
                      color: kRed,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.reason,
                    style: const TextStyle(fontSize: 9, color: kRed, letterSpacing: 1),
                  ),
                ],
              ),
            ),
            const Text(
              'TAP TO DISMISS',
              style: TextStyle(fontSize: 8, letterSpacing: 1.5, color: kDim),
            ),
          ],
        ),
      ),
    );
  }
}
