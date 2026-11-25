import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../data/services/geocoding_service.dart';
import '../../data/services/relay_link_service.dart';
import '../../domain/models/caregiver_models.dart';

class CaregiverViewModel extends ChangeNotifier {
  CaregiverViewModel({
    RelayLinkService? relayLink,
    GeocodingService? geocoding,
    this.enablePlatformPlugins = true,
  }) : _link = relayLink ?? RelayLinkService(),
       _geocoding = geocoding ?? GeocodingService() {
    _link.onMessage = _handleServerMessage;
    _link.onConnectionChanged = _handleConnectionChanged;
    _link.onError = _handleConnectionError;
  }

  final RelayLinkService _link;
  final GeocodingService _geocoding;
  final bool enablePlatformPlugins;
  final _uuid = const Uuid();

  final FlutterTts _tts = FlutterTts();
  final SpeechToText _stt = SpeechToText();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Timer? _simTimer;
  int _simCursor = 0;
  int _demoScenarioCounter = 0;

  // ─── Cấu hình người thân & người đeo kính ────────────────────────
  String caregiverName = 'Người thân';
  String wearerName = 'Hải Đăng';
  String wearerPhone = '0901234567';
  String endpoint = 'http://192.168.1.50:8787';
  String glassEndpointForQr = 'http://secondsight.local:8765';
  String token = '';
  String routingKey = '';
  bool allowInsecure = true;
  LinkMode linkMode = LinkMode.relayServer;
  bool audibleAlerts = true;

  // ─── Trạng thái hoạt động ────────────────────────────────────────
  bool simulationMode = true;
  bool liveConnected = false;
  bool wearerOnline = true;
  String? lastError;

  /// 'idle' | 'ready' | 'navigating' | 'paused' | 'arrived'
  String navigationState = 'navigating';
  SessionRoute? activeRoute;
  LatLng? wearerPosition;
  double? gpsAccuracyM = 4.2;
  int currentStepIndex = 0;
  double remainingMeters = 420;
  int remainingSeconds = 320;
  List<LatLng> blockedLocations = <LatLng>[];

  late GlassHealth glassHealth = _initialDemoHealth();
  SosIncident? activeSos;
  final List<AssistRequest> assistRequests = <AssistRequest>[];
  final List<DestinationSuggestion> destinationHistory =
      <DestinationSuggestion>[];
  final List<SafetyEvent> safetyEvents = <SafetyEvent>[];

  // ─── Trạng thái nhận diện giọng nói trả lời nhanh ────────────────
  bool isListeningVoice = false;
  String liveTranscript = '';

  bool get isPrivacySharingActive =>
      navigationState == 'navigating' || (activeSos?.active == true);

  int get pendingAssistCount => assistRequests.where((r) => r.isPending).length;

  AssistRequest? get latestPendingAssist {
    for (final req in assistRequests) {
      if (req.isPending) return req;
    }
    return assistRequests.isNotEmpty ? assistRequests.first : null;
  }

  static const List<LatLng> _demoWalkPolyline = <LatLng>[
    LatLng(10.7575, 106.6666), // PTNK Nguyễn Chí Thanh
    LatLng(10.7579, 106.6685),
    LatLng(10.7585, 106.6708),
    LatLng(10.7594, 106.6735),
    LatLng(10.7604, 106.6762),
    LatLng(10.7613, 106.6789),
    LatLng(10.7621, 106.6808),
    LatLng(10.7626, 106.6822), // ĐH KHTN Nguyễn Văn Cừ
  ];

  static GlassHealth _initialDemoHealth() => GlassHealth(
    demo: true,
    yoloFps: 18.4,
    cpuTemp: 61.8,
    batteryPercent: 84,
    cameraOk: true,
    lidarOk: true,
    stm32Ok: true,
    stm32Calibrated: true,
    stm32Heading: 72.0,
    stm32Pitch: 1.4,
    stm32Roll: -0.8,
    updatedAt: DateTime.now(),
  );

  Future<void> init() async {
    if (enablePlatformPlugins) {
      await _loadPersistedSettings();
      await _configureTts();
    }
    if (simulationMode) {
      _seedDemoData();
      _startSimulationLoop();
    } else if (token.trim().isNotEmpty) {
      await connectLive();
    }
    _syncWakelock();
    notifyListeners();
  }

  Future<void> _loadPersistedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      caregiverName = prefs.getString('caregiver_name') ?? caregiverName;
      wearerName = prefs.getString('wearer_name') ?? wearerName;
      wearerPhone = prefs.getString('wearer_phone') ?? wearerPhone;
      endpoint = prefs.getString('endpoint') ?? endpoint;
      glassEndpointForQr =
          prefs.getString('glass_endpoint_qr') ?? glassEndpointForQr;
      allowInsecure = prefs.getBool('allow_insecure') ?? allowInsecure;
      simulationMode = prefs.getBool('simulation_mode') ?? true;
      audibleAlerts = prefs.getBool('audible_alerts') ?? true;
      final savedMode = prefs.getString('link_mode');
      if (savedMode == 'directPiBridge') {
        linkMode = LinkMode.directPiBridge;
      }

      token = (await _secureStorage.read(key: 'secondsight_token')) ?? '';
      routingKey =
          (await _secureStorage.read(key: 'secondsight_routing_key')) ?? '';
    } catch (_) {
      // Giữ cấu hình mặc định nếu môi trường không có secure storage
    }
  }

  Future<void> _configureTts() async {
    try {
      await _tts.setLanguage('vi-VN');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(0.9);
    } catch (_) {}
  }

  void _syncWakelock() {
    if (!enablePlatformPlugins) return;
    final shouldKeepAwake = isPrivacySharingActive || pendingAssistCount > 0;
    try {
      if (shouldKeepAwake) {
        WakelockPlus.enable();
      } else {
        WakelockPlus.disable();
      }
    } catch (_) {}
  }

  void _seedDemoData() {
    final now = DateTime.now();
    activeRoute = SessionRoute(
      id: 'demo-route-q5',
      destination: const PlaceLocation(
        name: 'Trạm xe buýt ĐH Khoa học Tự nhiên',
        address: '227 Nguyễn Văn Cừ, Quận 5, TP.HCM',
        point: LatLng(10.7626, 106.6822),
      ),
      points: _demoWalkPolyline,
      steps: const <RouteStep>[
        RouteStep(
          text: 'Đi thẳng theo vỉa hè đường Nguyễn Chí Thanh',
          street: 'Nguyễn Chí Thanh',
          action: 'continue',
          index: 0,
        ),
        RouteStep(
          text: 'Rẽ trái vào đường Nguyễn Văn Cừ tại ngã tư có đèn tín hiệu',
          street: 'Nguyễn Văn Cừ',
          action: 'turn_left',
          index: 3,
        ),
        RouteStep(
          text: 'Tiếp tục 180 mét tới Trạm xe buýt ĐH Khoa học Tự nhiên',
          street: 'Nguyễn Văn Cừ',
          action: 'continue',
          index: 5,
        ),
        RouteStep(
          text: 'Đã đến điểm đích an toàn',
          street: 'Nguyễn Văn Cừ',
          action: 'arrive',
          index: 7,
        ),
      ],
      distanceMeters: 1850,
      durationSeconds: 1380,
      created: now.subtract(const Duration(minutes: 4)),
      demo: true,
    );
    navigationState = 'navigating';
    _simCursor = 2;
    wearerPosition = _demoWalkPolyline[_simCursor];
    blockedLocations = const <LatLng>[LatLng(10.7598, 106.6748)];
    _recalculateDemoRemaining();

    if (assistRequests.isEmpty) {
      assistRequests.add(
        AssistRequest(
          requestId: 'demo-req-bus',
          question: 'OCR đọc bị chói nắng. Nhờ xem giúp biển trạm xe buýt phía trước có tuyến số 08 không và lối lên có vướng xe máy không?',
          contextNote:
              'Khoảng cách ToF gần nhất: 2.3 m · Hướng nhìn 72° Đông Bắc',
          position: wearerPosition,
          accuracyM: 3.8,
          sceneKind: 'bus_stop',
          tofMinM: 2.3,
          detections: const <SceneDetectionBox>[
            SceneDetectionBox(
              label: 'sign (biển báo)',
              confidence: 0.84,
              distanceM: 3.1,
              normRect: <double>[0.58, 0.14, 0.24, 0.28],
            ),
            SceneDetectionBox(
              label: 'curb_obstacle (xe đậu)',
              confidence: 0.91,
              distanceM: 2.3,
              normRect: <double>[0.12, 0.46, 0.30, 0.36],
            ),
          ],
          createdAt: now.subtract(const Duration(seconds: 40)),
        ),
      );
    }

    if (safetyEvents.isEmpty) {
      safetyEvents.addAll(<SafetyEvent>[
        SafetyEvent(
          id: 'ev-init-2',
          kind: 'obstacle_avoid',
          severity: EventSeverity.info,
          title: 'Né cục bộ vật cản vỉa hè (Cấp độ 1)',
          detail: 'Phát hiện xe máy dựng lấn vỉa hè cách 2.4 m — kính đã hướng dẫn bước chếch sang phải, không cần tính lại tuyến.',
          position: const LatLng(10.7585, 106.6708),
          distanceM: 2.4,
          avoidDirection: 'right',
          timestamp: now.subtract(const Duration(minutes: 2)),
        ),
        SafetyEvent(
          id: 'ev-init-1',
          kind: 'turn_confirmed',
          severity: EventSeverity.info,
          title: 'Đã bắt đầu hành trình có kính đồng hành',
          detail: 'Đã xác nhận kiểm tra loa kính + điện thoại (preflight pass). Đang chia sẻ vị trí theo phiên dẫn đường.',
          position: _demoWalkPolyline.first,
          timestamp: now.subtract(const Duration(minutes: 4)),
        ),
      ]);
    }
  }

  void _startSimulationLoop() {
    _simTimer?.cancel();
    _simTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!simulationMode) return;
      if (navigationState == 'navigating' && activeRoute != null) {
        _simCursor = (_simCursor + 1) % _demoWalkPolyline.length;
        final prev = wearerPosition ?? _demoWalkPolyline.first;
        final next = _demoWalkPolyline[_simCursor];
        wearerPosition = next;
        gpsAccuracyM = 3.4 + (_simCursor % 3) * 0.9;
        final heading = _simCursor == 0 ? 72.0 : bearingBetween(prev, next);
        glassHealth = glassHealth.copyWith(
          yoloFps: 17.6 + ((_simCursor % 4) * 0.5),
          cpuTemp: glassHealth.isThermalThrottling
              ? glassHealth.cpuTemp
              : 60.5 + (_simCursor % 5) * 0.9,
          batteryPercent: math.max(18, (glassHealth.batteryPercent ?? 84)),
          stm32Heading: double.parse(heading.toStringAsFixed(1)),
          updatedAt: DateTime.now(),
        );
        _recalculateDemoRemaining();
      } else {
        glassHealth = glassHealth.copyWith(updatedAt: DateTime.now());
      }
      notifyListeners();
    });
  }

  void _recalculateDemoRemaining() {
    if (activeRoute == null || wearerPosition == null) return;
    final dest = activeRoute!.destination.point;
    remainingMeters = metersBetween(wearerPosition!, dest);
    remainingSeconds = math.max(30, (remainingMeters / 1.25).round());
    if (_simCursor < 2) {
      currentStepIndex = 0;
    } else if (_simCursor < 5) {
      currentStepIndex = 1;
    } else if (_simCursor < 7) {
      currentStepIndex = 2;
    } else {
      currentStepIndex = 3;
    }
  }

  // ─── Chuyển đổi Mô phỏng <-> Kết nối thật ────────────────────────

  Future<void> setSimulationMode(bool enabled) async {
    simulationMode = enabled;
    lastError = null;
    if (enablePlatformPlugins) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('simulation_mode', enabled);
      } catch (_) {}
    }

    if (enabled) {
      _link.disconnect();
      liveConnected = false;
      wearerOnline = true;
      _seedDemoData();
      _startSimulationLoop();
    } else {
      _simTimer?.cancel();
      wearerOnline = false;
      if (token.trim().isNotEmpty) {
        await connectLive();
      }
    }
    _syncWakelock();
    notifyListeners();
  }

  Future<void> saveConnectionSettings({
    required String newCaregiverName,
    required String newWearerName,
    required String newWearerPhone,
    required String newEndpoint,
    required String newGlassEndpointQr,
    required String newToken,
    required String newRoutingKey,
    required bool newAllowInsecure,
    required LinkMode newMode,
    required bool newAudibleAlerts,
  }) async {
    caregiverName = newCaregiverName.trim().isEmpty
        ? 'Người thân'
        : newCaregiverName.trim();
    wearerName = newWearerName.trim().isEmpty
        ? 'Người đeo kính'
        : newWearerName.trim();
    wearerPhone = newWearerPhone.trim();
    endpoint = newEndpoint.trim();
    glassEndpointForQr = newGlassEndpointQr.trim();
    token = newToken.trim();
    routingKey = newRoutingKey.trim();
    allowInsecure = newAllowInsecure;
    linkMode = newMode;
    audibleAlerts = newAudibleAlerts;
    lastError = null;

    if (enablePlatformPlugins) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('caregiver_name', caregiverName);
        await prefs.setString('wearer_name', wearerName);
        await prefs.setString('wearer_phone', wearerPhone);
        await prefs.setString('endpoint', endpoint);
        await prefs.setString('glass_endpoint_qr', glassEndpointForQr);
        await prefs.setBool('allow_insecure', allowInsecure);
        await prefs.setBool('audible_alerts', audibleAlerts);
        await prefs.setString('link_mode', linkMode.name);

        await _secureStorage.write(key: 'secondsight_token', value: token);
        await _secureStorage.write(
          key: 'secondsight_routing_key',
          value: routingKey,
        );
      } catch (_) {}
    }

    notifyListeners();
  }

  Future<void> importPairingQr(String rawQr) async {
    final parsed = SecondSightPairingPayload.parse(rawQr);
    glassEndpointForQr = parsed.endpoint;
    endpoint = parsed.relayEndpoint ?? parsed.endpoint;
    token = parsed.token;
    if (parsed.routingKey != null && parsed.routingKey!.isNotEmpty) {
      routingKey = parsed.routingKey!;
    }
    allowInsecure = parsed.allowInsecure;
    if (parsed.wearerName != null && parsed.wearerName!.isNotEmpty) {
      wearerName = parsed.wearerName!;
    }
    if (parsed.wearerPhone != null && parsed.wearerPhone!.isNotEmpty) {
      wearerPhone = parsed.wearerPhone!;
    }
    linkMode = parsed.relayEndpoint != null
        ? LinkMode.relayServer
        : LinkMode.directPiBridge;

    await saveConnectionSettings(
      newCaregiverName: caregiverName,
      newWearerName: wearerName,
      newWearerPhone: wearerPhone,
      newEndpoint: endpoint,
      newGlassEndpointQr: glassEndpointForQr,
      newToken: token,
      newRoutingKey: routingKey,
      newAllowInsecure: allowInsecure,
      newMode: linkMode,
      newAudibleAlerts: audibleAlerts,
    );
  }

  SecondSightPairingPayload buildPairingPayload({bool includeRelay = true}) {
    final effectiveToken = token.trim().isNotEmpty
        ? token.trim()
        : 'ss-demo-${_uuid.v4().replaceAll('-', '')}';
    return SecondSightPairingPayload(
      endpoint: glassEndpointForQr.trim().isEmpty
          ? 'http://secondsight.local:8765'
          : glassEndpointForQr.trim(),
      token: effectiveToken,
      routingKey: routingKey.trim().isEmpty ? null : routingKey.trim(),
      allowInsecure: allowInsecure,
      relayEndpoint: includeRelay && endpoint.trim().isNotEmpty
          ? endpoint.trim()
          : null,
      wearerName: wearerName,
      wearerPhone: wearerPhone,
    );
  }

  String generateFreshToken() {
    final random = math.Random.secure();
    const alphabet =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_';
    token = List<String>.generate(
      36,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
    notifyListeners();
    return token;
  }

  Future<void> connectLive() async {
    lastError = null;
    _link
      ..endpoint = endpoint
      ..token = token
      ..allowInsecure = allowInsecure
      ..mode = linkMode;
    try {
      await _link.connect();
      final statusPath = linkMode == LinkMode.relayServer
          ? '/status'
          : '/device/status';
      final snap = await _link.getJson(statusPath);
      _handleServerMessage(snap);
    } catch (e) {
      lastError = e.toString();
      notifyListeners();
    }
  }

  void disconnectLive() {
    _link.disconnect();
    liveConnected = false;
    notifyListeners();
  }

  void _handleConnectionChanged(bool isConnected) {
    liveConnected = isConnected;
    if (isConnected) lastError = null;
    notifyListeners();
  }

  void _handleConnectionError(String err) {
    lastError = err;
    notifyListeners();
  }

  void _handleServerMessage(Map<String, dynamic> msg) {
    final type = msg['type'] as String?;
    switch (type) {
      case 'caregiver_snapshot':
        wearerOnline = msg['wearer_online'] == true;
        final nav = msg['navigation'] as Map<String, dynamic>?;
        if (nav != null) {
          navigationState = (nav['state'] as String?) ?? 'idle';
          wearerPosition = nav['position'] != null
              ? fromLonLat(nav['position'])
              : null;
          gpsAccuracyM = (nav['accuracy_m'] as num?)?.toDouble();
          currentStepIndex = (nav['step_index'] as num?)?.toInt() ?? 0;
          final routeRaw = nav['route'] as Map<String, dynamic>?;
          activeRoute = routeRaw != null
              ? SessionRoute.fromJson(routeRaw)
              : null;
        }
        final dev = msg['device_status'] as Map<String, dynamic>?;
        if (dev != null) {
          glassHealth = GlassHealth.fromJson(dev);
        }
        final sosRaw = msg['active_sos'] as Map<String, dynamic>?;
        activeSos = sosRaw != null ? SosIncident.fromJson(sosRaw) : null;

        final reqs =
            (msg['assist_requests'] as List<dynamic>?) ?? const <dynamic>[];
        assistRequests
          ..clear()
          ..addAll(
            reqs
                .whereType<Map<String, dynamic>>()
                .map(AssistRequest.fromJson)
                .toList()
                .reversed,
          );
        break;

      case 'presence_update':
        wearerOnline = msg['wearer_online'] == true;
        break;

      case 'device_status':
        wearerOnline = true;
        glassHealth = GlassHealth.fromJson(msg);
        if (glassHealth.isThermalThrottling) {
          _prependEvent(
            SafetyEvent(
              id: _uuid.v4(),
              kind: 'thermal_warning',
              severity: EventSeverity.warning,
              title: 'Cảnh báo nhiệt độ Pi 5 tăng cao',
              detail:
                  'CPU đạt ${glassHealth.cpuTemp?.toStringAsFixed(1)}°C — có nguy cơ giảm xung (thermal throttling).',
              timestamp: DateTime.now(),
            ),
          );
        }
        break;

      case 'position_update':
        if (msg['position'] != null) {
          wearerPosition = fromLonLat(msg['position']);
        }
        gpsAccuracyM = (msg['accuracy_m'] as num?)?.toDouble() ?? gpsAccuracyM;
        currentStepIndex =
            (msg['step_index'] as num?)?.toInt() ?? currentStepIndex;
        if (msg['distance_m'] is num) {
          remainingMeters = (msg['distance_m'] as num).toDouble();
        }
        break;

      case 'assist_request':
        final req = AssistRequest.fromJson(msg);
        assistRequests.removeWhere((r) => r.requestId == req.requestId);
        assistRequests.insert(0, req);
        _announceUrgent('$wearerName vừa gửi ảnh nhờ hỗ trợ: ${req.question}');
        break;

      case 'caregiver_reply':
        final reqId = msg['request_id'] as String?;
        final text = (msg['reply_text'] as String?) ?? '';
        final sender = (msg['sender_name'] as String?) ?? caregiverName;
        if (reqId != null) {
          _updateLocalReply(reqId, text, sender);
        }
        break;

      case 'sos_alert':
        activeSos = SosIncident.fromJson(msg);
        _prependEvent(
          SafetyEvent(
            id: activeSos!.sosId,
            kind: 'sos_alert',
            severity: EventSeverity.critical,
            title: 'TÍN HIỆU KHẨN CẤP SOS',
            detail: activeSos!.message,
            position: activeSos!.position,
            timestamp: activeSos!.createdAt,
          ),
        );
        _announceUrgent(
          'Khẩn cấp! $wearerName vừa kích hoạt SOS: ${activeSos!.message}',
        );
        break;

      case 'sos_resolved':
        if (activeSos != null) {
          activeSos = activeSos!.resolve(
            (msg['resolved_by'] as String?) ?? caregiverName,
          );
        }
        break;

      case 'obstacle_avoid':
        _prependEvent(
          SafetyEvent(
            id: _uuid.v4(),
            kind: 'obstacle_avoid',
            severity: EventSeverity.info,
            title: 'Né vật cản cục bộ (Cấp độ 1)',
            detail:
                (msg['message'] as String?) ??
                'Kính hướng dẫn bước né nhẹ trên vỉa hè.',
            position: wearerPosition,
            distanceM: (msg['distance_m'] as num?)?.toDouble(),
            avoidDirection: msg['avoid_direction'] as String?,
            timestamp: DateTime.now(),
          ),
        );
        break;

      case 'path_blocked':
        if (wearerPosition != null) {
          blockedLocations = <LatLng>[...blockedLocations, wearerPosition!];
        }
        _prependEvent(
          SafetyEvent(
            id: _uuid.v4(),
            kind: 'path_blocked',
            severity: EventSeverity.warning,
            title: 'Lối đi bị chặn hoàn toàn (Cấp độ 2)',
            detail:
                (msg['message'] as String?) ??
                'Đang tự động tính lại lộ trình mới qua GraphHopper.',
            position: wearerPosition,
            distanceM: (msg['distance_m'] as num?)?.toDouble(),
            timestamp: DateTime.now(),
          ),
        );
        break;

      case 'hazard':
        _prependEvent(
          SafetyEvent(
            id: (msg['hazard_id'] as String?) ?? _uuid.v4(),
            kind: 'hazard',
            severity: EventSeverity.critical,
            title:
                'Cảnh báo nguy hiểm gần (${msg['hazard_class'] ?? 'vật cản'})',
            detail:
                (msg['message'] as String?) ??
                'Phát hiện nguy cơ sát phía trước.',
            position: wearerPosition,
            distanceM: (msg['distance_m'] as num?)?.toDouble(),
            timestamp: DateTime.now(),
          ),
        );
        break;

      case 'destination_suggestion':
        final sug = DestinationSuggestion.fromJson(msg);
        destinationHistory.removeWhere(
          (d) => d.suggestionId == sug.suggestionId,
        );
        destinationHistory.insert(0, sug);
        break;
    }
    _syncWakelock();
    notifyListeners();
  }

  void _prependEvent(SafetyEvent event) {
    safetyEvents.insert(0, event);
    if (safetyEvents.length > 80) {
      safetyEvents.removeRange(80, safetyEvents.length);
    }
  }

  void _announceUrgent(String speechText) {
    if (!enablePlatformPlugins) return;
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
    if (audibleAlerts) {
      try {
        _tts.speak(speechText);
      } catch (_) {}
    }
  }

  // ─── Thao tác của Người thân (Caregiver Actions) ──────────────────

  Future<void> replyToAssistRequest(String requestId, String replyText) async {
    final clean = replyText.trim();
    if (clean.isEmpty) return;

    if (!simulationMode && liveConnected && linkMode == LinkMode.relayServer) {
      await _link.postJson('/assist/reply', <String, dynamic>{
        'request_id': requestId,
        'reply_text': clean,
        'sender_name': caregiverName,
        'speak_immediately': true,
      });
    }
    _updateLocalReply(requestId, clean, caregiverName);
    _prependEvent(
      SafetyEvent(
        id: _uuid.v4(),
        kind: 'caregiver_reply',
        severity: EventSeverity.info,
        title: 'Đã gửi chỉ dẫn giọng nói vào tai nghe kính',
        detail: '"$clean"',
        position: wearerPosition,
        timestamp: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void _updateLocalReply(String requestId, String text, String sender) {
    final idx = assistRequests.indexWhere((r) => r.requestId == requestId);
    if (idx >= 0) {
      assistRequests[idx] = assistRequests[idx].markReplied(
        text: text,
        sender: sender,
      );
    }
    _syncWakelock();
  }

  Future<void> resolveActiveSos() async {
    if (activeSos == null) return;
    if (!simulationMode && liveConnected && linkMode == LinkMode.relayServer) {
      try {
        await _link.postJson('/sos/resolve', <String, dynamic>{
          'sos_id': activeSos!.sosId,
          'resolved_by': caregiverName,
        });
      } catch (_) {}
    }
    activeSos = activeSos!.resolve(caregiverName);
    _prependEvent(
      SafetyEvent(
        id: _uuid.v4(),
        kind: 'sos_resolved',
        severity: EventSeverity.info,
        title: 'Đã xác nhận xử lý SOS',
        detail: '$caregiverName đã đánh dấu an toàn cho $wearerName.',
        position: wearerPosition,
        timestamp: DateTime.now(),
      ),
    );
    _syncWakelock();
    notifyListeners();
  }

  Future<List<PlaceLocation>> searchPlaces(String query) =>
      _geocoding.searchPlaces(
        query,
        graphHopperKey: routingKey.isEmpty ? null : routingKey,
      );

  Future<DestinationSuggestion> sendDestinationToWearer(
    PlaceLocation place, {
    String note = '',
  }) async {
    final suggestion = DestinationSuggestion(
      suggestionId: _uuid.v4(),
      name: place.name,
      address: place.address,
      point: place.point,
      note: note.trim(),
      senderName: caregiverName,
      createdAt: DateTime.now(),
    );

    if (!simulationMode && liveConnected && linkMode == LinkMode.relayServer) {
      await _link.postJson('/destination/suggest', <String, dynamic>{
        'suggestion_id': suggestion.suggestionId,
        'name': suggestion.name,
        'address': suggestion.address,
        'point': toLonLat(suggestion.point),
        'note': suggestion.note,
        'sender_name': caregiverName,
      });
    }

    destinationHistory.insert(0, suggestion);
    _prependEvent(
      SafetyEvent(
        id: _uuid.v4(),
        kind: 'destination_pushed',
        severity: EventSeverity.info,
        title: 'Đã gửi gợi ý điểm đến sang ứng dụng kính',
        detail:
            '${place.name} — đang chờ $wearerName xác nhận bằng giọng nói ("Có").',
        position: place.point,
        timestamp: DateTime.now(),
      ),
    );

    // Trong chế độ mô phỏng, giả lập người khiếm thị xác nhận "Có" sau 2 giây
    if (simulationMode) {
      Timer(const Duration(seconds: 2), () {
        final idx = destinationHistory.indexWhere(
          (d) => d.suggestionId == suggestion.suggestionId,
        );
        if (idx >= 0) {
          destinationHistory[idx] = destinationHistory[idx].copyWith(
            status: 'accepted',
          );
          if (activeRoute != null) {
            final start = wearerPosition ?? _demoWalkPolyline.first;
            final mid = LatLng(
              (start.latitude + place.point.latitude) / 2,
              (start.longitude + place.point.longitude) / 2,
            );
            activeRoute = SessionRoute(
              id: 'route-${suggestion.suggestionId.substring(0, 6)}',
              destination: place,
              points: <LatLng>[start, mid, place.point],
              steps: <RouteStep>[
                const RouteStep(
                  text: 'Xuất phát từ vị trí hiện tại theo vỉa hè',
                  street: 'Lộ trình mới',
                  action: 'continue',
                  index: 0,
                ),
                RouteStep(
                  text: 'Hướng về ${place.name}',
                  street: place.address,
                  action: 'arrive',
                  index: 2,
                ),
              ],
              distanceMeters: metersBetween(start, place.point),
              durationSeconds: math
                  .max(60, (metersBetween(start, place.point) / 1.2).round())
                  .toDouble(),
              created: DateTime.now(),
              demo: true,
            );
            navigationState = 'navigating';
            _recalculateDemoRemaining();
          }
          notifyListeners();
        }
      });
    }

    notifyListeners();
    return suggestion;
  }

  // ─── Nhập giọng nói (Push-to-Talk) cho người thân ─────────────────

  Future<void> toggleVoiceDictation(
    void Function(String recognized) onResultText,
  ) async {
    if (!enablePlatformPlugins) return;
    if (isListeningVoice) {
      await _stt.stop();
      isListeningVoice = false;
      notifyListeners();
      return;
    }
    try {
      final available = await _stt.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            isListeningVoice = false;
            notifyListeners();
          }
        },
        onError: (_) {
          isListeningVoice = false;
          notifyListeners();
        },
      );
      if (!available) {
        lastError = 'Thiết bị chưa cấp quyền micro hoặc dịch vụ nhận dạng giọng nói không khả dụng.';
        notifyListeners();
        return;
      }
      isListeningVoice = true;
      liveTranscript = '';
      notifyListeners();
      await _stt.listen(
        listenOptions: SpeechListenOptions(
          localeId: 'vi_VN',
          listenFor: const Duration(seconds: 15),
          pauseFor: const Duration(seconds: 3),
        ),
        onResult: (result) {
          liveTranscript = result.recognizedWords;
          onResultText(liveTranscript);
          notifyListeners();
        },
      );
    } catch (e) {
      isListeningVoice = false;
      lastError = 'Không thể bật micro: $e';
      notifyListeners();
    }
  }

  // ─── Các kịch bản Demo trực quan cho Hội đồng giám khảo ──────────

  void toggleDemoPrivacyState() {
    if (!simulationMode) return;
    if (navigationState == 'navigating') {
      navigationState = 'idle';
      _prependEvent(
        SafetyEvent(
          id: _uuid.v4(),
          kind: 'privacy_mode',
          severity: EventSeverity.info,
          title: 'Đã kết thúc hành trình — bật màn chắn riêng tư',
          detail: 'Vị trí GPS tự động ẩn khỏi màn hình người thân khi người dùng ở trạng thái nghỉ (idle).',
          timestamp: DateTime.now(),
        ),
      );
    } else {
      navigationState = 'navigating';
      wearerPosition ??= _demoWalkPolyline[_simCursor];
    }
    _syncWakelock();
    notifyListeners();
  }

  void triggerDemoAssistSnapshot() {
    _demoScenarioCounter = (_demoScenarioCounter + 1) % 3;
    final now = DateTime.now();
    final pos = wearerPosition ?? _demoWalkPolyline.first;

    final AssistRequest req = switch (_demoScenarioCounter) {
      1 => AssistRequest(
        requestId: 'demo-cross-${now.millisecondsSinceEpoch}',
        question: 'Ngã tư Nguyễn Văn Cừ đông xe quá, AI báo chưa chắc chắn. Đèn đi bộ phía trước đang xanh hay đỏ vậy?',
        contextNote: 'Chế độ CROSS_OBSERVE · ToF gần nhất: 3.4 m · 4 xe trong khung hình',
        position: pos,
        accuracyM: 4.1,
        sceneKind: 'crosswalk',
        tofMinM: 3.4,
        detections: const <SceneDetectionBox>[
          SceneDetectionBox(
            label: 'vehicle (xe máy)',
            confidence: 0.89,
            distanceM: 4.2,
            normRect: <double>[0.18, 0.44, 0.28, 0.30],
          ),
          SceneDetectionBox(
            label: 'zebra_crossing',
            confidence: 0.78,
            distanceM: 3.4,
            normRect: <double>[0.15, 0.72, 0.70, 0.20],
          ),
        ],
        createdAt: now,
      ),
      2 => AssistRequest(
        requestId: 'demo-work-${now.millisecondsSinceEpoch}',
        question: 'Vỉa hè phía trước có rào tôn công trình. Mình lách bên trái sát tường được không hay phải quay lại?',
        contextNote:
            'Cảnh báo path_blocked · ToF báo tường chắn 1.8 m phía trước',
        position: pos,
        accuracyM: 3.5,
        sceneKind: 'construction',
        tofMinM: 1.8,
        detections: const <SceneDetectionBox>[
          SceneDetectionBox(
            label: 'street_obstacle (rào chắn)',
            confidence: 0.94,
            distanceM: 1.8,
            normRect: <double>[0.22, 0.30, 0.56, 0.52],
          ),
        ],
        createdAt: now,
      ),
      _ => AssistRequest(
        requestId: 'demo-bus-${now.millisecondsSinceEpoch}',
        question: 'Biển hiệu trước mặt bị ngược sáng VietOCR không đọc rõ. Đây có phải cổng Phòng khám Đa khoa không?',
        contextNote:
            'Nút nhấn ngắn BTN_OCR chuyển tiếp · Khoảng cách ToF: 2.6 m',
        position: pos,
        accuracyM: 3.9,
        sceneKind: 'bus_stop',
        tofMinM: 2.6,
        detections: const <SceneDetectionBox>[
          SceneDetectionBox(
            label: 'sign (biển hiệu)',
            confidence: 0.82,
            distanceM: 2.6,
            normRect: <double>[0.32, 0.16, 0.38, 0.26],
          ),
        ],
        createdAt: now,
      ),
    };

    assistRequests.insert(0, req);
    _announceUrgent('$wearerName vừa gửi ảnh nhờ kiểm tra phía trước.');
    _syncWakelock();
    notifyListeners();
  }

  void triggerDemoSos() {
    final pos = wearerPosition ?? const LatLng(10.7604, 106.6762);
    activeSos = SosIncident(
      sosId: 'sos-${DateTime.now().millisecondsSinceEpoch}',
      trigger: 'Câu lệnh "Aurelia, cứu tôi" + giữ nút kính',
      message:
          '$wearerName báo cần hỗ trợ khẩn cấp tại vỉa hè Nguyễn Văn Cừ (đã đính kèm ảnh camera IMX708 mới nhất).',
      position: pos,
      accuracyM: 3.6,
      sceneKind: 'sos_street',
      batteryPercent: glassHealth.batteryPercent ?? 78,
      createdAt: DateTime.now(),
    );
    _prependEvent(
      SafetyEvent(
        id: activeSos!.sosId,
        kind: 'sos_alert',
        severity: EventSeverity.critical,
        title: 'KHẨN CẤP: Kích hoạt SOS kèm ảnh hiện trường',
        detail: activeSos!.message,
        position: pos,
        timestamp: activeSos!.createdAt,
      ),
    );
    _announceUrgent('Cảnh báo khẩn cấp! $wearerName vừa kích hoạt SOS.');
    _syncWakelock();
    notifyListeners();
  }

  void triggerDemoAnomaly(String anomalyType) {
    final now = DateTime.now();
    final pos = wearerPosition ?? _demoWalkPolyline.first;
    switch (anomalyType) {
      case 'imu_fall':
        glassHealth = glassHealth.copyWith(
          stm32Pitch: 68.5,
          stm32Roll: -54.2,
          updatedAt: now,
        );
        _prependEvent(
          SafetyEvent(
            id: _uuid.v4(),
            kind: 'imu_fall_suspected',
            severity: EventSeverity.critical,
            title: 'Phát hiện nghiêng đột ngột trên IMU STM32 (Nghi rơi kính / té ngã)',
            detail: 'Pitch 68.5° / Roll -54.2° kết hợp vận tốc GPS = 0 m/s quá 15 giây.',
            position: pos,
            timestamp: now,
          ),
        );
        _announceUrgent(
          'Cảnh báo! Cảm biến kính của $wearerName ghi nhận va chạm hoặc rơi kính.',
        );
        break;
      case 'thermal':
        glassHealth = glassHealth.copyWith(
          cpuTemp: 79.4,
          yoloFps: 9.2,
          updatedAt: now,
        );
        _prependEvent(
          SafetyEvent(
            id: _uuid.v4(),
            kind: 'thermal_warning',
            severity: EventSeverity.warning,
            title: 'Raspberry Pi 5 quá nhiệt (79.4°C) — giảm tốc YOLO',
            detail: 'Tốc độ nhận diện giảm còn 9.2 FPS do thermal throttling. Nên nhắc người dùng tạm nghỉ nơi râm mát.',
            position: pos,
            timestamp: now,
          ),
        );
        break;
      default:
        _prependEvent(
          SafetyEvent(
            id: _uuid.v4(),
            kind: 'off_route_prolonged',
            severity: EventSeverity.warning,
            title: 'Đi lệch tuyến quá 3 phút chưa quay lại lộ trình',
            detail: 'Khoảng cách lệch > 42 m sau 2 lần tính lại tuyến. Gợi ý gửi lại điểm đến hoặc gọi kiểm tra.',
            position: pos,
            timestamp: now,
          ),
        );
    }
    notifyListeners();
  }

  void resetDemoHardwareNormal() {
    glassHealth = _initialDemoHealth();
    notifyListeners();
  }

  @override
  void dispose() {
    _simTimer?.cancel();
    _link.dispose();
    _geocoding.dispose();
    if (enablePlatformPlugins) {
      try {
        _tts.stop();
        _stt.stop();
        WakelockPlus.disable();
      } catch (_) {}
    }
    super.dispose();
  }
}
