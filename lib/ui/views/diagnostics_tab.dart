import 'package:flutter/material.dart';

import '../../domain/models/caregiver_models.dart';
import '../core/caregiver_theme.dart';
import '../view_models/caregiver_view_model.dart';

class DiagnosticsTab extends StatelessWidget {
  final CaregiverViewModel vm;

  const DiagnosticsTab({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    final h = vm.glassHealth;
    final battery = h.batteryPercent ?? 0;
    final cpu = h.cpuTemp ?? 0;
    final thermalWarn = h.isThermalThrottling;
    final allGood = h.sensorsHealthy && !thermalWarn;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: <Widget>[
        // Thẻ tóm tắt sức khỏe tổng quan kiểu Apple Health
        SurfaceCard(
          color: allGood ? kSurface : kWarningSoft,
          borderColor: allGood ? kBorder : const Color(0xFFFDE68A),
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: allGood ? kSuccessSoft : Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  allGood
                      ? Icons.check_circle_rounded
                      : Icons.warning_amber_rounded,
                  color: allGood ? kSuccess : kWarning,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      allGood
                          ? 'Kính đang hoạt động ổn định'
                          : (thermalWarn
                                ? 'Nhiệt độ Pi 5 đang tăng cao'
                                : 'Có cảm biến cần kiểm tra'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: kInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      thermalWarn
                          ? 'CPU đạt ${cpu.toStringAsFixed(1)}°C — nên nhắc ${vm.wearerName} nghỉ nơi thoáng mát.'
                          : 'Cập nhật ${formatRelativeTime(h.updatedAt)} · Mọi cảm biến phản hồi tốt',
                      style: const TextStyle(
                        fontSize: 13,
                        color: kInkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Lưới 2×2 rộng rãi — không bao giờ cắt chữ "..." trên màn hình điện thoại
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.25,
          children: <Widget>[
            CleanMetricTile(
              label: 'Pin bộ kính',
              value: h.batteryPercent != null ? '$battery%' : '--',
              caption: battery < 25 ? 'Cần sạc sớm' : 'Đủ hành trình',
              icon: Icons.battery_charging_full_rounded,
              accentColor: battery < 25 ? kDanger : kSuccess,
              accentBg: battery < 25 ? kDangerSoft : kSuccessSoft,
              progress: battery / 100.0,
            ),
            CleanMetricTile(
              label: 'Nhiệt độ Pi 5',
              value: h.cpuTemp != null ? '${cpu.toStringAsFixed(1)}°C' : '--',
              caption: thermalWarn ? 'Cần làm mát' : 'Ổn định',
              icon: Icons.thermostat_rounded,
              accentColor: thermalWarn ? kDanger : kPrimary,
              accentBg: thermalWarn ? kDangerSoft : kPrimarySoft,
              progress: (cpu / 90.0).clamp(0.05, 1.0),
            ),
            CleanMetricTile(
              label: 'Tốc độ nhận diện',
              value: '${h.yoloFps.toStringAsFixed(1)} FPS',
              caption: h.yoloFps < 10 ? 'Đang chậm' : 'Mượt mà',
              icon: Icons.visibility_outlined,
              accentColor: h.yoloFps < 10 ? kWarning : kInfo,
              accentBg: h.yoloFps < 10 ? kWarningSoft : kInfoSoft,
              progress: (h.yoloFps / 24.0).clamp(0.05, 1.0),
            ),
            CleanMetricTile(
              label: 'Sai số GPS',
              value: vm.gpsAccuracyM != null
                  ? '±${vm.gpsAccuracyM!.toStringAsFixed(1)} m'
                  : '--',
              caption: (vm.gpsAccuracyM ?? 0) <= 20
                  ? 'Đạt chuẩn rẽ'
                  : 'Tín hiệu yếu',
              icon: Icons.gps_fixed_rounded,
              accentColor: (vm.gpsAccuracyM ?? 0) <= 20 ? kSuccess : kWarning,
              accentBg: (vm.gpsAccuracyM ?? 0) <= 20
                  ? kSuccessSoft
                  : kWarningSoft,
              progress: (1.0 - ((vm.gpsAccuracyM ?? 5.0) / 30.0)).clamp(
                0.15,
                1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),

        const SectionHeader(title: 'Trạng thái cảm biến'),
        SurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            children: <Widget>[
              _SensorRow(
                icon: Icons.camera_alt_outlined,
                title: 'Camera quan sát (IMX708)',
                subtitle: h.cameraOk
                    ? 'Đang hoạt động bình thường'
                    : 'Mất tín hiệu camera',
                ok: h.cameraOk,
              ),
              const Divider(),
              _SensorRow(
                icon: Icons.sensors_rounded,
                title: 'Cảm biến khoảng cách ToF 8×8',
                subtitle: h.lidarOk
                    ? 'Đang đo khoảng cách hành lang phía trước'
                    : 'Mất kết nối cảm biến ToF',
                ok: h.lidarOk,
              ),
              const Divider(),
              _SensorRow(
                icon: Icons.explore_outlined,
                title: 'Cảm biến hướng STM32',
                subtitle: h.stm32Ok
                    ? 'Hướng ${(h.stm32Heading ?? 0).toStringAsFixed(0)}° · '
                          'Nghiêng ${h.stm32Pitch.toStringAsFixed(1)}° '
                          '(${h.stm32Calibrated ? 'Đã hiệu chuẩn' : 'Chưa hiệu chuẩn'})'
                    : 'Mất kết nối bo mạch STM32',
                ok: h.stm32Ok,
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        const SectionHeader(
          title: 'Nhật ký an toàn',
          subtitle: 'Các sự kiện và cảnh báo phát sinh trong chuyến đi',
        ),
        SurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: vm.safetyEvents.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Chưa ghi nhận sự kiện bất thường nào.',
                    style: TextStyle(color: kInkMuted),
                  ),
                )
              : Column(
                  children: <Widget>[
                    for (
                      var i = 0;
                      i < vm.safetyEvents.length;
                      i++
                    ) ...<Widget>[
                      if (i > 0) const Divider(),
                      _SafetyEventRow(event: vm.safetyEvents[i]),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _SensorRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool ok;

  const _SensorRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.ok,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: ok ? kSuccessSoft : kDangerSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 20, color: ok ? kSuccess : kDanger),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12.5, color: kInkSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            ok ? Icons.check_circle_rounded : Icons.error_rounded,
            size: 20,
            color: ok ? kSuccess : kDanger,
          ),
        ],
      ),
    );
  }
}

class _SafetyEventRow extends StatelessWidget {
  final SafetyEvent event;

  const _SafetyEventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final (Color color, Color bg, IconData icon) = switch (event.severity) {
      EventSeverity.critical => (kDanger, kDangerSoft, Icons.warning_rounded),
      EventSeverity.warning => (
        kWarning,
        kWarningSoft,
        Icons.report_problem_outlined,
      ),
      EventSeverity.info => (
        kPrimary,
        kPrimarySoft,
        Icons.info_outline_rounded,
      ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        event.title,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: kInk,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatRelativeTime(event.timestamp),
                      style: const TextStyle(fontSize: 11.5, color: kInkMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  event.detail,
                  style: const TextStyle(fontSize: 12.5, color: kInkSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
