# Cato (AutoGap) — Trợ lý AI Cảnh Báo Khoảng Cách An Toàn Cao Tốc (iOS / Swift)

Ứng dụng iOS native viết hoàn toàn bằng **Swift & SwiftUI**, nhận diện phương tiện cùng làn phía trước, ước lượng khoảng cách vật lý và thời gian bám đuôi (headway time), đối chiếu và cảnh báo tức thì khi khoảng cách xuống dưới ngưỡng an toàn quy định theo tốc độ trong **Thông tư 38/2024/TT-BGTVT** (35 m, 55 m, 70 m, 100 m).

Dự án tích hợp đầy đủ tính năng **Lưu vết lịch sử GPS theo ngày & Vẽ bản đồ lộ trình đường đi (Apple Maps / MapKit)** theo yêu cầu của bạn.

---

## 🌟 Tính Năng Chính

1. **Chạy On-Device AI — 100% Offline, Bảo mật tuyệt đối**:
   - Sử dụng Apple **Vision Framework & CoreML**, xử lý trực tiếp trên Apple Neural Engine (ANE) và GPU của iPhone.
   - Không gửi hình ảnh, video hay vị trí GPS ra bất kỳ máy chủ nào.
   - Hoàn toàn miễn phí, không quảng cáo, không thu thập dữ liệu cá nhân.

2. **Cảnh Báo Theo Dải Tốc Độ Thông Tư 38/2024/TT-BGTVT**:
   - **Tốc độ $\le 60 \text{ km/h}$**: Người lái chủ động giữ khoảng cách theo mật độ; cảnh báo va chạm khẩn cấp khi $< 8 - 10\text{ m}$.
   - **Trên $60 - 80 \text{ km/h}$**: Ngưỡng an toàn tối thiểu **$35\text{ m}$**.
   - **Trên $80 - 100 \text{ km/h}$**: Ngưỡng an toàn tối thiểu **$55\text{ m}$**.
   - **Trên $100 - 120 \text{ km/h}$**: Ngưỡng an toàn tối thiểu **$70\text{ m}$**.
   - **Trên $120 \text{ km/h}$**: Ngưỡng an toàn tối thiểu **$100\text{ m}$**.
   - Tuỳ chọn cảnh báo sớm hơn ngưỡng luật: **+0 m**, **+5 m**, **+10 m** trong Cài đặt.

3. **Ước Lượng Khoảng Cách Hình Học & Bù Nghiêng Taplo**:
   - Thuật toán phối cảnh camera đơn (Monocular Perspective Geometry):
     $$d_{geom} = \frac{H_{cam}}{\tan(\theta_{pitch} + \alpha)}$$
   - Cảm biến gia tốc kế / con quay hồi chuyển (`CoreMotion`) tự động bù trừ góc nghiêng điện thoại gắn trên kính lái xe.
   - Kết hợp phép chiếu tỷ lệ bề rộng xe (`Pinhole Projection`) và bộ lọc **EMA (Exponential Moving Average)** chống giật và nhảy số.
   - Phân loại 3 làn đường (Làn trái, Làn xe ta, Làn phải) và tự động nhận diện **Xe dẫn đầu (Lead Vehicle)**.

4. **3 Trạng Thái Cảnh Báo An Toàn (Màu Sắc + Âm Thanh ADAS)**:
   - 🟢 **An toàn (Safe - Xanh `#2ECC71`)**: Khoảng cách $> \text{Ngưỡng}$.
   - 🟡 **Thận trọng (Caution - Vàng cam `#F5C518`)**: Khoảng cách sát ngưỡng hoặc thời gian bám đuôi $< 2.0\text{s}$. Phát tiếng ping nhẹ báo hiệu (giãn cách tối thiểu 5s).
   - 🔴 **Quá gần / Nguy hiểm (Danger - Đỏ `#FF3B30`)**: Khoảng cách $< \text{Ngưỡng}$. Phát chuỗi 3 tiếng bíp dứt khoát chuẩn ADAS và viền màn hình nhấp nháy đỏ báo động.

5. **3 Chế Độ Hiển Thị Linh Hoạt**:
   - 📷 **Chế độ Camera (Camera View)**: Xem trực tiếp camera sau, bounding box xe, vạch phối cảnh làn và radar HUD mét / giây.
   - 🗺️ **Chế độ Sơ đồ (Schematic Radar OLED View)**: Vector 3 làn đường trên nền đen sâu OLED (`#0A0C10`), chống chói nắng ban ngày và giảm lóa kính lái ban đêm. Hỗ trợ chạm kéo trực tiếp trên màn hình để kiểm thử khoảng cách.
   - 🌙 **Chế độ Tắt màn hình (Screen Off / Audio-Only)**: Màn hình đen OLED tiết kiệm pin và chống nóng máy tối đa khi điện thoại đặt trên taplo dưới trời nắng gắt. Hệ thống camera và âm thanh cảnh báo vẫn hoạt động bình thường, chạm 2 lần để bật sáng lại.

6. **🗺️ Tính Năng Liệt Kê Lịch Sử Chạy GPS & Vẽ Bản Đồ Lộ Trình (Mới)**:
   - **Tự động phát hiện Dừng đỗ vs Di chuyển**: Dừng quá 5 phút tự động tính là 1 điểm đỗ xe (Parking Stop 🅿️).
   - **Tổng hợp theo ngày**: Hôm nay, Hôm qua, 7 ngày qua... hiển thị tổng số km, thời gian lái xe, thời gian đỗ xe, tốc độ tối đa, tốc độ trung bình.
   - **Vẽ bản đồ Apple Maps (MapKit)**: Vẽ đường đi GPS dạng Polyline, hiển thị điểm xuất phát 🟢, điểm đến 🏁 và các điểm dừng trên bản đồ tương tác.
   - Tích hợp sẵn dữ liệu mẫu thực tế tại Việt Nam (Cao tốc Long Thành – Dầu Giây, Đại lộ Võ Văn Kiệt, Hà Nội – Hải Phòng) giúp người dùng và tester xem ngay giao diện bản đồ.

7. **Chế Độ Mô Phỏng (Demo Mode)**:
   - Cho phép bật thanh trượt tốc độ ảo (20 – 120 km/h) và xe mô phỏng để kiểm thử mọi trạng thái cảnh báo trên Xcode Simulator hoặc ngay trong phòng làm việc.

---

## 📁 Cấu Trúc Dự Án (Xcode Ready)

```
cato-ios/
├── Cato.xcodeproj/                  # File dự án Xcode (Mở và Build ngay lập tức)
│   ├── project.pbxproj              # Cấu hình build phase, sources, frameworks
│   └── project.xcworkspace/
├── Cato/
│   ├── App/
│   │   ├── CatoApp.swift            # Điểm khởi chạy SwiftUI (@main) & giữ sáng màn hình
│   │   └── Info.plist               # Quyền Camera, GPS và Motion
│   ├── Models/
│   │   ├── DetectedVehicle.swift    # Data model xe, bounding box, làn đường
│   │   ├── SafetyState.swift        # 3 Trạng thái Safe / Caution / Danger & màu sắc
│   │   └── TripHistoryModels.swift  # Model GpsPoint, TripRecord, TimelineDay
│   ├── Detection/
│   │   ├── VehicleDetector.swift    # Apple Vision Framework nhận diện ô tô
│   │   └── CameraFeedManager.swift  # AVFoundation quản lý camera sau 720p/1080p
│   ├── Estimation/
│   │   ├── DistanceEstimator.swift  # Thuật toán hình học phối cảnh & bộ lọc EMA
│   │   └── SafetyThresholdManager.swift # Chuẩn Thông tư 38/2024 (35/55/70/100m)
│   ├── Audio/
│   │   └── AlertSoundManager.swift  # Âm thanh cảnh báo ADAS độ trễ thấp & haptic
│   ├── Location/
│   │   ├── LocationManager.swift    # CoreLocation GPS tốc độ & Demo mode
│   │   └── TiltSensorManager.swift  # CoreMotion đo góc nghiêng kính lái
│   ├── History/
│   │   └── TripHistoryManager.swift # Lưu vết GPS, phân loại chuyến đi & điểm đỗ
│   ├── Views/
│   │   ├── MainView.swift           # Điều phối toàn bộ vòng đời và các chế độ xem
│   │   ├── HUDOverlayView.swift     # Giao diện HUD radar mét, giây, km/h
│   │   ├── CameraView.swift         # View camera thực tế & bounding box
│   │   ├── SchematicView.swift      # View sơ đồ làn đường radar OLED
│   │   ├── ScreenOffView.swift      # View tắt màn hình tiết kiệm pin
│   │   ├── TripHistoryView.swift    # Màn hình liệt kê lịch sử chuyến đi theo ngày
│   │   ├── TripMapView.swift        # Màn hình vẽ lộ trình trên bản đồ Apple Maps
│   │   ├── SettingsView.swift       # Hộp thoại cài đặt chiều cao camera, buffer
│   │   └── DisclaimerView.swift     # Tuyên bố trách nhiệm pháp lý
│   └── Assets.xcassets/             # AppIcon và AccentColor (#2ECC71)
└── README.md
```

---

## 🛠️ Hướng Dẫn Mở & Build Trên Xcode

1. **Yêu cầu hệ thống**:
   - macOS với **Xcode 14.0** trở lên (Khuyên dùng Xcode 15 hoặc Xcode 16).
   - iOS Deployment Target: **iOS 15.0+** (tương thích mọi iPhone từ iPhone 6s, iPhone 7, 8, X, XS, 11, 12, 13, 14, 15, 16).

2. **Cách mở và Build**:
   - Mở thư mục dự án trên máy Mac hoặc trong Xcode:
     ```bash
     open Cato.xcodeproj
     ```
   - Chọn thiết bị mục tiêu: **iPhone Simulator** (ví dụ: *iPhone 15 Pro*) hoặc **iPhone thật của bạn**.
   - Bấm **`Cmd + R`** (hoặc nút **Play** ở góc trên thanh công cụ Xcode).
   - Dự án sẽ tự động biên dịch thành công và khởi chạy ứng dụng!

3. **Thử nghiệm trên Simulator**:
   - Khi chạy trên Simulator (không có camera phần cứng), ứng dụng tự động kích hoạt **Chế độ mô phỏng** với hình ảnh kính lái hoặc chế độ **Sơ đồ radar**.
   - Vào **Cài đặt** (biểu tượng bánh răng) $\rightarrow$ bật **Chế độ lái xe mô phỏng** để kéo thanh trượt tốc độ (ví dụ 82 km/h) và thử nghiệm cảnh báo.
   - Bấm vào biểu tượng **Bản đồ** ở góc trên để xem danh sách lịch sử hành trình theo ngày và xem vẽ lộ trình GPS trên bản đồ Apple Maps.

---

## 🚀 Đẩy Code Lên GitLab

Để đồng bộ lên kho chứa của bạn tại GitLab:

```bash
cd "c:\Users\ASUS\Downloads\cato ios"
git init
git add .
git commit -m "feat: Initial commit Cato iOS with Vision AI, ADAS alerts and GPS Trip History"
git branch -M main
git remote add origin https://gitlab.com/sondeptrai/autogap_ios.git
git push -u origin main
```

---

## 📜 Tuyên Bố Trách Nhiệm

> *"Đây là ước lượng, không phải thiết bị đo. Sai số tăng theo khoảng cách. Vạch xanh không phải giấy phép bám đuôi nhé."*
