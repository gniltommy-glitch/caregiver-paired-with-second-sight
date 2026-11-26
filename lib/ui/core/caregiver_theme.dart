import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── Design Tokens (UI/UX Pro Max — Healthcare & Family Safety Light) ───
const kCanvas = Color(0xFFF4F6F8); // Warm alabaster canvas
const kSurface = Color(0xFFFFFFFF); // Crisp elevated white cards
const kSurfaceMuted = Color(0xFFEEF2F6); // Secondary recessed surfaces
const kPrimary = Color(
  0xFF0F766E,
); // Calm trustworthy deep teal (5.4:1 on white)
const kPrimarySoft = Color(0xFFE6F4F1); // Subtle teal tint
const kInk = Color(0xFF0F172A); // Deep slate ink (16.5:1)
const kInkSecondary = Color(0xFF475569); // Readable body secondary (7.2:1)
const kInkMuted = Color(0xFF64748B); // Captions & timestamps (4.8:1)
const kBorder = Color(0xFFE2E8F0); // Subtle 1px hairline border
const kDivider = Color(0xFFF1F5F9); // Inset row divider

const kDanger = Color(0xFFDC2626); // Emergency SOS red
const kDangerSoft = Color(0xFFFEF2F2);
const kWarning = Color(0xFFB45309); // High-contrast amber
const kWarningSoft = Color(0xFFFFFBEB);
const kSuccess = Color(0xFF047857); // Safe emerald
const kSuccessSoft = Color(0xFFECFDF5);
const kInfo = Color(0xFF0369A1); // Calm sky-blue info
const kInfoSoft = Color(0xFFF0F9FF);

// Shared spacing tokens (4/8dp rhythm)
const double kSpaceXs = 4;
const double kSpaceSm = 8;
const double kSpaceMd = 16;
const double kSpaceLg = 24;

// Shared elevation shadow (soft ambient, zero neon glow)
final List<BoxShadow> kCardShadow = <BoxShadow>[
  BoxShadow(
    color: const Color(0xFF0F172A).withValues(alpha: 0.05),
    blurRadius: 14,
    offset: const Offset(0, 4),
  ),
];

ThemeData buildCaregiverTheme() {
  const base = TextStyle(fontFamily: 'BeVietnamPro');
  final textTheme = TextTheme(
    headlineLarge: base.copyWith(
      fontSize: 26,
      fontWeight: FontWeight.w800,
      color: kInk,
      letterSpacing: -0.5,
      height: 1.2,
    ),
    headlineMedium: base.copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: kInk,
      letterSpacing: -0.3,
      height: 1.25,
    ),
    titleLarge: base.copyWith(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: kInk,
      height: 1.3,
    ),
    titleMedium: base.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: kInk,
      height: 1.35,
    ),
    bodyLarge: base.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: kInk,
      height: 1.5,
    ),
    bodyMedium: base.copyWith(
      fontSize: 13.5,
      fontWeight: FontWeight.w400,
      color: kInkSecondary,
      height: 1.45,
    ),
    labelLarge: base.copyWith(
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
      color: kInk,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'BeVietnamPro',
    brightness: Brightness.light,
    scaffoldBackgroundColor: kCanvas,
    colorScheme: const ColorScheme.light(
      primary: kPrimary,
      onPrimary: Colors.white,
      secondary: kInfo,
      onSecondary: Colors.white,
      error: kDanger,
      onError: Colors.white,
      surface: kSurface,
      onSurface: kInk,
      outline: kBorder,
    ),
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: kSurface,
      foregroundColor: kInk,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: base.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: kInk,
      ),
      iconTheme: const IconThemeData(color: kInk, size: 22),
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: kSurface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: kPrimarySoft,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: kPrimary, size: 24);
        }
        return const IconThemeData(color: kInkMuted, size: 23);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return base.copyWith(
          fontSize: 11.5,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? kPrimary : kInkMuted,
        );
      }),
      height: 70,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurfaceMuted,
      hintStyle: base.copyWith(color: kInkMuted, fontSize: 14),
      labelStyle: base.copyWith(color: kInkSecondary, fontSize: 13.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.transparent),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kPrimary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        textStyle: base.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600),
        minimumSize: const Size(52, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kInk,
        backgroundColor: kSurface,
        side: const BorderSide(color: kBorder),
        textStyle: base.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kPrimary,
        minimumSize: const Size(48, 44),
        textStyle: base.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: kSurface,
      selectedColor: kPrimarySoft,
      labelStyle: base.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: kInk,
      ),
      side: const BorderSide(color: kBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
    dividerTheme: const DividerThemeData(
      color: kDivider,
      thickness: 1,
      space: 1,
    ),
  );
}

/// Clean elevated surface card with Material ink support.
class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final double radius;

  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = kSurface,
    this.borderColor = kBorder,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: kCardShadow,
      ),
      child: Material(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Subtle, high-contrast status badge (used sparingly for genuine state only).
class StatusBadge extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color bgColor;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.textColor,
    required this.bgColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Clean 2-column metric tile with large tabular value and subtle progress bar.
class CleanMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color accentColor;
  final Color accentBg;
  final double progress;

  const CleanMetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    this.accentColor = kPrimary,
    this.accentBg = kPrimarySoft,
    this.progress = 0.75,
  });

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accentBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: kInkSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: kInk,
              letterSpacing: -0.4,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress.clamp(0.05, 1.0),
              minHeight: 5,
              backgroundColor: kSurfaceMuted,
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const SectionHeader({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: kInk,
            ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(fontSize: 13, color: kInkSecondary),
            ),
          ],
        ],
      ),
    );
  }
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
