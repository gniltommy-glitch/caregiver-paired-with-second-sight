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
    await launchUrl(Uri(scheme: 'tel', path: phone));
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
        behavior: SnackBarBehavior.floating,
        backgroundColor: kInk,
        content: Text(
          'Đã gửi "${sent.name}" tới máy của ${widget.vm.wearerName}.',
          style: const TextStyle(color: Colors.white),
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
      padding: EdgeInsets.zero,
      children: <Widget>[
        if (hasActiveSos)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: _buildEmergencySosCard(sos),
          ),

        // Bản đồ tràn viền kiểu Apple Find My / Grab hoặc Màn chắn riêng tư
        if (vm.isPrivacySharingActive)
          _buildFullBleedLiveMap(vm)
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _buildPrivacyCurtainCard(vm),
          ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (vm.pendingAssistCount > 0) ...<Widget>[
                _buildUnreadAssistBanner(vm),
                const SizedBox(height: 16),
              ],
              _buildJourneySummaryCard(vm),
              const SizedBox(height: 20),
              _buildRemoteDestinationSection(vm),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFullBleedLiveMap(CaregiverViewModel vm) {
    final center = vm.wearerPosition ?? const LatLng(10.7594, 106.6735);
    final routePoints = vm.activeRoute?.points ?? const <LatLng>[];
    final etaMin = (vm.remainingSeconds / 60).ceil();

    return SizedBox(
      height: 315,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: 15.5,
              onLongPress: (_, latLng) {
                _confirmPushDestination(
                  PlaceLocation(
                    name:
                        'Điểm đã ghim (${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)})',
                    address: 'Chọn trực tiếp trên bản đồ',
                    point: latLng,
                  ),
                );
              },
            ),
            children: <Widget>[
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'vn.secondsight.caregiver',
              ),
              if (routePoints.length >= 2)
                PolylineLayer(
                  polylines: <Polyline>[
                    Polyline(
                      points: routePoints,
                      strokeWidth: 5,
                      color: kPrimary,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: <Marker>[
                  for (final blocked in vm.blockedLocations)
                    Marker(
                      point: blocked,
                      width: 34,
                      height: 34,
                      child: Tooltip(
                        message: 'Vỉa hè bị chặn (path_blocked)',
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: kCardShadow,
                          ),
                          child: const Icon(
                            Icons.construction_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  if (vm.activeRoute != null)
                    Marker(
                      point: vm.activeRoute!.destination.point,
                      width: 36,
                      height: 36,
                      child: Container(
                        decoration: BoxDecoration(
                          color: kInk,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: kCardShadow,
                        ),
                        child: const Icon(
                          Icons.flag_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  if (vm.wearerPosition != null)
                    Marker(
                      point: vm.wearerPosition!,
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: kPrimary.withValues(alpha: 0.20),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(7),
                        child: Container(
                          decoration: BoxDecoration(
                            color: kPrimary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: kCardShadow,
                          ),
                          child: const Icon(
                            Icons.directions_walk_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Thẻ trạng thái nổi gọn gàng trên bản đồ
          Positioned(
            left: 14,
            top: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(999),
                boxShadow: kCardShadow,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: kSuccess,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Đang đi bộ · Còn ${vm.remainingMeters.round()} m (~$etaMin phút)',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: kInk,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Nút gọi nhanh nổi ở góc bản đồ
          Positioned(
            right: 14,
            bottom: 14,
            child: FloatingActionButton.small(
              heroTag: 'call_wearer_fab',
              backgroundColor: kSurface,
              foregroundColor: kPrimary,
              elevation: 3,
              tooltip: 'Gọi ${vm.wearerName}',
              onPressed: vm.wearerPhone.trim().isEmpty ? null : _callWearer,
              child: const Icon(Icons.phone_in_talk_rounded, size: 20),
            ),
          ),

          // Ghi chú nguồn bản đồ OSM tinh gọn
          Positioned(
            left: 12,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '© OpenStreetMap · Nhấn giữ bản đồ để gửi điểm đến',
                style: TextStyle(fontSize: 10.5, color: kInkSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyCurtainCard(CaregiverViewModel vm) {
    return SurfaceCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: kPrimarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              size: 28,
              color: kPrimary,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Màn chắn riêng tư đang bật',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: kInk,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${vm.wearerName} hiện đang ở trạng thái nghỉ. Để tôn trọng quyền tự chủ, vị trí GPS chỉ hiển thị khi đang bật dẫn đường hoặc có tín hiệu khẩn cấp SOS.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, color: kInkSecondary),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: vm.wearerPhone.trim().isEmpty ? null : _callWearer,
                  icon: const Icon(Icons.phone_outlined, size: 18),
                  label: Text('Gọi ${vm.wearerName}'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: widget.onOpenPairingTab,
                  icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                  label: const Text('Mã QR kính'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencySosCard(SosIncident sos) {
    return SurfaceCard(
      color: kDangerSoft,
      borderColor: kDanger.withValues(alpha: 0.45),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.warning_rounded, color: kDanger, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Cảnh báo khẩn cấp SOS',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: kDanger,
                  ),
                ),
              ),
              Text(
                formatRelativeTime(sos.createdAt),
                style: const TextStyle(fontSize: 12, color: kInkSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(sos.message, style: const TextStyle(fontSize: 14, color: kInk)),
          const SizedBox(height: 4),
          Text(
            'Sai số GPS ±${sos.accuracyM.toStringAsFixed(1)} m'
            '${sos.batteryPercent != null ? ' · Pin kính ${sos.batteryPercent}%' : ''}',
            style: const TextStyle(fontSize: 12.5, color: kInkSecondary),
          ),
          const SizedBox(height: 12),
          CameraScenePreview(
            capturedAt: sos.createdAt,
            imageBase64: sos.imageBase64,
            sceneKind: sos.sceneKind,
            height: 165,
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: kDanger),
                  onPressed: _callWearer,
                  icon: const Icon(Icons.call_rounded, size: 18),
                  label: const Text('Gọi ngay'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _shareSosLocation(sos),
                icon: const Icon(Icons.share_location_rounded, size: 18),
                label: const Text('Chia sẻ'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: widget.vm.resolveActiveSos,
              icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: const Text('Xác nhận đã hỗ trợ an toàn'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnreadAssistBanner(CaregiverViewModel vm) {
    final latest = vm.latestPendingAssist;
    return SurfaceCard(
      padding: EdgeInsets.zero,
      color: kWarningSoft,
      borderColor: const Color(0xFFFDE68A),
      radius: 16,
      child: InkWell(
        onTap: widget.onOpenAssistTab,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.photo_camera_back_rounded,
                  color: kWarning,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${vm.wearerName} gửi ${vm.pendingAssistCount} ảnh nhờ xem giúp',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: kInk,
                      ),
                    ),
                    if (latest != null)
                      Text(
                        latest.question,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: kInkSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: kWarning),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJourneySummaryCard(CaregiverViewModel vm) {
    final currentStep =
        (vm.activeRoute != null &&
            vm.currentStepIndex < vm.activeRoute!.steps.length)
        ? vm.activeRoute!.steps[vm.currentStepIndex]
        : null;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: kPrimarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  vm.isPrivacySharingActive
                      ? Icons.turn_left_rounded
                      : Icons.home_outlined,
                  color: kPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      vm.activeRoute?.destination.name ?? 'Chưa có hành trình',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: kInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentStep?.text ??
                          'Đang chờ ${vm.wearerName} bắt đầu hành trình mới',
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
          const Divider(height: 24),
          Row(
            children: <Widget>[
              _InlineMetric(
                label: 'Sai số GPS',
                value: '±${(vm.gpsAccuracyM ?? 4.0).toStringAsFixed(1)} m',
              ),
              const SizedBox(width: 16),
              _InlineMetric(
                label: 'Hướng kính',
                value: '${(vm.glassHealth.stm32Heading ?? 0).round()}°',
              ),
              const SizedBox(width: 16),
              _InlineMetric(
                label: 'Pin kính',
                value: vm.glassHealth.batteryPercent != null
                    ? '${vm.glassHealth.batteryPercent}%'
                    : '--',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRemoteDestinationSection(CaregiverViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: 'Đặt điểm đến hộ',
          subtitle:
              'Gửi gợi ý địa điểm sang kính — ${vm.wearerName} chỉ cần nói "Có" để bắt đầu đi.',
        ),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: _searchCtrl,
                onSubmitted: _runSearch,
                decoration: InputDecoration(
                  hintText: 'Tìm địa chỉ, bệnh viện, trạm xe buýt...',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: kInkMuted,
                  ),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          tooltip: 'Tìm kiếm',
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            color: kPrimary,
                          ),
                          onPressed: () => _runSearch(_searchCtrl.text),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  hintText: 'Lời nhắn đọc kèm (tùy chọn)',
                  prefixIcon: Icon(
                    Icons.record_voice_over_outlined,
                    color: kInkMuted,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (
                var i = 0;
                i < _searchResults.take(4).length;
                i++
              ) ...<Widget>[
                if (i > 0) const Divider(height: 1),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 4,
                  ),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: kSurfaceMuted,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.place_outlined,
                      size: 19,
                      color: kPrimary,
                    ),
                  ),
                  title: Text(
                    _searchResults[i].name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: kInk,
                    ),
                  ),
                  subtitle: _searchResults[i].address.isEmpty
                      ? null
                      : Text(
                          _searchResults[i].address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: kInkMuted,
                          ),
                        ),
                  trailing: FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      backgroundColor: kPrimarySoft,
                      foregroundColor: kPrimary,
                      minimumSize: const Size(64, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    onPressed: () => _confirmPushDestination(_searchResults[i]),
                    child: const Text('Gửi'),
                  ),
                ),
              ],
              if (vm.destinationHistory.isNotEmpty) ...<Widget>[
                const Divider(height: 20),
                const Text(
                  'Vừa gửi gần đây',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kInkMuted,
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
                              color: d.status == 'accepted'
                                  ? kSuccess
                                  : kWarning,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                d.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: kInk,
                                ),
                              ),
                            ),
                            Text(
                              d.status == 'accepted'
                                  ? 'Đã xác nhận'
                                  : 'Đang chờ...',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: d.status == 'accepted'
                                    ? kSuccess
                                    : kWarning,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _InlineMetric extends StatelessWidget {
  final String label;
  final String value;

  const _InlineMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(fontSize: 11.5, color: kInkMuted)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: kInk,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
