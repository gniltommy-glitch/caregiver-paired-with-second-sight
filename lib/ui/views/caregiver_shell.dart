import 'package:flutter/material.dart';

import '../core/caregiver_theme.dart';
import '../view_models/caregiver_view_model.dart';
import 'assist_inbox_tab.dart';
import 'diagnostics_tab.dart';
import 'live_journey_tab.dart';
import 'pairing_settings_tab.dart';

class CaregiverShell extends StatefulWidget {
  final CaregiverViewModel vm;

  const CaregiverShell({super.key, required this.vm});

  @override
  State<CaregiverShell> createState() => _CaregiverShellState();
}

class _CaregiverShellState extends State<CaregiverShell> {
  int _index = 0;

  void _openDemoControlsSheet(CaregiverViewModel vm) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: kBorder,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Kịch bản thử nghiệm (Demo)',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: kInk,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Chọn tình huống để kiểm thử phản hồi của ứng dụng khi không có kính thật.',
                style: TextStyle(fontSize: 13, color: kInkSecondary),
              ),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: kPrimarySoft,
                  child: Icon(Icons.add_a_photo_outlined, color: kPrimary),
                ),
                title: const Text(
                  'Giả lập gửi ảnh hỏi người thân',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Chụp ảnh ngã tư / rào chắn / biển báo'),
                onTap: () {
                  Navigator.pop(ctx);
                  vm.triggerDemoAssistSnapshot();
                  setState(() => _index = 1);
                },
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: kDangerSoft,
                  child: Icon(Icons.sos_rounded, color: kDanger),
                ),
                title: const Text(
                  'Giả lập tín hiệu khẩn cấp SOS',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Gửi vị trí kèm ảnh hiện trường'),
                onTap: () {
                  Navigator.pop(ctx);
                  vm.triggerDemoSos();
                  setState(() => _index = 0);
                },
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: kInfoSoft,
                  child: Icon(Icons.verified_user_outlined, color: kInfo),
                ),
                title: Text(
                  vm.navigationState == 'navigating'
                      ? 'Thử kết thúc hành trình (Bật màn chắn riêng tư)'
                      : 'Tiếp tục hành trình dẫn đường',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  vm.toggleDemoPrivacyState();
                  setState(() => _index = 0);
                },
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: kWarningSoft,
                  child: Icon(Icons.thermostat_rounded, color: kWarning),
                ),
                title: const Text(
                  'Giả lập Pi 5 quá nhiệt (79.4°C) / Nghi rơi kính',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  vm.triggerDemoAnomaly('thermal');
                  setState(() => _index = 2);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.vm,
      builder: (context, _) {
        final vm = widget.vm;
        final pendingCount = vm.pendingAssistCount;
        final sosActive = vm.activeSos?.active == true;

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 16,
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, color: kBorder),
            ),
            title: Row(
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: sosActive ? kDangerSoft : kPrimarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    sosActive
                        ? Icons.warning_rounded
                        : Icons.visibility_outlined,
                    size: 19,
                    color: sosActive ? kDanger : kPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'SecondSight Caregiver',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: kInk,
                        ),
                      ),
                      Row(
                        children: <Widget>[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: vm.simulationMode
                                  ? kWarning
                                  : (vm.liveConnected ? kSuccess : kDanger),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              '${vm.wearerName} · ${vm.simulationMode ? 'Mô phỏng' : (vm.liveConnected ? 'Trực tuyến' : 'Ngoại tuyến')}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: kInkMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              if (sosActive)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: kDanger,
                      minimumSize: const Size(44, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onPressed: () => setState(() => _index = 0),
                    icon: const Icon(Icons.sos_rounded, size: 15),
                    label: const Text('SOS', style: TextStyle(fontSize: 12)),
                  ),
                )
              else if (vm.simulationMode)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      backgroundColor: kSurfaceMuted,
                      foregroundColor: kInk,
                      minimumSize: const Size(44, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    onPressed: () => _openDemoControlsSheet(vm),
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    label: const Text(
                      'Thử nghiệm',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
                ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: IndexedStack(
              index: _index,
              children: <Widget>[
                LiveJourneyTab(
                  vm: vm,
                  onOpenAssistTab: () => setState(() => _index = 1),
                  onOpenPairingTab: () => setState(() => _index = 3),
                ),
                AssistInboxTab(vm: vm),
                DiagnosticsTab(vm: vm),
                PairingSettingsTab(vm: vm),
              ],
            ),
          ),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: kSurface,
              border: Border(top: BorderSide(color: kBorder)),
            ),
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (idx) => setState(() => _index = idx),
              destinations: <NavigationDestination>[
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: sosActive,
                    backgroundColor: kDanger,
                    child: const Icon(Icons.explore_outlined),
                  ),
                  selectedIcon: const Icon(Icons.explore_rounded),
                  label: 'Hành trình',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: pendingCount > 0,
                    backgroundColor: kDanger,
                    label: Text(
                      '$pendingCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Icon(Icons.photo_camera_back_outlined),
                  ),
                  selectedIcon: const Icon(Icons.photo_camera_back_rounded),
                  label: 'Hỏi ảnh',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.monitor_heart_outlined),
                  selectedIcon: Icon(Icons.monitor_heart_rounded),
                  label: 'Thiết bị',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.qr_code_2_rounded),
                  selectedIcon: Icon(Icons.qr_code_2_rounded),
                  label: 'Ghép đôi',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
