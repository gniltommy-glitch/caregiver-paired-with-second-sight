import 'dart:convert';
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

double metersBetween(LatLng a, LatLng b) =>
    const Distance().as(LengthUnit.Meter, a, b);

List<double> toLonLat(LatLng p) => <double>[p.longitude, p.latitude];

LatLng fromLonLat(dynamic raw) {
  if (raw is List && raw.length >= 2) {
    final lon = (raw[0] as num).toDouble();
    final lat = (raw[1] as num).toDouble();
    return LatLng(lat, lon);
  }
  return const LatLng(10.7553, 106.6662);
}

double bearingBetween(LatLng a, LatLng b) {
  final lat1 = a.latitude * math.pi / 180;
  final lat2 = b.latitude * math.pi / 180;
  final dLon = (b.longitude - a.longitude) * math.pi / 180;
  final y = math.sin(dLon) * math.cos(lat2);
  final x =
      math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

class PlaceLocation {
  final String name;
  final String address;
  final LatLng point;

  const PlaceLocation({
    required this.name,
    required this.point,
    this.address = '',
  });

  String get displayLabel => address.isEmpty ? name : '$name — $address';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'point': toLonLat(point),
    if (address.isNotEmpty) 'address': address,
  };

  factory PlaceLocation.fromJson(Map<String, dynamic> json) => PlaceLocation(
    name: (json['name'] as String?) ?? 'Điểm đến',
    point: fromLonLat(json['point']),
    address: (json['address'] as String?) ?? '',
  );
}

class RouteStep {
  final String text;
  final String street;
  final String action;
  final int index;

  const RouteStep({
    required this.text,
    required this.street,
    required this.action,
    required this.index,
  });

  factory RouteStep.fromJson(Map<String, dynamic> json) => RouteStep(
    text: (json['text'] as String?) ?? '',
    street: (json['street'] as String?) ?? '',
    action: (json['action'] as String?) ?? 'continue',
    index: (json['index'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'text': text,
    'street': street,
    'action': action,
    'index': index,
  };
}

class SessionRoute {
  final String id;
  final PlaceLocation destination;
  final List<LatLng> points;
  final List<RouteStep> steps;
  final double distanceMeters;
  final double durationSeconds;
  final DateTime created;
  final bool demo;

  const SessionRoute({
    required this.id,
    required this.destination,
    required this.points,
    required this.steps,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.created,
    this.demo = false,
  });

  factory SessionRoute.fromJson(Map<String, dynamic> json) {
    final rawPoints = (json['points'] as List<dynamic>?) ?? const <dynamic>[];
    final rawSteps = (json['steps'] as List<dynamic>?) ?? const <dynamic>[];
    return SessionRoute(
      id: (json['id'] as String?) ?? 'route',
      destination: PlaceLocation.fromJson(
        (json['destination'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      points: rawPoints.map(fromLonLat).toList(),
      steps: rawSteps
          .whereType<Map<String, dynamic>>()
          .map(RouteStep.fromJson)
          .toList(),
      distanceMeters: (json['distance'] as num?)?.toDouble() ?? 0,
      durationSeconds: (json['seconds'] as num?)?.toDouble() ?? 0,
      created:
          DateTime.tryParse((json['created'] as String?) ?? '') ??
          DateTime.now(),
      demo: json['demo'] == true,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'destination': destination.toJson(),
    'points': points.map(toLonLat).toList(),
    'steps': steps.map((s) => s.toJson()).toList(),
    'distance': distanceMeters,
    'seconds': durationSeconds,
    'created': created.toUtc().toIso8601String(),
    'demo': demo,
  };
}

class GlassHealth {
  final bool demo;
  final double yoloFps;
  final double? cpuTemp;
  final int? batteryPercent;
  final bool cameraOk;
  final bool lidarOk;
  final bool stm32Ok;
  final bool stm32Calibrated;
  final double? stm32Heading;
  final double stm32Pitch;
  final double stm32Roll;
  final DateTime updatedAt;

  const GlassHealth({
    required this.demo,
    required this.yoloFps,
    required this.cpuTemp,
    required this.batteryPercent,
    required this.cameraOk,
    required this.lidarOk,
    required this.stm32Ok,
    required this.stm32Calibrated,
    required this.stm32Heading,
    required this.stm32Pitch,
    required this.stm32Roll,
    required this.updatedAt,
  });

  bool get isThermalThrottling => (cpuTemp ?? 0) >= 75.0;

  bool isFresh(DateTime now) => now.difference(updatedAt).inSeconds <= 8;

  bool get sensorsHealthy => cameraOk && lidarOk && stm32Ok;

  GlassHealth copyWith({
    bool? demo,
    double? yoloFps,
    double? cpuTemp,
    int? batteryPercent,
    bool? cameraOk,
    bool? lidarOk,
    bool? stm32Ok,
    bool? stm32Calibrated,
    double? stm32Heading,
    double? stm32Pitch,
    double? stm32Roll,
    DateTime? updatedAt,
  }) {
    return GlassHealth(
      demo: demo ?? this.demo,
      yoloFps: yoloFps ?? this.yoloFps,
      cpuTemp: cpuTemp ?? this.cpuTemp,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      cameraOk: cameraOk ?? this.cameraOk,
      lidarOk: lidarOk ?? this.lidarOk,
      stm32Ok: stm32Ok ?? this.stm32Ok,
      stm32Calibrated: stm32Calibrated ?? this.stm32Calibrated,
      stm32Heading: stm32Heading ?? this.stm32Heading,
      stm32Pitch: stm32Pitch ?? this.stm32Pitch,
      stm32Roll: stm32Roll ?? this.stm32Roll,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory GlassHealth.fromJson(Map<String, dynamic> json) => GlassHealth(
    demo: json['demo'] == true,
    yoloFps: (json['yolo_fps'] as num?)?.toDouble() ?? 0.0,
    cpuTemp: (json['cpu_temp'] as num?)?.toDouble(),
    batteryPercent: (json['battery_percent'] as num?)?.toInt(),
    cameraOk: json['camera_ok'] != false,
    lidarOk: json['lidar_ok'] != false,
    stm32Ok: json['stm32_ok'] != false,
    stm32Calibrated: json['stm32_calibrated'] == true,
    stm32Heading: (json['stm32_heading'] as num?)?.toDouble(),
    stm32Pitch: (json['stm32_pitch'] as num?)?.toDouble() ?? 0.0,
    stm32Roll: (json['stm32_roll'] as num?)?.toDouble() ?? 0.0,
    updatedAt:
        DateTime.tryParse((json['updated_at'] as String?) ?? '') ??
        DateTime.now(),
  );
}

class SceneDetectionBox {
  final String label;
  final double confidence;
  final double? distanceM;

  /// Normalized [left, top, width, height] in 0..1
  final List<double> normRect;

  const SceneDetectionBox({
    required this.label,
    required this.confidence,
    required this.normRect,
    this.distanceM,
  });

  factory SceneDetectionBox.fromJson(Map<String, dynamic> json) {
    final rawRect =
        (json['rect'] as List<dynamic>?) ?? <dynamic>[0.3, 0.3, 0.3, 0.3];
    return SceneDetectionBox(
      label: (json['label'] as String?) ?? 'obstacle',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.8,
      distanceM: (json['distance_m'] as num?)?.toDouble(),
      normRect: rawRect.map((e) => (e as num).toDouble()).toList(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'label': label,
    'confidence': confidence,
    'rect': normRect,
    if (distanceM != null) 'distance_m': distanceM,
  };
}

class AssistRequest {
  final String requestId;
  final String question;
  final String contextNote;
  final LatLng? position;
  final double? accuracyM;
  final String? imageBase64;
  final String sceneKind;
  final List<SceneDetectionBox> detections;
  final double? tofMinM;
  final String status; // 'pending' | 'replied'
  final String? replyText;
  final String? repliedBy;
  final DateTime? repliedAt;
  final DateTime createdAt;

  const AssistRequest({
    required this.requestId,
    required this.question,
    required this.createdAt,
    this.contextNote = '',
    this.position,
    this.accuracyM,
    this.imageBase64,
    this.sceneKind = 'bus_stop',
    this.detections = const <SceneDetectionBox>[],
    this.tofMinM,
    this.status = 'pending',
    this.replyText,
    this.repliedBy,
    this.repliedAt,
  });

  bool get isPending => status == 'pending';

  AssistRequest markReplied({
    required String text,
    required String sender,
    DateTime? at,
  }) {
    return AssistRequest(
      requestId: requestId,
      question: question,
      contextNote: contextNote,
      position: position,
      accuracyM: accuracyM,
      imageBase64: imageBase64,
      sceneKind: sceneKind,
      detections: detections,
      tofMinM: tofMinM,
      status: 'replied',
      replyText: text,
      repliedBy: sender,
      repliedAt: at ?? DateTime.now(),
      createdAt: createdAt,
    );
  }

  factory AssistRequest.fromJson(Map<String, dynamic> json) {
    final reply = json['reply'] as Map<String, dynamic>?;
    final rawBoxes =
        (json['detections'] as List<dynamic>?) ?? const <dynamic>[];
    return AssistRequest(
      requestId: (json['request_id'] as String?) ?? 'req',
      question:
          (json['question'] as String?) ??
          'Người dùng gửi ảnh nhờ kiểm tra phía trước.',
      contextNote: (json['context_note'] as String?) ?? '',
      position: json['position'] != null ? fromLonLat(json['position']) : null,
      accuracyM: (json['accuracy_m'] as num?)?.toDouble(),
      imageBase64: json['image_base64'] as String?,
      sceneKind: (json['scene_kind'] as String?) ?? 'bus_stop',
      detections: rawBoxes
          .whereType<Map<String, dynamic>>()
          .map(SceneDetectionBox.fromJson)
          .toList(),
      tofMinM: (json['tof_min_m'] as num?)?.toDouble(),
      status: (json['status'] as String?) ?? 'pending',
      replyText: reply != null
          ? (reply['reply_text'] as String?)
          : (json['reply_text'] as String?),
      repliedBy: reply != null
          ? (reply['sender_name'] as String?)
          : (json['replied_by'] as String?),
      repliedAt: reply != null
          ? DateTime.tryParse((reply['replied_at'] as String?) ?? '')
          : null,
      createdAt:
          DateTime.tryParse((json['created_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}

class SosIncident {
  final String sosId;
  final String trigger;
  final String message;
  final LatLng position;
  final double accuracyM;
  final String? imageBase64;
  final String sceneKind;
  final int? batteryPercent;
  final bool active;
  final DateTime createdAt;
  final String? resolvedBy;
  final DateTime? resolvedAt;

  const SosIncident({
    required this.sosId,
    required this.trigger,
    required this.message,
    required this.position,
    required this.accuracyM,
    required this.createdAt,
    this.imageBase64,
    this.sceneKind = 'sos_street',
    this.batteryPercent,
    this.active = true,
    this.resolvedBy,
    this.resolvedAt,
  });

  SosIncident resolve(String by) => SosIncident(
    sosId: sosId,
    trigger: trigger,
    message: message,
    position: position,
    accuracyM: accuracyM,
    imageBase64: imageBase64,
    sceneKind: sceneKind,
    batteryPercent: batteryPercent,
    active: false,
    createdAt: createdAt,
    resolvedBy: by,
    resolvedAt: DateTime.now(),
  );

  factory SosIncident.fromJson(Map<String, dynamic> json) => SosIncident(
    sosId: (json['sos_id'] as String?) ?? 'sos',
    trigger: (json['trigger'] as String?) ?? 'voice_or_button',
    message:
        (json['message'] as String?) ??
        'Người dùng kích hoạt tín hiệu khẩn cấp SOS!',
    position: fromLonLat(json['position']),
    accuracyM: (json['accuracy_m'] as num?)?.toDouble() ?? 5.0,
    imageBase64: json['image_base64'] as String?,
    sceneKind: (json['scene_kind'] as String?) ?? 'sos_street',
    batteryPercent: (json['battery_percent'] as num?)?.toInt(),
    active: json['active'] != false,
    createdAt:
        DateTime.tryParse((json['created_at'] as String?) ?? '') ??
        DateTime.now(),
  );
}

enum EventSeverity { info, warning, critical }

class SafetyEvent {
  final String id;
  final String kind;
  final EventSeverity severity;
  final String title;
  final String detail;
  final LatLng? position;
  final double? distanceM;
  final String? avoidDirection;
  final DateTime timestamp;

  const SafetyEvent({
    required this.id,
    required this.kind,
    required this.severity,
    required this.title,
    required this.detail,
    required this.timestamp,
    this.position,
    this.distanceM,
    this.avoidDirection,
  });
}

class DestinationSuggestion {
  final String suggestionId;
  final String name;
  final String address;
  final LatLng point;
  final String note;
  final String senderName;
  final String status; // 'pending_confirmation' | 'accepted' | 'declined'
  final DateTime createdAt;

  const DestinationSuggestion({
    required this.suggestionId,
    required this.name,
    required this.point,
    required this.senderName,
    required this.createdAt,
    this.address = '',
    this.note = '',
    this.status = 'pending_confirmation',
  });

  DestinationSuggestion copyWith({String? status}) => DestinationSuggestion(
    suggestionId: suggestionId,
    name: name,
    address: address,
    point: point,
    note: note,
    senderName: senderName,
    status: status ?? this.status,
    createdAt: createdAt,
  );

  factory DestinationSuggestion.fromJson(Map<String, dynamic> json) =>
      DestinationSuggestion(
        suggestionId: (json['suggestion_id'] as String?) ?? 'dest',
        name: (json['name'] as String?) ?? 'Điểm đến',
        address: (json['address'] as String?) ?? '',
        point: fromLonLat(json['point']),
        note: (json['note'] as String?) ?? '',
        senderName: (json['sender_name'] as String?) ?? 'Người thân',
        status: (json['status'] as String?) ?? 'pending_confirmation',
        createdAt:
            DateTime.tryParse((json['created_at'] as String?) ?? '') ??
            DateTime.now(),
      );
}

/// Tương thích hoàn toàn với `PairingConfig.parse` của `the_second_sight_mobile_app`.
class SecondSightPairingPayload {
  final String endpoint;
  final String token;
  final String? routingKey;
  final bool allowInsecure;
  final String? relayEndpoint;
  final String? wearerName;
  final String? wearerPhone;

  const SecondSightPairingPayload({
    required this.endpoint,
    required this.token,
    this.routingKey,
    this.allowInsecure = false,
    this.relayEndpoint,
    this.wearerName,
    this.wearerPhone,
  });

  String toQrJsonString() {
    final map = <String, dynamic>{
      'type': 'secondsight_pairing',
      'version': 1,
      'endpoint': endpoint.trim(),
      'token': token.trim(),
      if (routingKey != null && routingKey!.trim().isNotEmpty)
        'routing_key': routingKey!.trim(),
      'allow_insecure': allowInsecure,
      if (relayEndpoint != null && relayEndpoint!.trim().isNotEmpty)
        'relay_endpoint': relayEndpoint!.trim(),
      if (wearerName != null && wearerName!.trim().isNotEmpty)
        'wearer_name': wearerName!.trim(),
      if (wearerPhone != null && wearerPhone!.trim().isNotEmpty)
        'wearer_phone': wearerPhone!.trim(),
    };
    return jsonEncode(map);
  }

  static SecondSightPairingPayload parse(String raw) {
    const invalid = FormatException(
      'Mã QR không đúng chuẩn SecondSight v1. Hãy kiểm tra lại mã cấu hình.',
    );
    if (raw.length > 8192) throw invalid;
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw invalid;
    }
    if (decoded is! Map ||
        decoded['type'] != 'secondsight_pairing' ||
        decoded['version'] != 1) {
      throw invalid;
    }
    final endpoint = decoded['endpoint'];
    final token = decoded['token'];
    final routingKey = decoded['routing_key'];
    final allowInsecureRaw = decoded['allow_insecure'];

    if (endpoint is! String ||
        token is! String ||
        token.trim().isEmpty ||
        token.length > 1024 ||
        (routingKey != null && routingKey is! String) ||
        (allowInsecureRaw != null && allowInsecureRaw is! bool)) {
      throw invalid;
    }

    final uri = Uri.tryParse(endpoint.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw invalid;
    }

    final insecure = allowInsecureRaw == true;
    if (uri.scheme == 'http' && !insecure) {
      throw const FormatException(
        'Địa chỉ HTTP yêu cầu bật allow_insecure=true cho mạng LAN thử nghiệm.',
      );
    }

    return SecondSightPairingPayload(
      endpoint: endpoint.trim(),
      token: token.trim(),
      routingKey: (routingKey as String?)?.trim(),
      allowInsecure: insecure,
      relayEndpoint: (decoded['relay_endpoint'] as String?)?.trim(),
      wearerName: (decoded['wearer_name'] as String?)?.trim(),
      wearerPhone: (decoded['wearer_phone'] as String?)?.trim(),
    );
  }
}
