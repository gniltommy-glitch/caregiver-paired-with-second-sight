import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:secondsight_caregiver/domain/models/caregiver_models.dart';
import 'package:secondsight_caregiver/main.dart';
import 'package:secondsight_caregiver/ui/view_models/caregiver_view_model.dart';

void main() {
  group('SecondSightPairingPayload compatibility', () {
    test('generates and parses valid secondsight_pairing v1 JSON', () {
      const payload = SecondSightPairingPayload(
        endpoint: 'http://secondsight.local:8765',
        token: 'ss-secret-token-0123456789abcdef',
        routingKey: 'gh-key-demo',
        allowInsecure: true,
        relayEndpoint: 'http://192.168.1.50:8787',
        wearerName: 'Hải Đăng',
        wearerPhone: '0901234567',
      );

      final encoded = payload.toQrJsonString();
      final parsed = SecondSightPairingPayload.parse(encoded);

      expect(parsed.endpoint, 'http://secondsight.local:8765');
      expect(parsed.token, 'ss-secret-token-0123456789abcdef');
      expect(parsed.routingKey, 'gh-key-demo');
      expect(parsed.allowInsecure, isTrue);
      expect(parsed.relayEndpoint, 'http://192.168.1.50:8787');
      expect(parsed.wearerName, 'Hải Đăng');
    });

    test('rejects insecure HTTP when allow_insecure is false', () {
      const raw =
          '{"type":"secondsight_pairing","version":1,"endpoint":"http://192.168.1.10:8765","token":"abcdef1234567890","allow_insecure":false}';
      expect(
        () => SecondSightPairingPayload.parse(raw),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('CaregiverViewModel domain flows', () {
    test(
      'privacy curtain hides sharing when idle unless SOS is active',
      () async {
        final vm = CaregiverViewModel(enablePlatformPlugins: false);
        await vm.init();

        expect(vm.navigationState, 'navigating');
        expect(vm.isPrivacySharingActive, isTrue);

        vm.toggleDemoPrivacyState();
        expect(vm.navigationState, 'idle');
        expect(vm.isPrivacySharingActive, isFalse);

        vm.triggerDemoSos();
        expect(vm.activeSos?.active, isTrue);
        expect(vm.isPrivacySharingActive, isTrue);

        await vm.resolveActiveSos();
        expect(vm.activeSos?.active, isFalse);
        expect(vm.isPrivacySharingActive, isFalse);

        vm.dispose();
      },
    );

    test('assist snapshot request and reply roundtrip works cleanly', () async {
      final vm = CaregiverViewModel(enablePlatformPlugins: false);
      await vm.init();

      final initialCount = vm.assistRequests.length;
      vm.triggerDemoAssistSnapshot();
      expect(vm.assistRequests.length, initialCount + 1);

      final newest = vm.assistRequests.first;
      expect(newest.isPending, isTrue);

      await vm.replyToAssistRequest(
        newest.requestId,
        'Đường phía trước thoáng, đi thẳng 5 mét.',
      );

      expect(vm.assistRequests.first.isPending, isFalse);
      expect(
        vm.assistRequests.first.replyText,
        'Đường phía trước thoáng, đi thẳng 5 mét.',
      );
      vm.dispose();
    });

    test(
      'remote destination push records suggestion and thermal alert triggers',
      () async {
        final vm = CaregiverViewModel(enablePlatformPlugins: false);
        await vm.init();

        final suggestion = await vm.sendDestinationToWearer(
          const PlaceLocation(
            name: 'Bệnh viện Chợ Rẫy',
            address: '201B Nguyễn Chí Thanh, Quận 5',
            point: LatLng(10.7578, 106.6596),
          ),
          note: 'Đi cổng chính',
        );
        expect(suggestion.name, 'Bệnh viện Chợ Rẫy');
        expect(vm.destinationHistory.first.status, 'pending_confirmation');

        vm.triggerDemoAnomaly('thermal');
        expect(vm.glassHealth.isThermalThrottling, isTrue);

        vm.resetDemoHardwareNormal();
        expect(vm.glassHealth.isThermalThrottling, isFalse);

        vm.dispose();
      },
    );
  });

  testWidgets('SecondSightCaregiverApp renders all 4 tabs cleanly', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    final vm = CaregiverViewModel(enablePlatformPlugins: false);
    await vm.init();

    // Tắt chế độ dẫn đường để kiểm thử giao diện mà không gọi HTTP tile OSM mạng ngoài
    vm.toggleDemoPrivacyState();

    await tester.pumpWidget(SecondSightCaregiverApp(viewModel: vm));
    await tester.pumpAndSettle();

    expect(find.text('SecondSight Caregiver'), findsOneWidget);
    expect(find.text('Màn chắn riêng tư đang bật'), findsOneWidget);

    // Chuyển sang tab Hỏi ảnh
    await tester.tap(find.text('Hỏi ảnh'));
    await tester.pumpAndSettle();
    expect(find.text('Hỏi người thân qua ảnh tĩnh'), findsOneWidget);

    // Chuyển sang tab Thiết bị
    await tester.tap(find.text('Thiết bị'));
    await tester.pumpAndSettle();
    expect(find.text('Kính đang hoạt động ổn định'), findsOneWidget);

    // Chuyển sang tab Ghép đôi
    await tester.tap(find.text('Ghép đôi'));
    await tester.pumpAndSettle();
    expect(find.text('Ghép đôi nhanh với SecondSight'), findsOneWidget);

    vm.dispose();
    await tester.binding.setSurfaceSize(null);
  });
}
