# P2: kiểm tay của owner (VK-346)

Chạy trên **iPad Air (iPadOS 27)** thật và **iPhone 16 Plus** thật. Agent
không có GUI/VoiceOver/xoay máy nên các mục dưới là phần còn lại của Task 5.
Đã có sẵn trên simulator (iPad 26.5/27.0, iPhone 26.5): pill native, sidebar
overlay dọc, sidebar tiled ngang (thân Flutter nằm cạnh sidebar), trailing và
footer, đẩy trang che chrome, guard với dialog, iPhone dùng thanh tab native
nổi ở đáy (Task 7, quyết định D1), cả iPhone 17 Pro Max ngang; iPad ngang
(26.5 và 27.0) sidebar tiled. Cửa sổ iPad hẹp 375pt chỉ có trong XCTest (một
`UIWindow` hẹp, không phải Split View thật). Hit test chạy trên cây view UIKit
thật trong XCTest (`make ios-unit`), nhưng chỉ gọi `hitTest`, không phải chạm
thật.

## Cài bản example

```bash
cd liquid_shell/example
fvm flutter build ios --release          # hoặc --debug
xcrun devicectl list devices             # lấy <UDID> của iPad đang cắm
xcrun devicectl device install app --device <UDID> build/ios/iphoneos/Runner.app
xcrun devicectl device process launch --device <UDID> vn.lasoai.liquidShellExample
```

Nếu cần log: `fvm flutter run -d <UDID>` thay cho ba lệnh cuối.

Bản Task 7c do controller cài sẵn (`Runner.app` build profile, team
`7T48W99FC5`, bundle id tạm `vn.lasoai.liquidshell.example`): mở app
"Liquid Shell Example" trên máy, chọn case **"Native chrome"**.

## iPad Air (iPadOS 27)

Đánh dấu `[x]` khi đạt; ghi lại nếu không đạt (kèm ảnh/quay màn hình).

- [ ] **Ảnh ngang (landscape):** xoay ngang. Sidebar tiled (không overlay),
      nội dung hẹp lại, không nhảy. So với ảnh simulator iPadOS 27
      `liquid_shell/doc/images/native_ipad_landscape.png`; khác thì chụp màn
      hình gửi lại.
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
- [ ] **Cửa sổ hẹp / Split View (D1):** thu cửa sổ thật hẹp hoặc 1/3 màn
      hình: thanh tab **native** Liquid Glass nổi ở đáy (không còn viên
      Flutter), ⌕ là nút tròn riêng ở cuối, badge "3" trên Inbox, không có
      "Reports" (chỉ có trong sidebar). Kéo rộng lại: thanh trên + sidebar
      native. Không thấy hai chrome cùng lúc; nội dung không nhảy; tiêu đề
      trang vẫn né nút `•••` khi thanh ở đáy.
- [ ] **Badge trên chrome native:** badge "3" trên Inbox ở thanh trên, ở
      hàng Inbox trong sidebar và ở thanh đáy khi cửa sổ hẹp; số không bị
      cắt, không lệch khi đổi tab.
- [ ] **Nút ⌕ (tab tìm kiếm):** ở thanh trên (đầu phải), ở hàng đầu sidebar
      và là nút tròn riêng khi cửa sổ hẹp. Chạm: số "Searches" tăng; **không**
      mở ô tìm kiếm hệ thống, thanh không biến dạng, ⌕ không bao giờ ở
      trạng thái được chọn (ô đang sáng vẫn là tab hiện tại).
- [ ] **Chọn tab chỉ-có-trong-sidebar rồi thu hẹp:** cửa sổ rộng, mở sidebar,
      chọn "Reports". Thu cửa sổ hẹp (Split View / Stage Manager): nội dung
      vẫn là Reports, thanh đáy sáng ô **Home** (ô đầu), **không** sáng ⌕.
      Chạm Home: sang Home. Kéo rộng lại: sidebar/thanh trên đúng tab.
- [ ] **Dáng sidebar iPadOS 27:** sidebar là tấm xám mờ phủ kín mép trái,
      không bo góc/nổi như iPadOS 26. Đó là dáng của chính hệ thống (Photos,
      Health trên iPadOS 27 giống hệt), không phải lỗi của liquid_shell.
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
- [ ] **Guard bị từ chối** (case **"Native chrome"**, không phải case
      "Discard guard": case đó không có `sfSymbol` nên luôn vẽ chrome
      Flutter): bật "Unsaved changes".
      - Thanh tab native: chạm "Inbox" → hiện "Discard changes?", chạm
        "Keep editing": vẫn ở Home, ô Home trên thanh tab vẫn sáng (không
        nháy/kẹt ô Inbox). Chạm lại "Inbox" → "Discard": sang Inbox.
      - Dọc, sidebar overlay: mở sidebar, bật lại "Unsaved changes" nếu cần,
        chạm hàng "Inbox": sidebar **đóng trước**, dialog hiện trọn vẹn,
        không bị sidebar/màn mờ che. "Keep editing": hàng/ô Home vẫn chọn.
      - Footer **không** đi qua guard (đúng thiết kế).
      (Simulator đã chạy tự động: `native_shell_test.dart`, "a dirty page".)
- [ ] **Scene reconnect:** Stage Manager/App Exposé: đóng cửa sổ app (vuốt
      loại scene, không kill app) rồi mở lại từ icon. Chrome native quay lại
      đúng tab đã chọn và đúng số badge.
- [ ] **Hot restart** (nếu chạy `flutter run`): bấm `R`, chrome native vẫn
      đúng (không trống, không lệch tab).
- [ ] **Không nháy chrome Flutter** lúc mở app lạnh (chỉ trống 1-2 frame).

## iPhone 16 Plus

- [ ] Mở app (case "Native chrome"): thanh tab **native** Liquid Glass nổi ở
      đáy `[Home | Inbox ③ | Settings]`, ⌕ tròn riêng ở cuối, badge "3" trên
      Inbox, không có "Reports". Hàng cuối danh sách cuộn được lên trên
      thanh (không bị che). Ảnh mẫu: `liquid_shell/doc/images/native_iphone.png`.
- [ ] Chạm tab: đổi tab; bật "Unsaved changes" rồi chạm tab khác → dialog
      "Discard changes?", "Keep editing" giữ nguyên tab.
- [ ] Lúc dialog "Discard changes?" hiện: thanh native ẩn, danh sách phía
      sau **không nhảy** (giữ nguyên khoảng cách đáy); đóng dialog thì thanh
      hiện lại, danh sách vẫn đứng yên.
- [ ] Chạm ⌕: số "Searches" tăng, không mở ô tìm kiếm hệ thống, ⌕ không ở
      trạng thái được chọn.
- [ ] Xoay ngang (16 Plus ngang có size class **regular**): vẫn thanh native
      nổi ở **đáy**, không có thanh trên/sidebar, vẫn không có "Reports";
      không nháy trống ở lúc mở.
- [ ] Đẩy trang chi tiết rồi quay lại: thanh ẩn khi trang che, hiện lại khi
      pop; tab/badge đúng.

## Báo kết quả

Gửi lại: danh sách mục đạt/không đạt, ảnh landscape, và bất kỳ mục nào lạ.
