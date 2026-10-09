# P2: kiểm tay của owner (VK-346)

Chạy trên **iPad Air (iPadOS 27)** thật và **iPhone 16 Plus** thật. Agent
không có GUI/VoiceOver/xoay máy nên các mục dưới là phần còn lại của Task 5.
Đã có sẵn trên simulator (iPad 26.5): pill native, sidebar overlay dọc, trailing
và footer, đẩy trang che chrome, iPhone dùng chrome Flutter.

## Cài bản example

```bash
cd liquid_shell/example
fvm flutter build ios --release          # hoặc --debug
xcrun devicectl list devices             # lấy <UDID> của iPad đang cắm
xcrun devicectl device install app --device <UDID> build/ios/iphoneos/Runner.app
xcrun devicectl device process launch --device <UDID> vn.lasoai.liquidShellExample
```

Nếu cần log: `fvm flutter run -d <UDID>` thay cho ba lệnh cuối.

## iPad Air (iPadOS 27)

Đánh dấu `[x]` khi đạt; ghi lại nếu không đạt (kèm ảnh/quay màn hình).

- [ ] **Ảnh ngang (landscape):** xoay ngang. Sidebar tiled (không overlay),
      nội dung hẹp lại, không nhảy. Chụp màn hình, lưu thành
      `liquid_shell/doc/images/native_ipad_landscape.png` rồi báo lại.
- [ ] **Dọc:** chạm nút sidebar. Sidebar overlay mở, nội dung bên dưới màn mờ
      **không** dịch chuyển. Chạm một hàng: tab đổi, sidebar đóng.
- [ ] **Resize cửa sổ / clearance:** bật cửa sổ nổi (floating), kéo đổi kích
      thước nhiều cỡ. Tiêu đề trang (hàng trên cùng) **tránh** nút `•••` /
      đóng-thu nhỏ; ở full screen không bị thụt. Trong sidebar tiled, tiêu đề
      trang không bị đẩy. Lúc đẩy/pop trang, tiêu đề không trượt lạ.
- [ ] **Clearance khi chrome native bật** (case "Native chrome", cửa sổ
      nổi): thanh tab / sidebar native tự né nút `•••`; tiêu đề trang
      **không** thụt 66pt (giá trị window controls là 0 khi chrome native
      hiện). Đẩy một trang lên (chrome native ẩn): tiêu đề trang đó né nút
      `•••` như ở chrome Flutter.
- [ ] **Split View:** mở cùng app ở 1/3 màn hình: chỉ còn thanh dưới Flutter
      (không có chrome native). Kéo lên 1/2 và 2/3: quay lại native khi đủ
      rộng. Không thấy hai chrome cùng lúc.
- [ ] **VoiceOver:** bật VO. Đọc đúng tên các tab, nút bật/tắt sidebar, nút
      ⌕ (trailing) và footer ("Ann Lee ..."). Vuốt qua được hết, footer kích
      hoạt được. (Nhãn nút sidebar do hệ thống, theo ngôn ngữ máy.)
- [ ] **Chạm và cuộn thật quanh chrome native** (XCTest chỉ gọi `hitTest`,
      không gửi chạm thật): chạm và cuộn nội dung **ngay dưới** pill, sát
      **hai bên** pill, và sát **mép** sidebar tiled (ngang). Nội dung
      Flutter nhận chạm/cuộn; pill, hàng sidebar, vùng trống của sidebar và
      footer vẫn là của UIKit. Lặp lại ở dọc với sidebar overlay: chạm vùng
      mờ đóng sidebar, không chạm xuyên xuống nội dung.
- [ ] **Dialog trên chrome:** mở một dialog / bottom sheet từ một trang. Chạm
      ngoài dialog thì đóng (chạm xuyên qua chrome native tới barrier), không
      chạm nhầm tab. Đẩy trang chi tiết: chrome native ẩn, pop thì hiện lại.
- [ ] **Guard bị từ chối:** bật "unsaved changes" trong example, chạm hàng
      sidebar khác rồi từ chối: hàng được chọn cũ vẫn sáng (không kẹt hàng
      mới). Footer **không** đi qua guard (đúng thiết kế).
- [ ] **Scene reconnect:** Stage Manager/App Exposé: đóng cửa sổ app (vuốt
      loại scene, không kill app) rồi mở lại từ icon. Chrome native quay lại
      đúng tab đã chọn và đúng số badge.
- [ ] **Hot restart** (nếu chạy `flutter run`): bấm `R`, chrome native vẫn
      đúng (không trống, không lệch tab).
- [ ] **Không nháy chrome Flutter** lúc mở app lạnh (chỉ trống 1-2 frame).

## iPhone 16 Plus

- [ ] Mở app: chrome **Flutter** (thanh dưới glass), không có sidebar native.
- [ ] Xoay ngang: vẫn chrome Flutter, không nháy trống ở lúc mở.
- [ ] Đẩy trang chi tiết rồi quay lại: không lỗi; tab/badge đúng.

## Báo kết quả

Gửi lại: danh sách mục đạt/không đạt, ảnh landscape, và bất kỳ mục nào lạ.
