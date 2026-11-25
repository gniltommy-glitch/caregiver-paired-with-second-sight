import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── Bảng màu đồng bộ hệ sinh thái SecondSight ─────────────────────
const kBg = Color(0xFF0D1117);
const kSurface = Color(0xFF161B22);
const kCard2 = Color(0xFF1C2430);
const kAccent = Color(0xFF22D3A5);
const kAccentSoft = Color(0xFF80E8C8);
const kAccent2 = Color(0xFF818CF8);
const kDanger = Color(0xFFFF5370);
const kWarning = Color(0xFFF59E0B);
const kText = Color(0xFFE6EDF3);
const kTextSub = Color(0xFF8B949E);
const kBorder = Color(0xFF21262D);

ThemeData buildCaregiverTheme() {
  const base = TextStyle(fontFamily: 'BeVietnamPro');
  final textTheme = TextTheme(
    headlineLarge: base.copyWith(
      fontSize: 28,
      fontWeight: FontWeight.w800,
      color: kText,
      letterSpacing: -0.5,
    ),
    headlineMedium: base.copyWith(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: kText,
    ),
    titleLarge: base.copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: kText,
    ),
    titleMedium: base.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: kText,
    ),
    bodyLarge: base.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: kText,
      height: 1.45,
    ),
    bodyMedium: base.copyWith(fontSize: 13.5, color: kTextSub, height: 1.45),
    labelLarge: base.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: kText,
      letterSpacing: 0.2,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'BeVietnamPro',
    brightness: Brightness.dark,
    scaffoldBackgroundColor: kBg,
    colorScheme: const ColorScheme.dark(
      primary: kAccent,
      secondary: kAccent2,
      error: kDanger,
      surface: kSurface,
      onPrimary: Color(0xFF001A14),
      onSecondary: Colors.white,
      onSurface: kText,
      onError: Colors.white,
    ),
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: kBg,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: base.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: kText,
      ),
      iconTheme: const IconThemeData(color: kAccent),
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF11161F),
      indicatorColor: kAccent.withValues(alpha: 0.16),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: kAccent, size: 25);
        }
        return const IconThemeData(color: kTextSub, size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return base.copyWith(
          fontSize: 11.5,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? kAccent : kTextSub,
        );
      }),
      height: 74,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurface,
      hintStyle: base.copyWith(color: kTextSub, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kAccent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kAccent,
        foregroundColor: const Color(0xFF001A14),
        textStyle: base.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
        minimumSize: const Size(56, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kAccent,
        side: BorderSide(color: kAccent.withValues(alpha: 0.55)),
        textStyle: base.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
        minimumSize: const Size(52, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    cardTheme: CardThemeData(
      color: kSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: kBorder),
      ),
    ),
  );
}

/// Spotlight card đồng bộ phong cách React Bits của SecondSight.
class SpotlightCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color accentColor;

  const SpotlightCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.accentColor = kAccentSoft,
  });

  @override
  State<SpotlightCard> createState() => _SpotlightCardState();
}

class _SpotlightCardState extends State<SpotlightCard> {
  Alignment _light = const Alignment(-0.75, -0.85);
  bool _active = false;

  void _updatePoint(Offset local, double width) {
    if (MediaQuery.disableAnimationsOf(context) || width <= 0) return;
    setState(() {
      _light = Alignment(
        (local.dx / width * 2 - 1).clamp(-1.0, 1.0),
        (local.dy / 220 * 2 - 1).clamp(-1.0, 1.0),
      );
      _active = true;
    });
  }

  void _reset() {
    if (!mounted) return;
    setState(() {
      _active = false;
      _light = const Alignment(-0.75, -0.85);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, bounds) => MouseRegion(
        onHover: (e) => _updatePoint(e.localPosition, bounds.maxWidth),
        onExit: (_) => _reset(),
        child: Listener(
          onPointerDown: (e) => _updatePoint(e.localPosition, bounds.maxWidth),
          onPointerUp: (_) => _reset(),
          onPointerCancel: (_) => _reset(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: widget.padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: widget.accentColor.withValues(
                  alpha: _active ? 0.42 : 0.20,
                ),
              ),
              gradient: RadialGradient(
                center: _light,
                radius: 1.65,
                colors: <Color>[
                  widget.accentColor.withValues(alpha: _active ? 0.22 : 0.13),
                  const Color(0xFF15202B),
                  const Color(0xFF131822),
                ],
                stops: const <double>[0, 0.52, 1],
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class MetricArcTile extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final double progress;

  const MetricArcTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.subtitle = '',
    this.color = kAccent,
    this.progress = 0.75,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 46,
            height: 46,
            child: CustomPaint(
              painter: _RingArcPainter(
                progress: progress.clamp(0.0, 1.0),
                color: color,
              ),
              child: Center(child: Icon(icon, size: 20, color: color)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kText,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: kTextSub),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingArcPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _RingArcPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;
    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.5;

    canvas.drawCircle(center, radius, bgPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingArcPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

String formatRelativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inSeconds < 10) return 'Vừa xong';
  if (diff.inMinutes < 1) return '${diff.inSeconds} giây trước';
  if (diff.inHours < 1) return '${diff.inMinutes} phút trước';
  if (diff.inDays < 1) return '${diff.inHours} giờ trước';
  return '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')} '
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}
