import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../domain/models/caregiver_models.dart';
import '../core/caregiver_theme.dart';

/// Hiển thị ảnh chụp tĩnh từ camera IMX708 của kính thông minh.
/// - Nếu có `imageBase64` thật từ Pi 5 / Relay: giải mã và hiển thị ảnh JPEG gốc kèm lớp phủ HUD.
/// - Nếu đang ở chế độ mô phỏng (không có dữ liệu nhị phân): dựng khung cảnh đường phố
///   trực quan với bounding box YOLO và khoảng cách ToF để kiểm thử trực tiếp trên điện thoại.
class CameraScenePreview extends StatelessWidget {
  final String? imageBase64;
  final String sceneKind;
  final List<SceneDetectionBox> detections;
  final double? tofMinM;
  final DateTime capturedAt;
  final double height;

  const CameraScenePreview({
    super.key,
    required this.capturedAt,
    this.imageBase64,
    this.sceneKind = 'bus_stop',
    this.detections = const <SceneDetectionBox>[],
    this.tofMinM,
    this.height = 210,
  });

  Uint8List? _tryDecodeImage() {
    if (imageBase64 == null || imageBase64!.trim().isEmpty) return null;
    try {
      final raw = imageBase64!.contains(',')
          ? imageBase64!.split(',').last
          : imageBase64!;
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _tryDecodeImage();
    final timeLabel =
        '${capturedAt.hour.toString().padLeft(2, '0')}:${capturedAt.minute.toString().padLeft(2, '0')}:${capturedAt.second.toString().padLeft(2, '0')}';

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF0A0F16),
          border: Border.all(color: kBorder),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (bytes != null)
              Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => CustomPaint(
                  painter: _SimulatedStreetPainter(sceneKind: sceneKind),
                ),
              )
            else
              CustomPaint(
                painter: _SimulatedStreetPainter(sceneKind: sceneKind),
              ),

            // Lớp phủ bounding box YOLO + khoảng cách ToF
            if (detections.isNotEmpty)
              LayoutBuilder(
                builder: (context, constraints) => Stack(
                  children: detections.map((box) {
                    if (box.normRect.length < 4) return const SizedBox.shrink();
                    final left = box.normRect[0] * constraints.maxWidth;
                    final top = box.normRect[1] * constraints.maxHeight;
                    final width = box.normRect[2] * constraints.maxWidth;
                    final boxHeight = box.normRect[3] * constraints.maxHeight;
                    final isHazard =
                        box.label.contains('obstacle') ||
                        box.label.contains('vehicle');
                    final boxColor = isHazard ? kWarning : kAccent;

                    return Positioned(
                      left: left,
                      top: top,
                      width: width,
                      height: boxHeight,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: boxColor, width: 1.8),
                          borderRadius: BorderRadius.circular(6),
                          color: boxColor.withValues(alpha: 0.08),
                        ),
                        alignment: Alignment.topLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xDD0B1017),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${box.label} ${(box.confidence * 100).round()}%'
                            '${box.distanceM != null ? ' · ${box.distanceM!.toStringAsFixed(1)}m' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: boxColor,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

            // HUD góc trên: nguồn ảnh camera kính + thời gian chụp
            Positioned(
              left: 10,
              top: 10,
              right: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xCC0D1117),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: kAccent.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Icons.photo_camera_outlined,
                            size: 13,
                            color: kAccent,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              bytes != null
                                  ? 'IMX708 · $timeLabel'
                                  : 'KHUNG HÌNH KÍNH · $timeLabel',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: kText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (tofMinM != null) ...<Widget>[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xCC0D1117),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: (tofMinM! < 2.2 ? kDanger : kWarning)
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        'ToF: ${tofMinM!.toStringAsFixed(1)} m',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: tofMinM! < 2.2 ? kDanger : kWarning,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Ghi chú không truyền video liên tục
            Positioned(
              left: 10,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xB30D1117),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Ảnh tĩnh theo yêu cầu (~150 KB) · Không stream video nền',
                  style: TextStyle(fontSize: 10, color: kTextSub),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SimulatedStreetPainter extends CustomPainter {
  final String sceneKind;

  const _SimulatedStreetPainter({required this.sceneKind});

  @override
  void paint(Canvas canvas, Size size) {
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFF142433),
          Color(0xFF1E3240),
          Color(0xFF121821),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, skyPaint);

    final horizon = size.height * 0.48;

    // Mặt đường & vỉa hè phối cảnh
    final roadPath = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width * 0.30, horizon)
      ..lineTo(size.width * 0.72, horizon)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(roadPath, Paint()..color = const Color(0xFF1B222C));

    // Vỉa hè gạch dẫn hướng màu vàng
    final tactilePath = Path()
      ..moveTo(size.width * 0.76, size.height)
      ..lineTo(size.width * 0.62, horizon + 8)
      ..lineTo(size.width * 0.66, horizon + 8)
      ..lineTo(size.width * 0.85, size.height)
      ..close();
    canvas.drawPath(
      tactilePath,
      Paint()..color = const Color(0xFFF59E0B).withValues(alpha: 0.42),
    );

    if (sceneKind == 'crosswalk') {
      final stripePaint = Paint()..color = Colors.white.withValues(alpha: 0.55);
      for (var i = 0; i < 6; i++) {
        final x = size.width * (0.18 + i * 0.11);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, size.height * 0.74, size.width * 0.06, 24),
            const Radius.circular(3),
          ),
          stripePaint,
        );
      }
    } else if (sceneKind == 'construction') {
      final barrierRect = Rect.fromLTWH(
        size.width * 0.25,
        size.height * 0.34,
        size.width * 0.50,
        size.height * 0.44,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(barrierRect, const Radius.circular(6)),
        Paint()..color = const Color(0xFF3A2618),
      );
      final hazardStripe = Paint()
        ..color = kWarning.withValues(alpha: 0.75)
        ..strokeWidth = 6;
      for (var i = 0; i < 5; i++) {
        final dx = barrierRect.left + 16 + i * 34;
        canvas.drawLine(
          Offset(dx, barrierRect.top + 12),
          Offset(dx - 14, barrierRect.top + 38),
          hazardStripe,
        );
      }
    } else {
      // Biển báo trạm xe buýt / phòng khám
      final postPaint = Paint()
        ..color = const Color(0xFF6E7D90)
        ..strokeWidth = 4;
      canvas.drawLine(
        Offset(size.width * 0.69, size.height * 0.20),
        Offset(size.width * 0.69, size.height * 0.78),
        postPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * 0.60,
            size.height * 0.17,
            size.width * 0.19,
            size.height * 0.22,
          ),
          const Radius.circular(6),
        ),
        Paint()..color = const Color(0xFF1D4E68),
      );
    }

    // Lưới tâm ngắm ToF 8x8 nhẹ
    final gridPaint = Paint()
      ..color = kAccent.withValues(alpha: 0.08)
      ..strokeWidth = 0.8;
    for (var i = 1; i < 8; i++) {
      final gx = size.width * (i / 8);
      final gy = size.height * (i / 8);
      canvas.drawLine(Offset(gx, 0), Offset(gx, size.height), gridPaint);
      canvas.drawLine(Offset(0, gy), Offset(size.width, gy), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SimulatedStreetPainter oldDelegate) =>
      oldDelegate.sceneKind != sceneKind;
}
