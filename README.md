# Hệ thống Đăng ký Workshop và Quản lý Danh sách chờ Tự động (FIFO)

Nền tảng web hỗ trợ sinh viên và các đơn vị tổ chức (Khoa, Câu lạc bộ, Đoàn - Hội) tối ưu hóa quy trình đăng ký workshop, tự động hóa điều phối danh sách chờ theo nguyên tắc FIFO (First-In, First-Out) và ngăn ngừa lãng phí suất tham dự.

---

## 1. Vấn đề và Giải pháp

### Bối cảnh & Vấn đề thực tế
Tại các trường đại học, thông tin workshop thường bị phân mảnh trên nhiều kênh mạng xã hội, gây khó khăn cho sinh viên trong việc tiếp cận kịp thời. Quy trình đăng ký hiện tại chủ yếu sử dụng các biểu mẫu trực tuyến (Google Forms, Microsoft Forms) với nhiều bất cập lớn:
- **Biểu mẫu tự động đóng khi đủ số lượng:** Những sinh viên đến sau mất hoàn toàn cơ hội tham gia.
- **Không có cơ chế chuyển suất minh bạch khi có người hủy:** Sinh viên đã đăng ký nhưng bận đột xuất không có cách hủy thuận tiện, dẫn đến tình trạng "cháy vé ảo" nhưng ghế hội trường thực tế bị bỏ trống.
- **Tốn nhiều công sức đối soát thủ công:** Ban tổ chức phải tự lọc danh sách, liên hệ từng người để bù chỗ.

### Giải pháp của hệ thống
Hệ thống cung cấp một giải pháp phần mềm tập trung giải quyết triệt để các vấn đề trên:
- **Nền tảng tra cứu tập trung:** Cung cấp cổng thông tin workshop thống nhất, cho phép tìm kiếm, lọc theo chuyên mục, thời gian và trạng thái tiếp nhận.
- **Cơ chế Danh sách chờ tự động (Automated FIFO Waiting List):** Khi một workshop đạt giới hạn sức chứa, sinh viên vẫn có thể đăng ký vào danh sách chờ.
- **Tự động thăng hạng suất tham dự (Auto-promotion):** Khi có sinh viên trong danh sách chính thức hủy tham gia hợp lệ, hệ thống sẽ tự động kích hoạt chuyển suất cho sinh viên đứng đầu danh sách chờ theo thứ tự thời gian (FIFO), bảo đảm tối đa hóa số người tham dự và không bao giờ vượt quá sức chứa quy định.

---

## 2. Các Tính năng Chính

### 2.1. Dành cho Sinh viên
* **Khám phá & Tra cứu:** Xem danh mục các workshop đang mở, sắp diễn ra; tìm kiếm theo từ khóa; lọc theo chủ đề và thời gian.
* **Xem thông tin chi tiết:** Xem nội dung chương trình, diễn giả, thời gian, địa điểm, sức chứa và số lượng suất còn lại.
* **Đăng ký linh hoạt:**
  * Đăng ký nhận vé chính thức khi workshop còn chỗ trống.
  * Tự động đăng ký vào danh sách chờ (Waiting List) khi workshop đã đủ sức chứa.
* **Theo dõi trạng thái cá nhân (My Workshops):**
  * Xem trạng thái vé của mình (Chính thức, Danh sách chờ, Đã hủy).
  * Hiển thị trực quan số thứ tự hiện tại trong hàng chờ (ví dụ: *Bạn đang ở vị trí #2*).
* **Hủy đăng ký chủ động:** Cho phép sinh viên hủy vé chính thức hoặc rút khỏi danh sách chờ khi thay đổi lịch trình cá nhân.

### 2.2. Dành cho Ban Tổ Chức (Khoa / Câu lạc bộ)
* **Quản lý Workshop:** Tạo mới workshop, chỉnh sửa thông tin, tải lên hình ảnh banner, cập nhật sức chứa và thời hạn đăng ký.
* **Kiểm soát tiếp nhận:** Chủ động đóng hoặc mở lại cổng đăng ký khi cần thiết; hủy tổ chức workshop nếu có trường hợp bất khả kháng.
* **Quản trị người tham gia:**
  * Theo dõi danh sách đăng ký chính thức và số lượng thực tế so với sức chứa.
  * Theo dõi danh sách chờ theo đúng thứ tự thời gian đăng ký (FIFO).
  * Tìm kiếm sinh viên và xuất danh sách điểm danh phục vụ khâu check-in thực tế.

### 2.3. Tính năng Hệ thống & Đảm bảo Tính nhất quán
* **Bảo đảm sức chứa & Chống xung đột (Concurrency):** Xử lý an toàn khi nhiều sinh viên cùng bấm đăng ký vào giây cuối cùng, tuyệt đối không để xảy ra tình trạng vượt sức chứa (overbooking) hoặc đăng ký trùng.
* **Thuật toán FIFO chuẩn xác:** Quản lý hàng đợi dựa trên timestamp chuẩn, cập nhật trạng thái tức thời khi có biến động về chỗ trống.
* **Xác thực & Phân quyền (RBAC):** Kiểm soát quyền truy cập chặt chẽ giữa vai trò Sinh viên và Ban tổ chức.

---

## 3. Kiến trúc & Công nghệ

> **Ghi chú:** Thông tin chi tiết về các framework, ngôn ngữ lập trình, kiến trúc triển khai và hướng dẫn cài đặt môi trường phát triển sẽ được cập nhật đầy đủ sau khi nhóm hoàn tất giai đoạn thiết kế kỹ thuật.
