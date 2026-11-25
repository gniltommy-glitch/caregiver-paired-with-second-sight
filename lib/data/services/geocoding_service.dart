import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../domain/models/caregiver_models.dart';

class GeocodingService {
  GeocodingService({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;

  /// Danh sách địa điểm mẫu tại TP.HCM (quanh khu vực PTNK / Quận 5 / Quận 1)
  /// giúp người thân chọn nhanh hoặc dùng ngay cả khi mất mạng.
  static const List<PlaceLocation> curatedLandmarks = <PlaceLocation>[
    PlaceLocation(
      name: 'Trường Phổ thông Năng khiếu (ĐHQG-HCM)',
      address: '153 Nguyễn Chí Thanh, Phường 9, Quận 5, TP.HCM',
      point: LatLng(10.7575, 106.6666),
    ),
    PlaceLocation(
      name: 'Bệnh viện Chợ Rẫy',
      address: '201B Nguyễn Chí Thanh, Phường 12, Quận 5, TP.HCM',
      point: LatLng(10.7578, 106.6596),
    ),
    PlaceLocation(
      name: 'Trạm xe buýt ĐH Khoa học Tự nhiên',
      address: '227 Nguyễn Văn Cừ, Phường 4, Quận 5, TP.HCM',
      point: LatLng(10.7626, 106.6822),
    ),
    PlaceLocation(
      name: 'Chợ Bến Thành',
      address: 'Đường Lê Lợi, Phường Bến Thành, Quận 1, TP.HCM',
      point: LatLng(10.7725, 106.6980),
    ),
    PlaceLocation(
      name: 'Công viên Tao Đàn',
      address: '55C Nguyễn Thị Minh Khai, Quận 1, TP.HCM',
      point: LatLng(10.7746, 106.6924),
    ),
    PlaceLocation(
      name: 'Nhà sách Nguyễn Văn Cừ',
      address: '235 Nguyễn Văn Cừ, Quận 5, TP.HCM',
      point: LatLng(10.7634, 106.6826),
    ),
  ];

  Future<List<PlaceLocation>> searchPlaces(
    String query, {
    String? graphHopperKey,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return curatedLandmarks;

    final lower = trimmed.toLowerCase();
    final localMatches = curatedLandmarks
        .where(
          (p) =>
              p.name.toLowerCase().contains(lower) ||
              p.address.toLowerCase().contains(lower),
        )
        .toList();

    // Ưu tiên GraphHopper Geocoding nếu có khóa cấu hình
    if (graphHopperKey != null && graphHopperKey.trim().isNotEmpty) {
      try {
        final uri = Uri.https(
          'graphhopper.com',
          '/api/1/geocode',
          <String, String>{
            'q': trimmed,
            'locale': 'vi',
            'limit': '6',
            'point': '10.7626,106.6822',
            'key': graphHopperKey.trim(),
          },
        );
        final res = await _http.get(uri).timeout(const Duration(seconds: 6));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final hits = (data['hits'] as List<dynamic>?) ?? const <dynamic>[];
          final remote = <PlaceLocation>[];
          for (final raw in hits.whereType<Map<String, dynamic>>()) {
            final pt = raw['point'] as Map<String, dynamic>?;
            if (pt == null) continue;
            final lat = (pt['lat'] as num?)?.toDouble();
            final lng = (pt['lng'] as num?)?.toDouble();
            if (lat == null || lng == null) continue;
            final name = (raw['name'] as String?)?.trim() ?? trimmed;
            final parts = <String>[
              if (raw['housenumber'] is String) raw['housenumber'] as String,
              if (raw['street'] is String) raw['street'] as String,
              if (raw['city'] is String) raw['city'] as String,
            ];
            remote.add(
              PlaceLocation(
                name: name,
                address: parts.join(', '),
                point: LatLng(lat, lng),
              ),
            );
          }
          if (remote.isNotEmpty) {
            return <PlaceLocation>[...localMatches, ...remote];
          }
        }
      } catch (_) {
        // Chuyển tiếp sang Nominatim hoặc kết quả cục bộ
      }
    }

    try {
      final uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/search',
        <String, String>{
          'q': trimmed,
          'format': 'jsonv2',
          'limit': '6',
          'countrycodes': 'vn',
          'accept-language': 'vi',
        },
      );
      final res = await _http
          .get(
            uri,
            headers: const <String, String>{
              'User-Agent': 'SecondSightCaregiver/1.0 (assistive-companion)',
            },
          )
          .timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is List) {
          final remote = <PlaceLocation>[];
          for (final item in decoded.whereType<Map<String, dynamic>>()) {
            final lat = double.tryParse('${item['lat']}');
            final lon = double.tryParse('${item['lon']}');
            if (lat == null || lon == null) continue;
            final display = (item['display_name'] as String?) ?? trimmed;
            final segments = display.split(',').map((s) => s.trim()).toList();
            final title = (item['name'] as String?)?.trim().isNotEmpty == true
                ? (item['name'] as String).trim()
                : segments.first;
            final subtitle = segments.length > 1
                ? segments.skip(1).take(3).join(', ')
                : '';
            remote.add(
              PlaceLocation(
                name: title,
                address: subtitle,
                point: LatLng(lat, lon),
              ),
            );
          }
          if (remote.isNotEmpty) {
            return <PlaceLocation>[...localMatches, ...remote];
          }
        }
      }
    } catch (_) {
      // Fallback sang danh sách địa điểm cục bộ
    }

    return localMatches.isNotEmpty ? localMatches : curatedLandmarks;
  }

  void dispose() => _http.close();
}
