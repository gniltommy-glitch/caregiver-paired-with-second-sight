# SecondSight Caregiver — Ứng dụng Người thân Đồng hành

Ứng dụng di động đồng hành dành cho người thân / tình nguyện viên hỗ trợ từ xa người khiếm thị sử dụng hệ sinh thái kính thông minh **The Second Sight**:
- Ứng dụng chính cho người khiếm thị: [the_second_sight_mobile_app](https://github.com/gniltommy-glitch/the_second_sight_mobile_app)
- Hệ thống xử lý trên kính (Raspberry Pi 5 + ToF SEN0628 + STM32F411E-DISCO): [smart_glass_v2](https://github.com/gniltommy-glitch/smart_glass_v2)

## Cài đặt nhanh file APK có sẵn trong Repo

File cài đặt Android đã được biên dịch sẵn ngay tại thư mục gốc của repository:
- **`SecondSight-Caregiver.apk`**

Sau khi cài trên điện thoại Android, ứng dụng mở sẵn ở **Chế độ mô phỏng tương tác (Demo)** — bạn có thể trải nghiệm ngay lập tức toàn bộ bản đồ dẫn đường, gửi/trả lời ảnh chụp từ kính, kích hoạt SOS, chẩn đoán nhiệt độ Pi 5 / IMU STM32 và tạo mã QR ghép đôi **mà không cần máy chủ hay kính thật**.

---

## 4 Nhóm tính năng cốt lõi (Thiết kế tinh gọn, không nhồi nhét)

### 1. Hỏi người thân qua Ảnh tĩnh & Giọng nói (*"Ask My Person"*)
- Khi `VietOCR` gặp biển báo bị chói nắng/mờ hoặc người khiếm thị đứng trước ngã tư phức tạp, kính chụp **1 tấm ảnh tĩnh (~150 KB)** từ camera `IMX708` và gửi sang ứng dụng người thân (không stream video liên tục để giữ nhẹ băng thông và tránh làm nóng Pi 5).
- Người thân xem ảnh kèm lớp phủ khoảng cách ToF / nhãn nhận diện YOLO, sau đó bấm **1 chạm câu trả lời nhanh** hoặc **bấm giữ mic nói câu chỉ dẫn** → nội dung được đẩy ngược về đọc thẳng vào tai nghe của người đeo kính.

### 2. SOS Thông minh & Phát hiện bất thường thụ động (*Smart Safety*)
- **SOS một chạm / bằng giọng nói:** Nhận cảnh báo khẩn cấp kèm chuông giọng nói tiếng Việt, tọa độ GPS + sai số (`±m`), **ảnh chụp hiện trường mới nhất**, nút gọi điện ngay và chia sẻ vị trí Google Maps.
- **Cảnh báo thụ động:** Giám sát dấu hiệu đi lệch tuyến kéo dài, nghi ngờ rơi kính / té ngã qua góc nghiêng `pitch/roll` đột ngột từ **STM32 Mahony IMU**, và cảnh báo khi CPU **Raspberry Pi 5 quá nhiệt (≥75°C)**.

### 3. Đặt điểm đến hộ & Theo dõi hành trình tôn trọng riêng tư (*Privacy-First Remote Assist*)
- **Đặt điểm đến hộ từ xa:** Tìm địa chỉ (GraphHopper / OpenStreetMap Nominatim / danh mục địa điểm TP.HCM) hoặc **nhấn giữ trực tiếp trên bản đồ** để gửi gợi ý điểm đến sang kính. Người khiếm thị vẫn giữ quyền tự chủ: chỉ cần xác nhận *"Có"* bằng giọng nói để bắt đầu đi.
- **Màn chắn riêng tư tự động:** Vị trí GPS chỉ hiển thị khi người khiếm thị đang bật phiên dẫn đường (`navigating`) hoặc có tín hiệu `SOS`, tự động ẩn khi nghỉ (`idle` / `arrived`).

### 4. Giám sát kỹ thuật & Tạo mã QR cấu hình một lần
- Theo dõi trực tiếp gói `device_status` chuẩn `SecondSight protocol v1` (Pin, nhiệt độ CPU Pi 5, tốc độ FPS YOLO, trạng thái Camera IMX708, ToF SEN0628 8×8, STM32F411).
- **Tạo mã QR `secondsight_pairing` v1 ngay trên điện thoại người thân** (thay thế hoàn toàn thao tác chạy script CLI trên máy tính) để điện thoại của người khiếm thị quét cấu hình một lần.

---

## Chạy mã nguồn từ đầu

### 1. Ứng dụng Flutter (Android / iOS / Web)
```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Biên dịch lại file APK phát hành:
```bash
flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk ./SecondSight-Caregiver.apk
```

### 2. Chạy Caregiver Relay Server tham chiếu (`relay_server/`)
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r relay_server/requirements.txt

# Chạy kiểm thử tự động cho Relay Server
python3 -m unittest relay_server/test_relay.py -v

# Khởi chạy Relay Server ở cổng 8787
export SECONDSIGHT_TOKEN="$(python3 -c 'import secrets; print(secrets.token_urlsafe(32))')"
printf 'Token ghép đôi: %s\n' "$SECONDSIGHT_TOKEN"
python3 -m relay_server.server --port 8787 --demo
```

Chi tiết đặc tả gói tin xem tại [docs/CAREGIVER_PROTOCOL.md](docs/CAREGIVER_PROTOCOL.md).
