import 'dart:math';
import 'package:flutter/material.dart';
import 'constants.dart';

// ── Radial Gauge ─────────────────────────────────────────────────────────────

class RadialGauge extends StatelessWidget {
  final double percent;
  final Color color;
  final String label;
  final String sublabel;

  const RadialGauge({
    super.key,
    required this.percent,
    required this.color,
    required this.label,
    required this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      height: 110,
      child: CustomPaint(
        painter: _GaugePainter(percent: percent / 100, color: color),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${percent.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: percent > 85 ? kRed : color,
                  shadows: [Shadow(color: color, blurRadius: 10)],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sublabel,
                style: const TextStyle(
                  fontFamily: 'Orbitron',
                  fontSize: 7,
                  letterSpacing: 1.5,
                  color: kDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double percent;
  final Color color;
  _GaugePainter({required this.percent, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.width / 2 - 8;
    const strokeW = 7.0;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    // Track
    canvas.drawArc(
      rect, -pi / 2, 2 * pi, false,
      Paint()
        ..color = kGreen.withOpacity(0.1)
        ..strokeWidth = strokeW
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Fill
    canvas.drawArc(
      rect, -pi / 2, 2 * pi * percent, false,
      Paint()
        ..color = percent > 0.85 ? kRed : color
        ..strokeWidth = strokeW
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.percent != percent || old.color != color;
}

// ── Panel Card ───────────────────────────────────────────────────────────────

class HackerPanel extends StatelessWidget {
  final String title;
  final Widget child;
  final EdgeInsets? padding;

  const HackerPanel({
    super.key,
    required this.title,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kPanel,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                const Text(
                  '// ',
                  style: TextStyle(color: kGreen, fontFamily: 'Courier', fontSize: 11),
                ),
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Orbitron',
                    fontSize: 9,
                    letterSpacing: 2.5,
                    color: kDim,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: padding ?? const EdgeInsets.all(14),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ── Bar Progress ─────────────────────────────────────────────────────────────

class HackerBar extends StatelessWidget {
  final double percent;
  final String label;
  final String valueLabel;

  const HackerBar({
    super.key,
    required this.percent,
    required this.label,
    required this.valueLabel,
  });

  Color get _barColor {
    if (percent < 60) return kGreen;
    if (percent < 85) return kYellow;
    return kRed;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, letterSpacing: 1.5, color: kDim)),
            Text(valueLabel, style: TextStyle(fontSize: 10, letterSpacing: 1, color: _barColor)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: (percent / 100).clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: kGreen.withOpacity(0.08),
            valueColor: AlwaysStoppedAnimation(_barColor),
          ),
        ),
      ],
    );
  }
}

// ── Net Row ───────────────────────────────────────────────────────────────────

class NetRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const NetRow({super.key, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, letterSpacing: 1.5, color: kDim)),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Orbitron',
              fontSize: 11,
              color: valueColor ?? kBlue,
              shadows: [Shadow(color: valueColor ?? kBlue, blurRadius: 6)],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status Pill ───────────────────────────────────────────────────────────────

class StatusPill extends StatelessWidget {
  final String status;
  const StatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg, fg, border;
    switch (status.toLowerCase()) {
      case 'running':
        bg = kGreen.withOpacity(0.12);
        fg = kGreen;
        border = kGreen.withOpacity(0.3);
        break;
      case 'sleeping':
        bg = kBlue.withOpacity(0.1);
        fg = kBlue;
        border = kBlue.withOpacity(0.2);
        break;
      default:
        bg = kYellow.withOpacity(0.1);
        fg = kYellow;
        border = kYellow.withOpacity(0.25);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(fontSize: 8, letterSpacing: 1, color: fg),
      ),
    );
  }
}

// ── Glowing Text ─────────────────────────────────────────────────────────────

class GlowText extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color color;
  final String? fontFamily;
  final FontWeight? fontWeight;

  const GlowText(this.text, {
    super.key,
    this.fontSize = 14,
    this.color = kGreen,
    this.fontFamily,
    this.fontWeight,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: fontFamily ?? 'Orbitron',
        fontSize: fontSize,
        fontWeight: fontWeight ?? FontWeight.w700,
        color: color,
        shadows: [Shadow(color: color, blurRadius: 12)],
      ),
    );
  }
}

// ── Uptime box ────────────────────────────────────────────────────────────────

class UptimeSeg extends StatelessWidget {
  final String value;
  final String label;
  const UptimeSeg({super.key, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GlowText(value, fontSize: 22, color: kGreen),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 8, letterSpacing: 2, color: kDim)),
      ],
    );
  }
}
