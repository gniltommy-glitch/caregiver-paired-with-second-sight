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
        backgroundColor: kCard2,
        content: Text(
          connectAfterSave
              ? 'Đã lưu cấu hình và mở kết nối trực tiếp.'
              : 'Đã lưu cấu hình ghép đôi.',
          style: const TextStyle(color: kText),
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
          backgroundColor: kCard2,
          content: Text(
            'Đã nhập thành công mã QR cấu hình SecondSight!',
            style: TextStyle(color: kAccent),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF2B1218),
          content: Text('$e', style: const TextStyle(color: kDanger)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final qrString = vm.buildPairingPayload().toQrJsonString();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: <Widget>[
        _buildQrGeneratorCard(qrString),
        const SizedBox(height: 16),
        _buildModeSwitchCard(vm),
        if (vm.lastError != null) ...<Widget>[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF281219),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kDanger.withValues(alpha: 0.5)),
            ),
            child: Text(
              vm.lastError!,
              style: const TextStyle(fontSize: 12.5, color: kDanger),
            ),
          ),
        ],
        const SizedBox(height: 16),
        _buildConnectionForm(vm),
      ],
    );
  }

  Widget _buildQrGeneratorCard(String qrJson) {
    return SpotlightCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.qr_code_2_rounded, color: kAccent, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tạo mã QR cấu hình một lần cho Kính & App chính',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: kText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Thay vì phải chạy script Python trên máy tính, người thân tạo trực tiếp mã QR chuẩn secondsight_pairing v1 ngay tại đây để ứng dụng SecondSight của người khiếm thị quét một lần.',
            style: TextStyle(fontSize: 12.5, color: kTextSub),
          ),
          const SizedBox(height: 14),
          Center(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: QrImageView(
                data: qrJson,
                size: 196,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: () {
                  final fresh = widget.vm.generateFreshToken();
                  setState(() => _tokenCtrl.text = fresh);
                },
                icon: const Icon(Icons.key_rounded, size: 17),
                label: const Text('Sinh Token mới'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: qrJson));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: kCard2,
                      content: Text(
                        'Đã sao chép JSON ghép đôi vào bộ nhớ tạm.',
                        style: TextStyle(color: kText),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 17),
                label: const Text('Sao chép JSON'),
              ),
              OutlinedButton.icon(
                onPressed: _openQrScanner,
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 17),
                label: const Text('Quét mã có sẵn'),
              ),
              IconButton.filledTonal(
                style: IconButton.styleFrom(backgroundColor: kCard2),
                tooltip: 'Chia sẻ cấu hình cho người thân khác',
                onPressed: () =>
                    SharePlus.instance.share(ShareParams(text: qrJson)),
                icon: const Icon(
                  Icons.share_outlined,
                  color: kAccent,
                  size: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeSwitchCard(CaregiverViewModel vm) {
    return Material(
      color: kSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: kBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          children: <Widget>[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: kAccent,
              title: const Text(
                'Chế độ mô phỏng tương tác (Demo)',
                style: TextStyle(fontWeight: FontWeight.w700, color: kText),
              ),
              subtitle: const Text(
                'Trải nghiệm đầy đủ bản đồ hành trình, ảnh hỏi, SOS và chẩn đoán không cần máy chủ.',
                style: TextStyle(fontSize: 12, color: kTextSub),
              ),
              value: vm.simulationMode,
              onChanged: vm.setSimulationMode,
            ),
            const Divider(color: kBorder, height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: kAccent,
              title: const Text(
                'Đọc thông báo khẩn bằng giọng nói tiếng Việt',
                style: TextStyle(fontWeight: FontWeight.w600, color: kText),
              ),
              subtitle: const Text(
                'Tự động phát lời nhắc khi người đeo kính gửi ảnh hỏi hoặc kích hoạt SOS.',
                style: TextStyle(fontSize: 12, color: kTextSub),
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
    );
  }

  Widget _buildConnectionForm(CaregiverViewModel vm) {
    return Material(
      color: kSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: kBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Hồ sơ đồng hành & Kết nối máy chủ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: kText,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _caregiverCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tên của bạn',
                      prefixIcon: Icon(Icons.favorite_outline, size: 19),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _wearerCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tên người đeo kính',
                      prefixIcon: Icon(Icons.person_outline, size: 19),
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
                labelText: 'Số điện thoại gọi khẩn cấp người đeo kính',
                prefixIcon: Icon(Icons.phone_outlined, size: 19),
              ),
            ),
            const SizedBox(height: 14),
            SegmentedButton<LinkMode>(
              segments: const <ButtonSegment<LinkMode>>[
                ButtonSegment<LinkMode>(
                  value: LinkMode.relayServer,
                  label: Text('Caregiver Relay (:8787)'),
                  icon: Icon(Icons.hub_outlined, size: 17),
                ),
                ButtonSegment<LinkMode>(
                  value: LinkMode.directPiBridge,
                  label: Text('LAN Kính Pi 5 (:8765)'),
                  icon: Icon(Icons.router_outlined, size: 17),
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
                labelText: 'Địa chỉ Caregiver Relay hoặc Kính',
                hintText: 'http://192.168.1.50:8787',
                prefixIcon: Icon(Icons.dns_outlined, size: 19),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _glassQrCtrl,
              decoration: const InputDecoration(
                labelText: 'Địa chỉ LAN Pi 5 nhúng trong mã QR kính',
                hintText: 'http://secondsight.local:8765',
                prefixIcon: Icon(Icons.visibility_outlined, size: 19),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _tokenCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Bearer Token ghép đôi (lưu trong Secure Storage)',
                prefixIcon: Icon(Icons.lock_outline, size: 19),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _routingKeyCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'GraphHopper API Key (tùy chọn cho mã QR)',
                prefixIcon: Icon(Icons.map_outlined, size: 19),
              ),
            ),
            const SizedBox(height: 6),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _allowInsecure,
              activeColor: kAccent,
              title: const Text(
                'Cho phép HTTP LAN thử nghiệm (allow_insecure)',
                style: TextStyle(fontSize: 13.5, color: kText),
              ),
              onChanged: (v) => setState(() => _allowInsecure = v ?? false),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saveSettings,
                    child: const Text('Lưu cấu hình'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _saveSettings(connectAfterSave: true),
                    icon: const Icon(Icons.link_rounded, size: 19),
                    label: Text(
                      vm.liveConnected ? 'Kết nối lại' : 'Kết nối thật',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: kTextSub,
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
                  color: kText,
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
