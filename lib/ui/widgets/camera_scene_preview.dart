import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../domain/models/caregiver_models.dart';
import '../core/caregiver_theme.dart';

/// Khung xem ảnh chụp tĩnh từ camera kính IMX708.
/// Thiết kế tinh gọn theo chuẩn camera/photo viewer tự nhiên (không lưới neon).
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
    this.height = 220,
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
        '${capturedAt.hour.toString().padLeft(2, '0')}:${capturedAt.minute.toString().padLeft(2, '0')}';

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: height,
        width: double.infinity,
        color: const Color(0xFFE8EEF2),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (bytes != null)
              Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => CustomPaint(
                  painter: _DaylightStreetScenePainter(sceneKind: sceneKind),
                ),
              )
            else
              CustomPaint(
                painter: _DaylightStreetScenePainter(sceneKind: sceneKind),
              ),

            // Nhãn vật thể YOLO tinh gọn, dễ đọc
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
                    final boxColor = isHazard ? kWarning : kPrimary;

                    return Positioned(
                      left: left,
                      top: top,
                      width: width,
                      height: boxHeight,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: boxColor, width: 2),
                          borderRadius: BorderRadius.circular(8),
                          color: boxColor.withValues(alpha: 0.10),
                        ),
                        alignment: Alignment.topLeft,
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${box.label}'
                            '${box.distanceM != null ? ' · ${box.distanceM!.toStringAsFixed(1)}m' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
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

            // Thẻ thông tin nhỏ góc trên (trắng mờ kiểu iOS Camera)
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
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xD90F172A),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Icons.photo_camera_outlined,
                            size: 13,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              bytes != null
                                  ? 'Ảnh kính · $timeLabel'
                                  : 'Ảnh mô phỏng · $timeLabel',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
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
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Vật gần nhất ${tofMinM!.toStringAsFixed(1)} m',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: tofMinM! < 2.2 ? kDanger : kInk,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Minh họa đường phố ban ngày tự nhiên khi ở chế độ mô phỏng.
class _DaylightStreetScenePainter extends CustomPainter {
  final String sceneKind;

  const _DaylightStreetScenePainter({required this.sceneKind});

  @override
  void paint(Canvas canvas, Size size) {
    final horizon = size.height * 0.44;

    // Bầu trời sáng dịu ban ngày
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, horizon),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFFCDE5F5), Color(0xFFEAF3F8)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, horizon)),
    );

    // Dãy nhà phố nền nhẹ
    canvas.drawRect(
      Rect.fromLTWH(0, horizon - 38, size.width * 0.32, 40),
      Paint()..color = const Color(0xFFD5DEE6),
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.65, horizon - 46, size.width * 0.35, 48),
      Paint()..color = const Color(0xFFCAD6E0),
    );

    // Mặt đường nhựa & vỉa hè lát gạch sáng
    canvas.drawRect(
      Rect.fromLTWH(0, horizon, size.width, size.height - horizon),
      Paint()..color = const Color(0xFFBDC7D1),
    );

    final sidewalkPath = Path()
      ..moveTo(size.width * 0.56, horizon)
      ..lineTo(size.width, horizon)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.42, size.height)
      ..close();
    canvas.drawPath(sidewalkPath, Paint()..color = const Color(0xFFE2E7EC));

    // Làn gạch dẫn hướng màu vàng cho người khiếm thị
    final tactilePath = Path()
      ..moveTo(size.width * 0.72, horizon + 4)
      ..lineTo(size.width * 0.77, horizon + 4)
      ..lineTo(size.width * 0.86, size.height)
      ..lineTo(size.width * 0.74, size.height)
      ..close();
    canvas.drawPath(tactilePath, Paint()..color = const Color(0xFFEAB308));

    if (sceneKind == 'crosswalk') {
      final stripe = Paint()..color = Colors.white.withValues(alpha: 0.9);
      for (var i = 0; i < 5; i++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              size.width * (0.14 + i * 0.14),
              size.height * 0.72,
              size.width * 0.08,
              22,
            ),
            const Radius.circular(3),
          ),
          stripe,
        );
      }
    } else if (sceneKind == 'construction') {
      final rect = Rect.fromLTWH(
        size.width * 0.24,
        size.height * 0.34,
        size.width * 0.52,
        size.height * 0.42,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        Paint()..color = const Color(0xFFFEF3C7),
      );
      final stripe = Paint()
        ..color = const Color(0xFFD97706)
        ..strokeWidth = 7;
      for (var i = 0; i < 5; i++) {
        final x = rect.left + 20 + i * 36;
        canvas.drawLine(
          Offset(x, rect.top + 10),
          Offset(x - 16, rect.top + 40),
          stripe,
        );
      }
    } else {
      // Cột & biển báo trạm xe buýt màu xanh dương Việt Nam
      canvas.drawLine(
        Offset(size.width * 0.70, size.height * 0.20),
        Offset(size.width * 0.70, size.height * 0.78),
        Paint()
          ..color = const Color(0xFF475569)
          ..strokeWidth = 4,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * 0.61,
            size.height * 0.16,
            size.width * 0.18,
            size.height * 0.22,
          ),
          const Radius.circular(8),
        ),
        Paint()..color = const Color(0xFF0369A1),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * 0.64,
            size.height * 0.21,
            size.width * 0.12,
            size.height * 0.08,
          ),
          const Radius.circular(4),
        ),
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DaylightStreetScenePainter oldDelegate) =>
      oldDelegate.sceneKind != sceneKind;
}
