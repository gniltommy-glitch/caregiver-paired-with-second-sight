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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: <Widget>[
        SpotlightCard(
          accentColor: thermalWarn ? kWarning : kAccentSoft,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  StatusPill(
                    label: h.sensorsHealthy
                        ? 'PHẦN CỨNG ỔN ĐỊNH'
                        : 'CÓ CẢM BIẾN GIÁN ĐOẠN',
                    color: h.sensorsHealthy ? kAccent : kDanger,
                    icon: h.sensorsHealthy
                        ? Icons.verified_outlined
                        : Icons.error_outline,
                  ),
                  Text(
                    'Cập nhật ${formatRelativeTime(h.updatedAt)}',
                    style: const TextStyle(fontSize: 12, color: kTextSub),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Giám sát kỹ thuật kính từ xa',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: kText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                thermalWarn
                    ? 'Cảnh báo: CPU Raspberry Pi 5 đang đạt ${cpu.toStringAsFixed(1)}°C (ngưỡng giảm xung ≥75°C). Nên gọi nhắc ${vm.wearerName} tạm nghỉ nơi thoáng mát.'
                    : 'Theo dõi trực tiếp gói tin device_status (Raspberry Pi 5 + ToF SEN0628 + STM32F411 IMU) để kịp thời nhắc người đeo kính khi cảm biến suy giảm.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: thermalWarn ? kWarning : kTextSub,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 560;
            return GridView.count(
              crossAxisCount: isWide ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: isWide ? 2.1 : 1.75,
              children: <Widget>[
                MetricArcTile(
                  label: 'Pin bộ kính',
                  value: h.batteryPercent != null ? '$battery%' : 'Chưa rõ',
                  subtitle: battery < 25 ? 'Cần sạc sớm' : 'Đủ cho hành trình',
                  icon: Icons.battery_charging_full_rounded,
                  color: battery < 25 ? kDanger : kAccent,
                  progress: battery / 100.0,
                ),
                MetricArcTile(
                  label: 'Nhiệt độ Pi 5',
                  value: h.cpuTemp != null
                      ? '${cpu.toStringAsFixed(1)}°C'
                      : '--',
                  subtitle: thermalWarn
                      ? 'Đang throttling!'
                      : 'Bình thường (<75°C)',
                  icon: Icons.thermostat_rounded,
                  color: thermalWarn ? kDanger : kAccent,
                  progress: (cpu / 90.0).clamp(0.0, 1.0),
                ),
                MetricArcTile(
                  label: 'Nhận diện YOLO',
                  value: '${h.yoloFps.toStringAsFixed(1)} FPS',
                  subtitle: h.yoloFps < 10 ? 'Tốc độ thấp' : 'Luồng vision ổn',
                  icon: Icons.visibility_outlined,
                  color: h.yoloFps < 10 ? kWarning : kAccent2,
                  progress: (h.yoloFps / 24.0).clamp(0.0, 1.0),
                ),
                MetricArcTile(
                  label: 'Độ chính xác GPS',
                  value: vm.gpsAccuracyM != null
                      ? '±${vm.gpsAccuracyM!.toStringAsFixed(1)} m'
                      : '--',
                  subtitle: (vm.gpsAccuracyM ?? 0) <= 20
                      ? 'Đạt chuẩn rẽ (≤20m)'
                      : 'Sai số lớn',
                  icon: Icons.gps_fixed_rounded,
                  color: (vm.gpsAccuracyM ?? 0) <= 20 ? kAccent : kWarning,
                  progress: (1.0 - ((vm.gpsAccuracyM ?? 5.0) / 30.0)).clamp(
                    0.15,
                    1.0,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Trạng thái từng phân hệ phần cứng',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: kText,
                ),
              ),
              const SizedBox(height: 10),
              _SensorStatusRow(
                title: 'Camera CSI IMX708 (Vision + VietOCR)',
                detail: h.cameraOk
                    ? 'Đang cấp khung hình 640×360 & chụp tĩnh 2304×1296'
                    : 'Mất tín hiệu camera — không thể nhận diện vật cản xa',
                ok: h.cameraOk,
              ),
              const Divider(color: kBorder, height: 18),
              _SensorStatusRow(
                title: 'Cảm biến khoảng cách ToF SEN0628 (Ma trận 8×8 I2C)',
                detail: h.lidarOk
                    ? 'Đang quét hành lang an toàn phía trước'
                    : 'Lỗi giao tiếp I2C ToF — cần kiểm tra dây',
                ok: h.lidarOk,
              ),
              const Divider(color: kBorder, height: 18),
              _SensorStatusRow(
                title:
                    'Vi điều khiển STM32F411E-DISCO (Mahony IMU + CS43L22 DAC)',
                detail: h.stm32Ok
                    ? 'Heading ${(h.stm32Heading ?? 0).toStringAsFixed(1)}° · '
                          'Pitch ${h.stm32Pitch.toStringAsFixed(1)}° · '
                          'Roll ${h.stm32Roll.toStringAsFixed(1)}° '
                          '(${h.stm32Calibrated ? 'Đã hiệu chuẩn' : 'Chưa hiệu chuẩn'})'
                    : 'Mất kết nối UART 1 Mbaud với STM32',
                ok: h.stm32Ok,
              ),
            ],
          ),
        ),
        if (vm.simulationMode) ...<Widget>[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: kBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Thử nghiệm phát hiện bất thường thụ động (Demo)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kWarning,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    ActionChip(
                      avatar: const Icon(
                        Icons.personal_injury_outlined,
                        size: 16,
                        color: kDanger,
                      ),
                      label: const Text('Nghi rơi kính / té ngã (IMU)'),
                      onPressed: () => vm.triggerDemoAnomaly('imu_fall'),
                    ),
                    ActionChip(
                      avatar: const Icon(
                        Icons.local_fire_department_outlined,
                        size: 16,
                        color: kWarning,
                      ),
                      label: const Text('Pi 5 quá nhiệt (79.4°C)'),
                      onPressed: () => vm.triggerDemoAnomaly('thermal'),
                    ),
                    ActionChip(
                      avatar: const Icon(
                        Icons.wrong_location_outlined,
                        size: 16,
                        color: kAccent2,
                      ),
                      label: const Text('Lệch tuyến kéo dài'),
                      onPressed: () => vm.triggerDemoAnomaly('off_route'),
                    ),
                    ActionChip(
                      avatar: const Icon(
                        Icons.restart_alt_rounded,
                        size: 16,
                        color: kAccent,
                      ),
                      label: const Text('Khôi phục bình thường'),
                      onPressed: vm.resetDemoHardwareNormal,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        const Text(
          'Nhật ký an toàn & sự kiện hành trình',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: kText,
          ),
        ),
        const SizedBox(height: 10),
        ...vm.safetyEvents.map(_buildEventTile),
      ],
    );
  }

  Widget _buildEventTile(SafetyEvent ev) {
    final (Color color, IconData icon) = switch (ev.severity) {
      EventSeverity.critical => (kDanger, Icons.warning_amber_rounded),
      EventSeverity.warning => (kWarning, Icons.report_problem_outlined),
      EventSeverity.info => (kAccent, Icons.info_outline_rounded),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: ev.severity == EventSeverity.critical
                ? kDanger.withValues(alpha: 0.45)
                : kBorder,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
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
                          ev.title,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: kText,
                          ),
                        ),
                      ),
                      Text(
                        formatRelativeTime(ev.timestamp),
                        style: const TextStyle(fontSize: 11, color: kTextSub),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ev.detail,
                    style: const TextStyle(fontSize: 12.5, color: kTextSub),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SensorStatusRow extends StatelessWidget {
  final String title;
  final String detail;
  final bool ok;

  const _SensorStatusRow({
    required this.title,
    required this.detail,
    required this.ok,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(
          ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
          color: ok ? kAccent : kDanger,
          size: 22,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: kText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: const TextStyle(fontSize: 12, color: kTextSub),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
