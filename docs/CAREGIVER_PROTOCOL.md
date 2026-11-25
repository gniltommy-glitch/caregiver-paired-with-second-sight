# SecondSight Caregiver Protocol v1

Giao thức mở rộng dành cho ứng dụng người thân (**SecondSight Caregiver**), tương thích ngược hoàn toàn với [SecondSight protocol v1](https://github.com/gniltommy-glitch/the_second_sight_mobile_app) và cầu nối `thread_app_link.py` trên [smart_glass_v2](https://github.com/gniltommy-glitch/smart_glass_v2).

## 1. Nguyên tắc cốt lõi

1. **Không truyền video liên tục:** Giữ băng thông di động tối thiểu và bảo vệ Raspberry Pi 5 khỏi giảm xung nhiệt (*thermal throttling*). Mọi hỗ trợ hình ảnh đều dùng **ảnh chụp tĩnh JPEG theo yêu cầu (`assist_request`)** hoặc đính kèm sự kiện **SOS (`sos_alert`)**.
2. **Quyền riêng tư theo phiên (*Privacy-First*):** Relay Server và ứng dụng chỉ hiển thị tọa độ GPS/tuyến đi bộ khi `navigation.state == "navigating"` hoặc đang có `active_sos`. Khi người khiếm thị ở trạng thái `idle` hoặc `arrived`, tọa độ tự động được che bằng màn chắn riêng tư.
3. **Tôn trọng quyền tự chủ:** Khi người thân gửi điểm đến từ xa (`destination_suggestion`), ứng dụng của người khiếm thị không tự ý đổi hướng đi mà đọc lời mời và chờ xác nhận giọng nói (*"Có"*).
4. **Xác thực Header:** Mọi kết nối REST và WebSocket đều truyền `Authorization: Bearer <token>` trong HTTP header, tuyệt đối không đưa khóa vào URL hoặc nhật ký sự kiện.

---

## 2. Điểm cuối trên `relay_server/server.py` (cổng mặc định `8787`)

| Endpoint | Phương thức | Vai trò |
|---|---|---|
| `/ws?role=caregiver\|wearer\|glass` | `GET` (WebSocket) | Kênh đồng bộ thời gian thực hai chiều |
| `/status` (hoặc `/device/status`) | `GET` | Lấy `caregiver_snapshot` tổng hợp |
| `/navigation/state` | `POST` | Cập nhật trạng thái dẫn đường từ App người khiếm thị |
| `/assist/request` | `POST` | Gửi ảnh chụp tĩnh từ kính nhờ người thân xem giúp |
| `/assist/reply` | `POST` | Người thân gửi câu trả lời để đọc thẳng vào tai nghe kính |
| `/sos/trigger` | `POST` | Kích hoạt cảnh báo khẩn cấp kèm vị trí + ảnh hiện trường |
| `/sos/resolve` | `POST` | Xác nhận đã hỗ trợ an toàn |
| `/destination/suggest` | `POST` | Người thân đặt hộ điểm đến (chờ xác nhận *"Có"*) |

Ngoài ra, ứng dụng **SecondSight Caregiver** còn hỗ trợ chế độ **LAN Kính Pi 5 (`:8765`)** để nối thẳng vào `smart_glass_v2` / `pi_demo` khi ở cùng mạng Wi-Fi/Hotspot.

---

## 3. Cấu trúc mã QR ghép đôi mở rộng (`secondsight_pairing` v1)

Trình tạo mã QR tích hợp trong tab **Ghép đôi** sinh chuỗi JSON tương thích trực tiếp với `PairingConfig.parse()` của ứng dụng người khiếm thị:

```json
{
  "type": "secondsight_pairing",
  "version": 1,
  "endpoint": "http://secondsight.local:8765",
  "token": "TOKEN_NGAU_NHIEN_36_KY_TU",
  "routing_key": "GRAPHHOPPER_API_KEY_TUY_CHON",
  "allow_insecure": true,
  "relay_endpoint": "http://192.168.1.50:8787",
  "wearer_name": "Hải Đăng",
  "wearer_phone": "0901234567"
}
```
