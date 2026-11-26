import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/services/relay_link_service.dart';
import '../core/caregiver_theme.dart';
import '../view_models/caregiver_view_model.dart';

class PairingSettingsTab extends StatefulWidget {
  final CaregiverViewModel vm;

  const PairingSettingsTab({super.key, required this.vm});

  @override
  State<PairingSettingsTab> createState() => _PairingSettingsTabState();
}

class _PairingSettingsTabState extends State<PairingSettingsTab> {
  late final TextEditingController _caregiverCtrl;
  late final TextEditingController _wearerCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _endpointCtrl;
  late final TextEditingController _glassQrCtrl;
  late final TextEditingController _tokenCtrl;
  late final TextEditingController _routingKeyCtrl;
  late bool _allowInsecure;
  late bool _audibleAlerts;
  late LinkMode _mode;

  @override
  void initState() {
    super.initState();
    final vm = widget.vm;
    _caregiverCtrl = TextEditingController(text: vm.caregiverName);
    _wearerCtrl = TextEditingController(text: vm.wearerName);
    _phoneCtrl = TextEditingController(text: vm.wearerPhone);
    _endpointCtrl = TextEditingController(text: vm.endpoint);
    _glassQrCtrl = TextEditingController(text: vm.glassEndpointForQr);
    _tokenCtrl = TextEditingController(text: vm.token);
    _routingKeyCtrl = TextEditingController(text: vm.routingKey);
    _allowInsecure = vm.allowInsecure;
    _audibleAlerts = vm.audibleAlerts;
    _mode = vm.linkMode;
  }

  @override
  void dispose() {
    _caregiverCtrl.dispose();
    _wearerCtrl.dispose();
    _phoneCtrl.dispose();
    _endpointCtrl.dispose();
    _glassQrCtrl.dispose();
    _tokenCtrl.dispose();
    _routingKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveSettings({bool connectAfterSave = false}) async {
    await widget.vm.saveConnectionSettings(
      newCaregiverName: _caregiverCtrl.text,
      newWearerName: _wearerCtrl.text,
      newWearerPhone: _phoneCtrl.text,
      newEndpoint: _endpointCtrl.text,
      newGlassEndpointQr: _glassQrCtrl.text,
      newToken: _tokenCtrl.text,
      newRoutingKey: _routingKeyCtrl.text,
      newAllowInsecure: _allowInsecure,
      newMode: _mode,
      newAudibleAlerts: _audibleAlerts,
    );
    if (connectAfterSave) {
      await widget.vm.setSimulationMode(false);
      await widget.vm.connectLive();
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: kInk,
        content: Text(
          connectAfterSave
              ? 'Đã lưu cấu hình và mở kết nối trực tiếp.'
              : 'Đã lưu thay đổi.',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _openQrScanner() async {
    final scanned = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _QrScannerSheet(),
    );
    if (scanned == null || !mounted) return;
    try {
      await widget.vm.importPairingQr(scanned);
      setState(() {
        _wearerCtrl.text = widget.vm.wearerName;
        _phoneCtrl.text = widget.vm.wearerPhone;
        _endpointCtrl.text = widget.vm.endpoint;
        _glassQrCtrl.text = widget.vm.glassEndpointForQr;
        _tokenCtrl.text = widget.vm.token;
        _routingKeyCtrl.text = widget.vm.routingKey;
        _allowInsecure = widget.vm.allowInsecure;
        _mode = widget.vm.linkMode;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: kSuccess,
          content: Text(
            'Đã nhập thành công mã ghép đôi SecondSight!',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: kDanger,
          content: Text('$e', style: const TextStyle(color: Colors.white)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final qrString = vm.buildPairingPayload().toQrJsonString();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: <Widget>[
        _buildQrPairingCard(vm, qrString),
        const SizedBox(height: 20),

        const SectionHeader(title: 'Tùy chọn hoạt động'),
        SurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            children: <Widget>[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: kPrimary,
                title: const Text(
                  'Chế độ mô phỏng (Demo)',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: kInk,
                  ),
                ),
                subtitle: const Text(
                  'Trải nghiệm đầy đủ tính năng mà không cần kính thật',
                  style: TextStyle(fontSize: 12.5, color: kInkSecondary),
                ),
                value: vm.simulationMode,
                onChanged: vm.setSimulationMode,
              ),
              const Divider(),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: kPrimary,
                title: const Text(
                  'Đọc thông báo khẩn bằng giọng nói',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: kInk,
                  ),
                ),
                subtitle: const Text(
                  'Tự phát tiếng Việt khi có ảnh hỏi mới hoặc SOS',
                  style: TextStyle(fontSize: 12.5, color: kInkSecondary),
                ),
                value: _audibleAlerts,
                onChanged: (val) {
                  setState(() => _audibleAlerts = val);
                  _saveSettings();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const SectionHeader(title: 'Hồ sơ đồng hành'),
        SurfaceCard(
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _caregiverCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tên của bạn',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _wearerCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Người đeo kính',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Số điện thoại gọi khẩn cấp',
                  prefixIcon: Icon(Icons.phone_outlined, size: 19),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saveSettings,
                  child: const Text('Lưu thông tin'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (vm.lastError != null) ...<Widget>[
          SurfaceCard(
            color: kDangerSoft,
            borderColor: kDanger.withValues(alpha: 0.35),
            padding: const EdgeInsets.all(14),
            child: Text(
              vm.lastError!,
              style: const TextStyle(fontSize: 13, color: kDanger),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Progressive disclosure: giấu thông số kỹ thuật vào ExpansionTile gọn gàng
        SurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 2),
              childrenPadding: const EdgeInsets.only(bottom: 14),
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: kSurfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  size: 19,
                  color: kInkSecondary,
                ),
              ),
              title: const Text(
                'Cấu hình kết nối nâng cao',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: kInk,
                ),
              ),
              subtitle: const Text(
                'Địa chỉ Relay Server, LAN Pi 5 và Bearer Token',
                style: TextStyle(fontSize: 12, color: kInkMuted),
              ),
              children: <Widget>[
                const SizedBox(height: 8),
                SegmentedButton<LinkMode>(
                  segments: const <ButtonSegment<LinkMode>>[
                    ButtonSegment<LinkMode>(
                      value: LinkMode.relayServer,
                      label: Text('Relay (:8787)'),
                      icon: Icon(Icons.hub_outlined, size: 16),
                    ),
                    ButtonSegment<LinkMode>(
                      value: LinkMode.directPiBridge,
                      label: Text('LAN Pi 5 (:8765)'),
                      icon: Icon(Icons.router_outlined, size: 16),
                    ),
                  ],
                  selected: <LinkMode>{_mode},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _mode = selection.first;
                      if (_mode == LinkMode.directPiBridge &&
                          _endpointCtrl.text.contains(':8787')) {
                        _endpointCtrl.text = 'http://secondsight.local:8765';
                      } else if (_mode == LinkMode.relayServer &&
                          _endpointCtrl.text.contains(':8765')) {
                        _endpointCtrl.text = 'http://192.168.1.50:8787';
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _endpointCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Địa chỉ máy chủ kết nối',
                    hintText: 'http://192.168.1.50:8787',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _glassQrCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Địa chỉ LAN kính Pi 5 (trong QR)',
                    hintText: 'http://secondsight.local:8765',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _tokenCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mã xác thực (Bearer Token)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _routingKeyCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'GraphHopper API Key (tùy chọn)',
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _allowInsecure,
                  activeColor: kPrimary,
                  title: const Text(
                    'Cho phép HTTP mạng LAN thử nghiệm',
                    style: TextStyle(fontSize: 13.5, color: kInk),
                  ),
                  onChanged: (v) => setState(() => _allowInsecure = v ?? false),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _saveSettings(connectAfterSave: true),
                    icon: const Icon(Icons.link_rounded, size: 18),
                    label: Text(
                      vm.liveConnected
                          ? 'Kết nối lại'
                          : 'Lưu & Kết nối trực tiếp',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQrPairingCard(CaregiverViewModel vm, String qrJson) {
    return SurfaceCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: <Widget>[
          const Text(
            'Ghép đôi nhanh với SecondSight',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: kInk,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Mở ứng dụng SecondSight trên máy của ${vm.wearerName} và quét mã này một lần để tự động cấu hình.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: kInkSecondary),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kBorder, width: 1.5),
            ),
            child: QrImageView(
              data: qrJson,
              size: 190,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: kInk,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: kInk,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: _openQrScanner,
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                  label: const Text('Quét mã'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    final fresh = widget.vm.generateFreshToken();
                    setState(() => _tokenCtrl.text = fresh);
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Mã mới'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: <Widget>[
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: qrJson));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: kInk,
                      content: Text(
                        'Đã sao chép mã cấu hình.',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Sao chép'),
              ),
              TextButton.icon(
                onPressed: () =>
                    SharePlus.instance.share(ShareParams(text: qrJson)),
                icon: const Icon(Icons.share_outlined, size: 16),
                label: const Text('Chia sẻ'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QrScannerSheet extends StatefulWidget {
  const _QrScannerSheet();

  @override
  State<_QrScannerSheet> createState() => _QrScannerSheetState();
}

class _QrScannerSheetState extends State<_QrScannerSheet> {
  bool _completed = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: 420,
        child: Column(
          children: <Widget>[
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: kBorder,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Đưa mã QR SecondSight vào khung ngắm',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: kInk,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: MobileScanner(
                    onDetect: (capture) {
                      if (_completed) return;
                      for (final barcode in capture.barcodes) {
                        final raw = barcode.rawValue;
                        if (raw != null && raw.isNotEmpty) {
                          _completed = true;
                          Navigator.of(context).pop(raw);
                          break;
                        }
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
