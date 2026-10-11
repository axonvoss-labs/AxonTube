# AxonTube

[English](en.md) · [简体中文](zh-Hans.md) · [繁體中文](zh-Hant.md) · [日本語](ja.md) · [한국어](ko.md) · [Español](es.md) · [Français](fr.md) · [Deutsch](de.md) · [Italiano](it.md) · [Português](pt.md) · [Русский](ru.md) · [العربية](ar.md) · [हिन्दी](hi.md) · [Türkçe](tr.md) · **Tiếng Việt** · [ไทย](th.md) · [Bahasa Indonesia](id.md) · [Nederlands](nl.md) · [Polski](pl.md) · [Українська](uk.md) · [Svenska](sv.md) · [Dansk](da.md) · [Suomi](fi.md) · [עברית](he.md)

[README · English](../../README.md) · [README · 简体中文](../../README.zh-CN.md)

**Học các ngôn ngữ trên thế giới nhanh hơn cùng AI.**

Phiên bản 0.5.3 · Bản xem trước mã nguồn · Biên dịch từ mã nguồn

Biến YouTube thành lớp học ngôn ngữ của riêng bạn. Dùng phụ đề và bản dịch tự động của YouTube để học qua những video bạn yêu thích: đọc song song hai ngôn ngữ, phát lại từng câu và lưu giữ tài liệu hữu ích.

**24 ngôn ngữ giao diện · Phụ đề đa ngôn ngữ**

24 là số lựa chọn ngôn ngữ giao diện. Ngôn ngữ phụ đề phụ thuộc vào các luồng có sẵn của video đã chọn; đây không phải lời hứa giúp bạn thông thạo 24 ngôn ngữ.

## Ảnh chụp màn hình

Ảnh được chụp từ ứng dụng 0.5.3 thực tế. Ngôn ngữ giao diện trong ảnh được ghi riêng với ngôn ngữ của tài liệu này.

### Chào mừng và luồng thao tác chính

![Chào mừng và luồng thao tác chính](../assets/interface-en.png)

Bốn thao tác trên thanh công cụ, hai bộ chọn phụ đề hiển thị rõ, khẩu hiệu được bản địa hóa và trạng thái vô hiệu hóa rõ ràng trước khi mở video. — Ảnh ứng dụng với giao diện tiếng Anh

### Luyện tập theo từng câu

![Luyện tập theo từng câu](../assets/interface-study.png)

demo.mp4 — Tìm câu, nhấp để chuyển đến thời điểm tương ứng, câu trước / sau, phát lại, lặp, điều chỉnh tốc độ phát và theo dõi câu hiện tại. — Ảnh ứng dụng với giao diện tiếng Anh

### Phụ đề thứ nhất và thứ hai

![Phụ đề thứ nhất và thứ hai](../assets/interface-caption-languages.png)

Ảnh chụp thực tế giao diện tiếng Anh với hai danh sách chọn phụ đề độc lập, mặc định là tiếng Anh và tiếng Trung phồn thể. — Ảnh ứng dụng với giao diện tiếng Anh

### Mở liên kết YouTube

![Mở liên kết YouTube](../assets/interface-youtube-dialog.png)

Ảnh chụp thực tế hộp thoại liên kết trong giao diện tiếng Anh. Mở liên kết sẽ bắt đầu phát và yêu cầu cặp phụ đề đã chọn. — Ảnh ứng dụng với giao diện tiếng Anh

## Bắt đầu sử dụng

### 1. Mở YouTube

Dán liên kết video. Phụ đề có sẵn được yêu cầu tự động, với tiếng Anh ở luồng thứ nhất và tiếng Trung phồn thể ở luồng thứ hai. Lần lấy đầu tiên có thể mất khoảng 1–2 phút; không bảo đảm luôn có phụ đề.

### 2. Chọn và luyện tập

Dùng hai danh sách chọn phụ đề đang hiển thị. Nhấp vào một câu để chuyển đến câu đó, phát lại hoặc bật lặp câu.

### 3. Lưu hoặc xuất

Lưu video cho phép chọn thư mục chứa nội dung truy cập được và phụ đề có sẵn. Xuất phụ đề song ngữ tạo tệp Word, TXT hoặc SRT từ phụ đề đã tải.

### 4. Tùy chỉnh theo ý bạn

Thay đổi ngôn ngữ giao diện, tốc độ phát, cỡ phụ đề và độ lệch thời gian của từng luồng. Ứng dụng ghi nhớ lựa chọn ngôn ngữ giao diện và phụ đề.

## Tính năng hiện có

### Hai luồng phụ đề độc lập

Mặc định là tiếng Anh và tiếng Trung phồn thể; chọn trong các bản gốc và bản dịch tự động có sẵn của video hiện tại. Phụ đề luồng thứ nhất đã lấy thành công vẫn dùng được nếu luồng thứ hai thất bại.

### Luyện tập theo từng câu

Tìm câu, nhấp để chuyển đến thời điểm tương ứng, câu trước / sau, phát lại, lặp, điều chỉnh tốc độ phát và theo dõi câu hiện tại.

### Video kèm phụ đề đồng bộ

Vẫn có thể lưu trong khi phụ đề đang tải. Mỗi thao tác tạo một thư mục mới chứa video truy cập được; nếu có phụ đề, các luồng SRT kèm mốc thời gian và tệp đọc song ngữ sẽ được thêm vào. Cũng hỗ trợ lưu video không kèm phụ đề. Phần chưa hoàn tất nằm trong thư mục .partial.

### Xuất Word, TXT và SRT

Xuất phụ đề có sẵn sau khi áp dụng độ lệch thời gian. Word và TXT ghép văn bản theo phần giao nhau của khoảng thời gian. Nếu chỉ tải được một luồng, vẫn có thể xuất nội dung của luồng đó.

### Giao diện được bản địa hóa sang 24 ngôn ngữ

Menu, thông báo trạng thái và khẩu hiệu học tập cùng chuyển ngôn ngữ. Tiếng Ả Rập và tiếng Do Thái hỗ trợ bố cục từ phải sang trái; đổi ngôn ngữ giao diện không làm thay đổi nội dung phụ đề.

### Phát tệp cục bộ và điều khiển rõ ràng

Mở tệp nội dung và phụ đề cục bộ từ menu Tệp. Thao tác bị vô hiệu hóa được làm mờ kèm lý do; chế độ đã chọn được tô nổi và đánh dấu; quá trình lưu hiển thị trạng thái đang xử lý.

## Lợi ích

### Từ xem đến luyện tập chỉ vài bước

Bốn thao tác trên thanh công cụ giữ luồng chính đơn giản: YouTube → Lưu video → Phụ đề → Ngôn ngữ. Không cần thêm nút lấy phụ đề.

### Tài liệu học có thể giữ lại

Phụ đề có mốc thời gian và tệp Word / TXT dễ đọc hỗ trợ cả luyện nghe lẫn ôn tập sau này. Các bản xuất dùng vị trí lưu mới và giữ nguyên tệp gốc.

### Làm việc cục bộ, không cần khóa API AI

Nội dung cục bộ và phụ đề đã lưu hoạt động ngoại tuyến. YouTube cung cấp phụ đề trang web và bản dịch tự động; ứng dụng không thu thập dữ liệu đo từ xa, không tải nội dung cục bộ lên và không yêu cầu khóa API AI trả phí.

## Vấn đề còn tồn tại và giới hạn

### P0 · Khả năng truy cập phụ đề và video YouTube

**Xác minh dịch vụ trực tiếp**

Lần kiểm tra trực tiếp gần nhất gặp yêu cầu đăng nhập / xác minh chống bot của YouTube. Chưa xác nhận được việc tải trực tuyến thành công trong điều kiện hiện tại. Cần xác minh trên mạng dự kiến sử dụng và với các video đại diện trước khi phát hành công khai.

### P1 · Nhúng video và video bị giới hạn theo tài khoản

**Hạn chế của nền tảng**

Một số nhà sáng tạo hoặc video không cho phép phát nhúng. Chưa triển khai Google SSO trong ứng dụng; lối tắt mở trình duyệt dùng phiên đăng nhập và phát riêng. Không thể trình bày các hạn chế này như đã được giải quyết.

### P1 · Ký ứng dụng và kiểm thử trên nhiều máy Mac hơn

**Phân phối và tương thích**

Gói được ký ad-hoc, chưa có công chứng Developer ID. Đã kiểm thử Apple Silicon trên macOS 26.5.2; chưa kiểm thử macOS 27 và máy Mac dùng Intel. macOS 14 là phiên bản triển khai tối thiểu mục tiêu, không phải bằng chứng đã kiểm thử mọi phiên bản.

### P2 · Chất lượng tải xuống và độ chính xác của phụ đề

**Giới hạn định dạng và chất lượng**

Việc lưu dùng một luồng đầy đủ gồm cả âm thanh và hình ảnh, không ghép các luồng độ phân giải cao riêng biệt. Phát cục bộ phụ thuộc vào khả năng hỗ trợ codec. Chuyển đổi tùy chọn bằng FFmpeg có thể không giữ lại các luồng âm thanh bổ sung, HDR và phụ đề nhúng. Nhập ASS/SSA chỉ lấy văn bản. Phụ đề tự động, bản dịch và cách ghép song ngữ dựa trên thời gian có thể có lỗi.

### P2 · Lịch sử học và công cụ học tập

**Chưa triển khai**

Chưa triển khai khôi phục lịch sử phát, bộ sưu tập từ vựng, ôn tập ngắt quãng, OCR và trích xuất phụ đề dạng ảnh. Lưu lựa chọn ngôn ngữ không có nghĩa là lưu tiến độ học.

### P2 · Rà soát ngôn ngữ bởi người bản ngữ

**Rà soát biên tập**

Cả 24 lựa chọn ngôn ngữ giao diện và khẩu hiệu được bản địa hóa đã vượt qua kiểm tra chuyển đổi. Điều đó xác nhận phạm vi hỗ trợ và hành vi, không phải việc mọi bản dịch đã được người bản ngữ rà soát chuyên nghiệp.

## Những gì đã được xác minh

Với 0.5.3: đã vượt qua 105 kiểm tra lõi, 138 phép kiểm chứng mô hình, 29 kiểm tra phụ đề, 60 kiểm tra lưu video và 317 phép kiểm chứng giao diện gốc. Cả 24 ngôn ngữ đã được chọn trong menu thực tế; đã rà soát giao diện ở sáu ngôn ngữ và bố cục thu gọn bằng tiếng Đức.

Đã xác minh phát cục bộ, xuất tệp, chuyển trạng thái và hộp thoại lưu gốc. Dữ liệu kiểm thử ngoại tuyến và các bài kiểm thử lưu bằng công cụ trợ giúp giả lập không chứng minh YouTube hiện cho phép tải phụ đề hoặc video trực tuyến. Không nhập thông tin xác thực của người dùng.

[Bản ghi xác minh chi tiết](../VERIFICATION.md) · [README · EN](../../README.md) · [README · 简体中文](../../README.zh-CN.md)

[HTML (offline)](../product-guide.html#vi)

Ứng dụng dùng giấy phép MIT; các thành phần bên thứ ba giữ nguyên thông báo của mình. AxonTube không có quan hệ liên kết với YouTube, Google hay Apple.

Ngày tài liệu: 2026-10-11
