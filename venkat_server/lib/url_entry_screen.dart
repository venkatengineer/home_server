import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'constants.dart';
import 'dashboard_screen.dart';

const _kPrefKey = 'ngrok_base_url';

class UrlEntryScreen extends StatefulWidget {
  const UrlEntryScreen({super.key});

  @override
  State<UrlEntryScreen> createState() => _UrlEntryScreenState();
}

class _UrlEntryScreenState extends State<UrlEntryScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kPrefKey) ?? '';
    if (saved.isNotEmpty) {
      _controller.text = saved;
    }
  }

  Future<void> _connect() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      setState(() => _errorMsg = 'Please enter a URL.');
      return;
    }

    // Normalise: strip trailing slash, ensure https://
    var url = raw;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    url = url.trimRight().replaceAll(RegExp(r'/+$'), '');

    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    // Quick connectivity test
    try {
      ApiService.baseUrl = url;
      await ApiService.fetchSystem();          // will throw if unreachable
      // Save on success
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefKey, url);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMsg = 'Cannot reach server.\nCheck the URL and try again.';
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Logo ─────────────────────────────────────────────────────
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    border: Border.all(color: kGreen, width: 1.5),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: kGreen.withOpacity(0.35), blurRadius: 24)],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Image.asset(
                      'venkat_server.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.memory, color: kGreen, size: 32),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Title ─────────────────────────────────────────────────────
                const Text(
                  'VENKAT-SERVER',
                  style: TextStyle(
                    fontFamily: 'Orbitron',
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    color: kGreen,
                    shadows: [Shadow(color: kGreen, blurRadius: 12)],
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Enter your ngrok URL to connect',
                  style: TextStyle(fontSize: 11, letterSpacing: 1.5, color: kDim),
                ),

                const SizedBox(height: 32),

                // ── URL field ─────────────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: kPanel,
                    border: Border.all(
                      color: _errorMsg != null ? kRed : kBorder,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 13,
                      color: kText,
                      letterSpacing: 0.5,
                    ),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    enableSuggestions: false,
                    onSubmitted: (_) => _connect(),
                    decoration: const InputDecoration(
                      hintText: 'https://xxxx-xx-xx.ngrok-free.app',
                      hintStyle: TextStyle(color: kDim, fontSize: 12),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.link, color: kDim, size: 18),
                    ),
                  ),
                ),

                // ── Error ─────────────────────────────────────────────────────
                if (_errorMsg != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.error_outline, color: kRed, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _errorMsg!,
                          style: const TextStyle(
                              fontSize: 11, color: kRed, letterSpacing: 0.5),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 18),

                // ── Connect button ────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: _loading ? null : _connect,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 46,
                      decoration: BoxDecoration(
                        color: _loading
                            ? kGreen.withOpacity(0.15)
                            : kGreen.withOpacity(0.12),
                        border: Border.all(
                          color: _loading ? kGreen.withOpacity(0.4) : kGreen,
                        ),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: _loading
                            ? []
                            : [
                                BoxShadow(
                                    color: kGreen.withOpacity(0.2),
                                    blurRadius: 16)
                              ],
                      ),
                      alignment: Alignment.center,
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: kGreen,
                              ),
                            )
                          : const Text(
                              'CONNECT',
                              style: TextStyle(
                                fontFamily: 'Orbitron',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 3,
                                color: kGreen,
                                shadows: [Shadow(color: kGreen, blurRadius: 8)],
                              ),
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // ── Change URL hint ───────────────────────────────────────────
                const Text(
                  'The last used URL is pre-filled.\nTap CONNECT to reuse it or edit to update.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: kDim,
                    letterSpacing: 0.5,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
