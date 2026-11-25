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
            title: Row(
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: kCard2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (sosActive ? kDanger : kAccent).withValues(
                        alpha: 0.45,
                      ),
                    ),
                  ),
                  child: Icon(
                    sosActive
                        ? Icons.warning_amber_rounded
                        : Icons.remove_red_eye_outlined,
                    size: 19,
                    color: sosActive ? kDanger : kAccent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'SecondSight Caregiver',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: kText,
                        ),
                      ),
                      Text(
                        'Đồng hành cùng ${vm.wearerName}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: kTextSub,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              if (sosActive)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: kDanger,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(44, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onPressed: () => setState(() => _index = 0),
                    icon: const Icon(Icons.sos_rounded, size: 16),
                    label: const Text('SOS', style: TextStyle(fontSize: 12)),
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
                    backgroundColor: kWarning,
                    label: Text(
                      '$pendingCount',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
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
