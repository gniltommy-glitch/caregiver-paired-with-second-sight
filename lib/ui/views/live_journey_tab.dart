import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/models/caregiver_models.dart';
import '../core/caregiver_theme.dart';
import '../view_models/caregiver_view_model.dart';
import '../widgets/camera_scene_preview.dart';

class LiveJourneyTab extends StatefulWidget {
  final CaregiverViewModel vm;
  final VoidCallback onOpenAssistTab;
  final VoidCallback onOpenPairingTab;

  const LiveJourneyTab({
    super.key,
    required this.vm,
    required this.onOpenAssistTab,
    required this.onOpenPairingTab,
  });

  @override
  State<LiveJourneyTab> createState() => _LiveJourneyTabState();
}

class _LiveJourneyTabState extends State<LiveJourneyTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  List<PlaceLocation> _searchResults = const <PlaceLocation>[];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _loadInitialPlaces();
  }

  Future<void> _loadInitialPlaces() async {
    final results = await widget.vm.searchPlaces('');
    if (mounted) {
      setState(() => _searchResults = results);
    }
  }

  Future<void> _runSearch(String q) async {
    setState(() => _searching = true);
    final results = await widget.vm.searchPlaces(q);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    }
  }

  Future<void> _callWearer() async {
    final phone = widget.vm.wearerPhone.trim();
    if (phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    await launchUrl(uri);
  }

  Future<void> _shareSosLocation(SosIncident sos) async {
    final lat = sos.position.latitude.toStringAsFixed(6);
    final lng = sos.position.longitude.toStringAsFixed(6);
    final mapsUrl = 'https://maps.google.com/?q=$lat,$lng';
    await SharePlus.instance.share(
      ShareParams(
        text:
            '[KHẨN CẤP - SecondSight] ${widget.vm.wearerName} cần hỗ trợ!\n'
            'Thông điệp: ${sos.message}\n'
            'Vị trí: $lat, $lng (±${sos.accuracyM.toStringAsFixed(1)} m)\n'
            'Bản đồ: $mapsUrl',
      ),
    );
  }

  Future<void> _confirmPushDestination(PlaceLocation place) async {
    final sent = await widget.vm.sendDestinationToWearer(
      place,
      note: _noteCtrl.text,
    );
    if (!mounted) return;
    _noteCtrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: kCard2,
        content: Text(
          'Đã gửi "${sent.name}" tới kính của ${widget.vm.wearerName} (chờ xác nhận giọng nói).',
          style: const TextStyle(color: kText),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final sos = vm.activeSos;
    final hasActiveSos = sos != null && sos.active;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: <Widget>[
        _buildHeroCard(vm),
        if (vm.simulationMode) ...<Widget>[
          const SizedBox(height: 12),
          _buildSimulationQuickBar(vm),
        ],
        if (hasActiveSos) ...<Widget>[
          const SizedBox(height: 14),
          _buildEmergencySosCard(sos),
        ],
        if (vm.pendingAssistCount > 0) ...<Widget>[
          const SizedBox(height: 14),
          _buildPendingAssistCallout(vm),
        ],
        const SizedBox(height: 16),
        _buildSessionMapSection(vm),
        const SizedBox(height: 18),
        _buildRemoteDestinationCard(vm),
      ],
    );
  }

  Widget _buildHeroCard(CaregiverViewModel vm) {
    final activeNav = vm.navigationState == 'navigating';
    return SpotlightCard(
      accentColor: vm.activeSos?.active == true ? kDanger : kAccentSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              StatusPill(
                label: vm.simulationMode
                    ? 'CHẾ ĐỘ MÔ PHỎNG'
                    : (vm.liveConnected
                          ? 'ĐÃ KẾT NỐI TRỰC TIẾP'
                          : 'MẤT KẾT NỐI'),
                color: vm.simulationMode
                    ? kWarning
                    : (vm.liveConnected ? kAccent : kDanger),
                icon: vm.simulationMode
                    ? Icons.science_outlined
                    : (vm.liveConnected
                          ? Icons.cloud_done_outlined
                          : Icons.cloud_off),
              ),
              StatusPill(
                label: activeNav ? 'ĐANG DẪN ĐƯỜNG' : 'NGHỈ · RIÊNG TƯ',
                color: activeNav ? kAccent : kAccent2,
                icon: activeNav
                    ? Icons.directions_walk
                    : Icons.shield_moon_outlined,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            activeNav
                ? 'Đồng hành cùng ${vm.wearerName}'
                : '${vm.wearerName} đang ở trạng thái nghỉ',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            activeNav && vm.activeRoute != null
                ? 'Đích đến: ${vm.activeRoute!.destination.name} · '
                      'Còn ${vm.remainingMeters.round()} m (~${(vm.remainingSeconds / 60).ceil()} phút đi bộ)'
                : 'SecondSight bảo vệ quyền tự chủ của người khiếm thị: chỉ chia sẻ vị trí trực tiếp khi đang bật dẫn đường hoặc có tín hiệu SOS.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: vm.wearerPhone.trim().isEmpty ? null : _callWearer,
                  icon: const Icon(Icons.phone_in_talk_outlined, size: 18),
                  label: Text('Gọi ${vm.wearerName}'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: widget.onOpenPairingTab,
                  style: FilledButton.styleFrom(
                    backgroundColor: kCard2,
                    foregroundColor: kAccent,
                  ),
                  icon: const Icon(Icons.qr_code_2_rounded, size: 19),
                  label: const Text('Mã QR kính'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimulationQuickBar(CaregiverViewModel vm) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kWarning.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.bolt_rounded, size: 16, color: kWarning),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Bảng thử nhanh kịch bản Demo (không cần kính thật)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kWarning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              ActionChip(
                avatar: const Icon(
                  Icons.add_a_photo_outlined,
                  size: 16,
                  color: kAccent,
                ),
                label: const Text('Giả lập gửi ảnh hỏi'),
                onPressed: () {
                  vm.triggerDemoAssistSnapshot();
                  widget.onOpenAssistTab();
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.sos_rounded, size: 16, color: kDanger),
                label: const Text('Giả lập SOS khẩn'),
                onPressed: vm.triggerDemoSos,
              ),
              ActionChip(
                avatar: Icon(
                  vm.navigationState == 'navigating'
                      ? Icons.visibility_off_outlined
                      : Icons.directions_walk,
                  size: 16,
                  color: kAccent2,
                ),
                label: Text(
                  vm.navigationState == 'navigating'
                      ? 'Thử kết thúc đi (ẩn GPS)'
                      : 'Tiếp tục dẫn đường',
                ),
                onPressed: vm.toggleDemoPrivacyState,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencySosCard(SosIncident sos) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF281219),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kDanger, width: 1.6),
        boxShadow: <BoxShadow>[
          BoxShadow(color: kDanger.withValues(alpha: 0.22), blurRadius: 24),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.warning_amber_rounded, color: kDanger, size: 24),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'TÍN HIỆU SOS ĐANG KÍCH HOẠT',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: kDanger,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              Text(
                formatRelativeTime(sos.createdAt),
                style: const TextStyle(fontSize: 12, color: kTextSub),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(sos.message, style: const TextStyle(color: kText, fontSize: 14)),
          const SizedBox(height: 6),
          Text(
            'Nguồn kích hoạt: ${sos.trigger} · Sai số GPS ±${sos.accuracyM.toStringAsFixed(1)} m'
            '${sos.batteryPercent != null ? ' · Pin kính ${sos.batteryPercent}%' : ''}',
            style: const TextStyle(fontSize: 12, color: kTextSub),
          ),
          const SizedBox(height: 12),
          CameraScenePreview(
            capturedAt: sos.createdAt,
            imageBase64: sos.imageBase64,
            sceneKind: sos.sceneKind,
            height: 165,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: kDanger,
                  foregroundColor: Colors.white,
                ),
                onPressed: _callWearer,
                icon: const Icon(Icons.call, size: 18),
                label: const Text('Gọi khẩn cấp'),
              ),
              OutlinedButton.icon(
                onPressed: () => _shareSosLocation(sos),
                icon: const Icon(Icons.share_location_outlined, size: 18),
                label: const Text('Chia sẻ vị trí'),
              ),
              TextButton.icon(
                onPressed: widget.vm.resolveActiveSos,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Đánh dấu đã an toàn'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingAssistCallout(CaregiverViewModel vm) {
    final latest = vm.latestPendingAssist;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: widget.onOpenAssistTab,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kAccent2.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kAccent2.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.mark_chat_unread_rounded, color: kAccent2),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Có ${vm.pendingAssistCount} ảnh mới cần bạn xem giúp',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: kText,
                    ),
                  ),
                  if (latest != null)
                    Text(
                      latest.question,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: kTextSub),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: kAccent2),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionMapSection(CaregiverViewModel vm) {
    if (!vm.isPrivacySharingActive) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kBorder),
        ),
        child: Column(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kAccent2.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shield_moon_outlined,
                size: 32,
                color: kAccent2,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Màn chắn riêng tư đang bật',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: kText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Khi ${vm.wearerName} không mở phiên dẫn đường và không có cảnh báo khẩn cấp, tọa độ GPS được ẩn tự động để không biến ứng dụng thành công cụ giám sát 24/7.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: kTextSub),
            ),
          ],
        ),
      );
    }

    final center = vm.wearerPosition ?? const LatLng(10.7594, 106.6735);
    final routePoints = vm.activeRoute?.points ?? const <LatLng>[];
    final currentStep =
        (vm.activeRoute != null &&
            vm.currentStepIndex < vm.activeRoute!.steps.length)
        ? vm.activeRoute!.steps[vm.currentStepIndex]
        : null;

    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            height: 270,
            child: Stack(
              children: <Widget>[
                FlutterMap(
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 15.6,
                    onLongPress: (_, latLng) {
                      _confirmPushDestination(
                        PlaceLocation(
                          name:
                              'Điểm ghim (${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)})',
                          address: 'Đã chọn trực tiếp trên bản đồ người thân',
                          point: latLng,
                        ),
                      );
                    },
                  ),
                  children: <Widget>[
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'vn.secondsight.caregiver',
                    ),
                    if (routePoints.length >= 2)
                      PolylineLayer(
                        polylines: <Polyline>[
                          Polyline(
                            points: routePoints,
                            strokeWidth: 5,
                            color: kAccent,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: <Marker>[
                        // Điểm bị chặn (path_blocked)
                        for (final blocked in vm.blockedLocations)
                          Marker(
                            point: blocked,
                            width: 34,
                            height: 34,
                            child: Tooltip(
                              message: 'Vỉa hè bị chặn (path_blocked)',
                              child: Container(
                                decoration: BoxDecoration(
                                  color: kWarning,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: kBg, width: 2),
                                ),
                                child: const Icon(
                                  Icons.construction_rounded,
                                  size: 18,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                        // Đích đến
                        if (vm.activeRoute != null)
                          Marker(
                            point: vm.activeRoute!.destination.point,
                            width: 38,
                            height: 38,
                            child: Container(
                              decoration: BoxDecoration(
                                color: kAccent2,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.flag_rounded,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        // Vị trí hiện tại của người đeo kính
                        if (vm.wearerPosition != null)
                          Marker(
                            point: vm.wearerPosition!,
                            width: 46,
                            height: 46,
                            child: Container(
                              decoration: BoxDecoration(
                                color: kAccent.withValues(alpha: 0.25),
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(7),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: kAccent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: kBg, width: 2.5),
                                ),
                                child: const Icon(
                                  Icons.person_pin_circle_rounded,
                                  size: 19,
                                  color: Color(0xFF001A14),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  right: 8,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xCC0D1117),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '© OpenStreetMap · Nhấn giữ bản đồ để gửi điểm đến',
                      style: TextStyle(fontSize: 10, color: kTextSub),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kAccent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.turn_left_rounded, color: kAccent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        currentStep?.text ?? 'Đang đi theo lộ trình đi bộ',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: kText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'GPS ±${(vm.gpsAccuracyM ?? 4.0).toStringAsFixed(1)} m · '
                        'Hướng kính ${(vm.glassHealth.stm32Heading ?? 0).round()}°',
                        style: const TextStyle(fontSize: 12, color: kTextSub),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemoteDestinationCard(CaregiverViewModel vm) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.send_to_mobile_rounded, color: kAccent, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Đặt điểm đến hộ từ xa (Remote Assist)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: kText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Khi ngoài đường quá ồn khiến nhận diện giọng nói khó nghe tên đường, bạn có thể chọn điểm đến và gửi sang kính. ${vm.wearerName} chỉ cần nói "Có" để bắt đầu đi.',
            style: const TextStyle(fontSize: 12.5, color: kTextSub),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            onSubmitted: _runSearch,
            decoration: InputDecoration(
              hintText: 'Tìm địa chỉ, bệnh viện, trạm xe buýt...',
              prefixIcon: const Icon(Icons.search_rounded, color: kTextSub),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(
                        Icons.arrow_forward_rounded,
                        color: kAccent,
                      ),
                      onPressed: () => _runSearch(_searchCtrl.text),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(
              hintText:
                  'Lời nhắn đọc kèm (tùy chọn, VD: cổng Nguyễn Chí Thanh)',
              prefixIcon: Icon(
                Icons.record_voice_over_outlined,
                color: kTextSub,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ..._searchResults
              .take(4)
              .map(
                (place) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: kCard2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: kBorder),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 2,
                      ),
                      leading: const Icon(Icons.place_outlined, color: kAccent),
                      title: Text(
                        place.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: kText,
                        ),
                      ),
                      subtitle: place.address.isEmpty
                          ? null
                          : Text(
                              place.address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: kTextSub,
                              ),
                            ),
                      trailing: FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(64, 38),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          backgroundColor: kAccent.withValues(alpha: 0.16),
                          foregroundColor: kAccent,
                        ),
                        onPressed: () => _confirmPushDestination(place),
                        child: const Text('Gửi'),
                      ),
                    ),
                  ),
                ),
              ),
          if (vm.destinationHistory.isNotEmpty) ...<Widget>[
            const Divider(color: kBorder, height: 22),
            const Text(
              'Điểm đến vừa gửi gần đây',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: kTextSub,
              ),
            ),
            const SizedBox(height: 8),
            ...vm.destinationHistory
                .take(2)
                .map(
                  (d) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          d.status == 'accepted'
                              ? Icons.check_circle_rounded
                              : Icons.schedule_rounded,
                          size: 16,
                          color: d.status == 'accepted' ? kAccent : kWarning,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            d.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, color: kText),
                          ),
                        ),
                        Text(
                          d.status == 'accepted'
                              ? 'Đã xác nhận "Có"'
                              : 'Chờ xác nhận...',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: d.status == 'accepted' ? kAccent : kWarning,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}
