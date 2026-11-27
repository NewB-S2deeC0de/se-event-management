# API Contract — Workshop & FIFO

## 1. Phạm vi, trạng thái và nguồn

**Draft / Proposed — Needs team review, 27/11/2026.** Chưa được nhóm phê duyệt.
Nhánh: `feat/api-contract-specs`; base đã kiểm tra: `main` tại
`222d312343c6d817e272c3f95fecdc987dab7252`. Chỉ đặc tả API; không triển khai
backend, UI, SQL, deploy hay kiểm thử runtime. Mọi lựa chọn thiết kế dưới đây là
proposed default cho đến khi nhóm review. Model API không ép tên cột SQL.

Nguồn nội bộ: [README](../README.md), [LLM usage](../LLM_USAGE.md),
[PR template](../.github/PULL_REQUEST_TEMPLATE.md). Đã đọc các issue liên kết ngày
27/11/2026; remote chỉ có `main`, chưa có `docs/` hoặc `database/schema.sql`.

| Yêu cầu đã xác định | Phạm vi contract / nguồn |
|---|---|
| Auth, RBAC; FR-10 tạo workshop | [#3](https://github.com/NewB-S2deeC0de/se-event-management/issues/3) |
| FR-01 danh sách, FR-03 chi tiết | [#4](https://github.com/NewB-S2deeC0de/se-event-management/issues/4), [#5](https://github.com/NewB-S2deeC0de/se-event-management/issues/5) |
| Backend, health | [#6](https://github.com/NewB-S2deeC0de/se-event-management/issues/6) |
| FR-10 sửa, đóng/mở, hủy sự kiện | [#8](https://github.com/NewB-S2deeC0de/se-event-management/issues/8) |
| FR-02 tìm/lọc, FR-11 roster/export | [#9](https://github.com/NewB-S2deeC0de/se-event-management/issues/9) |
| FR-04/05/07/08/12 đăng ký, chờ, hủy, My Workshops, chống trùng | [#10](https://github.com/NewB-S2deeC0de/se-event-management/issues/10) |
| FR-06/07/12 FIFO transaction | [#11](https://github.com/NewB-S2deeC0de/se-event-management/issues/11) |
| E2E, NFR-04 concurrency, edge cases | [#12](https://github.com/NewB-S2deeC0de/se-event-management/issues/12), [#13](https://github.com/NewB-S2deeC0de/se-event-management/issues/13), [#14](https://github.com/NewB-S2deeC0de/se-event-management/issues/14) |
| Schema và deliverable cần review chéo | [#1](https://github.com/NewB-S2deeC0de/se-event-management/issues/1), [#2](https://github.com/NewB-S2deeC0de/se-event-management/issues/2) |

Chưa có SRS đầy đủ 12 FR / 6 NFR: FR-09 và NFR ngoài NFR-04 chưa xác định;
không tuyên bố coverage đầy đủ. #1 và #2 cần thống nhất trước khi #3–#6 triển khai.

## 2. Quy ước chung

- App REST: `/api/v1`, JSON UTF-8, `Content-Type: application/json`;
  `/health` ngoài prefix. CSV và multipart là ngoại lệ.
- Field `snake_case`; ID là string opaque không rỗng, ví dụ `w1`, không suy ra UUID.
  Timestamp ISO 8601 UTC dạng `2026-12-10T02:00:00Z`; FE đổi múi giờ hiển thị.
  Server quyết định thời gian, gate và FIFO.
- Thành công: `{"data": ...}`. List thêm `pagination` với `page`, `limit`, `total`
  là integer; total sau filter, trước phân trang. Empty/out-of-range page: 200, `[]`.
- Query `page` mặc định 1, integer >=1; `limit` mặc định 20, integer 1–100.
  Unknown query/body field, read-only field, enum/date/number sai: 400.
  Không ép kiểu chuỗi thành number trong JSON; query số phải là số nguyên thập phân.
- Lỗi: `error.code`, `error.message` là string; `error.details` optional array
  `{field: string, message: string}`. Không lộ SQL, stack, token hoặc PII.
- 200 read/update/cancel; 201 create/register/upload; 400 validation; 401 token;
  403 quyền; 404 thiếu resource; 409 conflict; 413 quá lớn; 415 sai media;
  500 unexpected. Không dùng 200 cho lỗi, không dùng 409 khi vào chờ thành công.
  Không có app logout/204 trong phương án này; nếu có 204 tương lai thì không body.
- GET không side effect. Không có DELETE, promote, force-confirm, set-position
  hay join-waitlist riêng. Không có notification, QR, websocket hoặc check-in API.
- Tất cả list có thứ tự xác định kèm ID/tie-breaker; response là snapshot nhất quán
  tại thời điểm đọc, có thể thay đổi ngay sau đó. FE refetch sau mutation và khi
  quay lại màn hình; cơ chế refresh nền cần nhóm chốt, chưa hứa push tức thì.

Ví dụ empty list:

```json
{"data":[],"pagination":{"page":1,"limit":20,"total":0}}
```

## 3. Auth và phân quyền

Chọn **Supabase Auth SDK trực tiếp**, không thêm `/auth/login`, `/auth/register`,
`/auth/refresh`, `/auth/logout` vào app API. Đây là flow provider, không áp dụng
JSON envelope/status/error matrix của app cho response SDK.

| SDK operation | Input / kết quả / lỗi |
|---|---|
| `signUp` | `{email, password, options: {data: {display_name}}}`; trả `{data: {user, session}, error}`. Đề xuất bật email confirmation: session có thể null; UI yêu cầu xác nhận trước login. Không suy ra email tồn tại từ kết quả signup. |
| `signInWithPassword` | `{email, password}`; `{data: {user, session}, error}`; session thành công chứa access/refresh token. Sai credentials hiển thị thông báo chung; email chưa xác nhận yêu cầu xác nhận. |
| `refreshSession` | Dùng session hiện tại hoặc `{refresh_token}`; `{data: {user, session}, error}`; dùng session mới do SDK trả về; invalid refresh buộc login lại. |
| `signOut` | Đề xuất `{scope: "local"}` cho thiết bị hiện tại; `{error}`. Xử lý lỗi mạng, không tự báo đã revoke server thành công. Access JWT đã cấp vẫn có thể hợp lệ đến expiry. |

SDK error giữ `message`, `status`, `code` nếu có: UI phân loại credentials/email
confirmation/validation/rate limit/network bằng mã provider tại phiên bản SDK đã
chọn; không đổi chúng thành mã app giả. Không log password/token. Không ghi giá trị
credentials trong ví dụ. Tham khảo chính thức:
[signUp](https://supabase.com/docs/reference/javascript/auth-signup),
[signInWithPassword](https://supabase.com/docs/reference/javascript/auth-signinwithpassword),
[refreshSession](https://supabase.com/docs/reference/javascript/auth-refreshsession),
[signOut](https://supabase.com/docs/reference/javascript/auth-signout).

App nhận `Authorization: Bearer <access_token>`, kiểm tra signature, issuer,
audience, expiry theo cấu hình Supabase và map identity sang profile/role tin cậy.
Không tin token chỉ decode ở FE, metadata role, `user_id`, `organizer_id` do client
cung cấp. Signup công khai chỉ tạo student; profile được tạo idempotent phía server
qua quy trình tin cậy của #1/#3 trước khi gọi app. Profile chưa sẵn sàng: 403
`FORBIDDEN`, không tự nâng quyền. Organizer được provision qua quy trình nhóm chốt.
Service-role key chỉ ở server; không xuất hiện trong FE hoặc response.

Public browse không cần token; nếu gửi token thì token sai trả 401. Route protected:
thiếu/sai/hết hạn token 401; sai role hoặc owner 403. Không trả email, roster hay
thông tin vé trong public workshop. Student chỉ đọc/hủy registration của mình;
organizer chỉ quản lý/roster/export workshop có `organizer_id` của mình.

### GET /auth/me

Path đầy đủ: `/api/v1/auth/me`.

Student/Organizer; không query/body; không side effect. 200:

```json
{"data":{"id":"u1","email":"an@example.org","display_name":"An","role":"student"}}
```

Lỗi: 401 `UNAUTHENTICATED`; 403 `FORBIDDEN` nếu thiếu profile; 500 chung.

### GET /health

Public; không query/body; liveness tối thiểu, không kiểm DB/readiness, không lộ config.
200, không side effect; 500 khi lỗi bất ngờ (không định nghĩa 503 readiness).

```json
{"data":{"status":"ok"}}
```

## 4. Logical resource models

Trong bảng: R = luôn có trong response; C = bắt buộc khi create; U = được PATCH
(optional nhưng không null). Field chỉ R là read-only; null chỉ được phép khi ghi rõ.
Không có field tùy ý khác. Chuỗi input trim trước validation; đề xuất giới hạn theo
số Unicode code point, cần đối chiếu SRS. Mọi object con dùng schema dưới đây.

### UserProfile

| Field | Type / hiện diện / null | Ràng buộc |
|---|---|---|
| id | string R, non-null | Identity profile tin cậy |
| email | string R, non-null | Email provider; chỉ bản thân hoặc owner roster |
| display_name | string R, non-null | Signup bắt buộc, 1–100 ký tự |
| role | enum R, non-null | `student`, `organizer`; server quản lý |

Không yêu cầu MSSV khi SRS/schema chưa xác nhận. `StudentSummary` chỉ gồm
`id`, `display_name`, `email` cùng kiểu trên, không có role.

### Workshop (detail, create/update/status/cancel response)

| Field | Type / hiện diện / null | Validation / ý nghĩa |
|---|---|---|
| id, organizer_id | string R, non-null | Owner lấy từ auth |
| title | string R/C/U, non-null | 1–200 ký tự |
| description | string R/C/U, non-null | 1–10000, plain text |
| speaker, location | string R/C/U, non-null | Mỗi field 1–200 |
| category | string R/C/U, non-null | 1–100; free-text, filter exact không phân biệt hoa thường |
| banner_url | string R, nullable | URL do server cấp; ban đầu null, chỉ upload thay đổi |
| start_at, end_at, registration_deadline | timestamp R/C/U, non-null | `end_at > start_at`, `registration_deadline <= start_at` |
| capacity | integer R/C/U, non-null | 1–2147483647; không dưới confirmed_count |
| confirmed_count, remaining_slots, waitlist_count | integer R, non-null | >=0; remaining_slots = capacity − confirmed_count |
| registration_status | enum R, non-null | Manual `open`, `closed`; create mặc định open |
| event_status | enum R, non-null | `active`, `cancelled`; create active |
| is_registration_available | boolean R, non-null | active AND manual open AND now < deadline AND now < start |
| created_at, updated_at | timestamp R, non-null | Server-generated |

Create yêu cầu deadline và start còn tương lai. PATCH validate toàn bộ merged
resource; deadline/start mới phải còn tương lai. Chỉ sửa event active chưa bắt đầu.
Full vẫn có thể available để nhận waitlist. Filter `registration_status=open|closed`
là **effective**: open khi is_registration_available=true, closed khi false; field
response registration_status luôn là manual. Không đồng nhất full với closed.

`WorkshopSummary` dùng mọi field Workshop trừ `description`, `speaker`,
`organizer_id`, `created_at`, `updated_at`; giữ `location`, counts và hai status.

### Registration

| Field | Type / hiện diện / null | Ý nghĩa |
|---|---|---|
| id, workshop_id | string R, non-null | ID giữ nguyên khi waitlisted -> confirmed |
| status | enum R, non-null | `confirmed`, `waitlisted`, `cancelled` |
| registered_at | timestamp R, non-null | Thời điểm server tạo lần đăng ký này |
| confirmed_at | timestamp R, nullable | Có khi đã từng confirmed; giữ sau hủy |
| cancelled_at | timestamp R, nullable | Chỉ non-null khi cancelled |
| cancellation_reason | enum R, nullable | null nếu active; `student_cancelled`, `workshop_cancelled` khi hủy |
| queue_position | integer R, nullable | >=1 chỉ khi waitlisted; dynamic rank |
| ticket | object R, nullable | Chỉ confirmed: `{registration_id: string}` bằng id; không QR |

`GET /me/registrations` bổ sung `workshop: WorkshopSummary` bắt buộc non-null.
Roster bổ sung `student: StudentSummary` bắt buộc non-null, không thêm workshop.
Mutation chỉ trả Registration, không identity người được promote.
Một registration cancelled giữ lịch sử; đăng ký lại sau student cancel tạo ID mới,
timestamp mới, xếp cuối. Sau event cancel không được đăng ký lại.
#1 cần xác nhận cách map hai bảng registrations/waiting_list thành ID ổn định,
lịch sử, unique active và FIFO tie-breaker; tài liệu này không thiết kế lại SQL.

## 5. Workshop endpoints

Tất cả path phần này có prefix `/api/v1`. Không body cho GET. Mọi endpoint có
thể trả 500 `INTERNAL_ERROR`; protected có 401/403; path ID thiếu resource có 404.
Lỗi 400 áp dụng query/body sai; ngoài các lỗi chung đó, lỗi nghiệp vụ ghi từng route.
Các ví dụ cùng `w1` là snapshot độc lập, không phải dữ liệu cố định qua mọi request.

### GET /workshops

Public; `q` optional 1–200 ký tự, tìm substring không phân biệt hoa thường trong
title/description/speaker; `category` optional như model; `registration_status`
optional effective open/closed; `from`, `to` optional UTC timestamps lọc start_at
trong `[from,to)` (một biên được bỏ); nếu cả hai thì from < to. Kết hợp filter AND.
Pagination chung; sort `start_at ASC, id ASC`. Mặc định mọi trạng thái, kể cả
cancelled; FE có thể chọn effective open. Không side effect. 200:

```json
{"data":[{"id":"w1","title":"Workshop API","location":"Phòng A","category":"Software","banner_url":null,"start_at":"2026-12-10T02:00:00Z","end_at":"2026-12-10T04:00:00Z","registration_deadline":"2026-12-09T17:00:00Z","capacity":1,"confirmed_count":1,"remaining_slots":0,"waitlist_count":1,"registration_status":"open","event_status":"active","is_registration_available":true}],"pagination":{"page":1,"limit":20,"total":1}}
```

Ví dụ query: `?q=API&category=Software&registration_status=open&from=2026-12-01T00%3A00%3A00Z&to=2027-01-01T00%3A00%3A00Z&page=1&limit=20`.
400 nếu filter/time/page sai; optional token sai 401.

### GET /workshops/{id}

Public; không query; 200 Workshop, không side effect. 404 nếu không tồn tại;
optional token sai 401. Không có dữ liệu cá nhân khi gửi token.

```json
{"data":{"id":"w1","organizer_id":"o1","title":"Workshop API","description":"Thiết kế API và FIFO.","speaker":"Bình","location":"Phòng A","category":"Software","banner_url":null,"start_at":"2026-12-10T02:00:00Z","end_at":"2026-12-10T04:00:00Z","registration_deadline":"2026-12-09T17:00:00Z","capacity":1,"confirmed_count":1,"remaining_slots":0,"waitlist_count":1,"registration_status":"open","event_status":"active","is_registration_available":true,"created_at":"2026-11-27T03:00:00Z","updated_at":"2026-12-01T03:01:00Z"}}
```

### GET /organizer/workshops

Organizer; luôn giới hạn owner từ token. Chỉ query page/limit; bao gồm closed và
cancelled, sort start_at ASC, id ASC; không side effect. 200 list WorkshopSummary,
ví dụ empty hợp lệ:

```json
{"data":[],"pagination":{"page":1,"limit":20,"total":0}}
```

### POST /workshops

Organizer; không query; body chỉ các field C trong model. Tạo owner từ token,
counts=0, remaining_slots=capacity, banner=null, active/open. 201 Workshop;
400 nếu validation, không nhận owner/status/counts. Request:

```json
{"title":"Workshop API","description":"Thiết kế API và FIFO.","speaker":"Bình","location":"Phòng A","category":"Software","start_at":"2026-12-10T02:00:00Z","end_at":"2026-12-10T04:00:00Z","registration_deadline":"2026-12-09T17:00:00Z","capacity":1}
```

Response:

```json
{"data":{"id":"w1","organizer_id":"o1","title":"Workshop API","description":"Thiết kế API và FIFO.","speaker":"Bình","location":"Phòng A","category":"Software","banner_url":null,"start_at":"2026-12-10T02:00:00Z","end_at":"2026-12-10T04:00:00Z","registration_deadline":"2026-12-09T17:00:00Z","capacity":1,"confirmed_count":0,"remaining_slots":1,"waitlist_count":0,"registration_status":"open","event_status":"active","is_registration_available":true,"created_at":"2026-11-27T03:00:00Z","updated_at":"2026-11-27T03:00:00Z"}}
```

### PATCH /workshops/{id}

Owner Organizer; không query; body nonempty chỉ field U, không nhận status/owner/
banner/counts. Ví dụ tăng capacity `{"capacity":2}`. Promote FIFO trong cùng
transaction nếu đủ điều kiện; 409 `CAPACITY_BELOW_CONFIRMED`, `WORKSHOP_CANCELLED`,
`WORKSHOP_STARTED`; 400 merged model sai. 200 Workshop:

```json
{"data":{"id":"w1","organizer_id":"o1","title":"Workshop API","description":"Thiết kế API và FIFO.","speaker":"Bình","location":"Phòng A","category":"Software","banner_url":null,"start_at":"2026-12-10T02:00:00Z","end_at":"2026-12-10T04:00:00Z","registration_deadline":"2026-12-09T17:00:00Z","capacity":2,"confirmed_count":2,"remaining_slots":0,"waitlist_count":0,"registration_status":"open","event_status":"active","is_registration_available":true,"created_at":"2026-11-27T03:00:00Z","updated_at":"2026-12-02T03:00:00Z"}}
```

### PATCH /workshops/{id}/registration-status

Owner Organizer; không query; body `{"registration_status":"closed"}` hoặc
`{"registration_status":"open"}`. Không đổi event_status, không hủy vé/queue.
Repeat cùng trạng thái trả 200, không side effect thêm; vẫn kiểm lifecycle trước.
Không mở khi now >= deadline; cả close/reopen bị chặn nếu cancelled/started.
409 `WORKSHOP_CANCELLED`, `WORKSHOP_STARTED`, `REGISTRATION_DEADLINE_PASSED`
(khi open). 200 Workshop (ví dụ closed; reopen giữ manual open và tính lại gate):

```json
{"data":{"id":"w1","organizer_id":"o1","title":"Workshop API","description":"Thiết kế API và FIFO.","speaker":"Bình","location":"Phòng A","category":"Software","banner_url":null,"start_at":"2026-12-10T02:00:00Z","end_at":"2026-12-10T04:00:00Z","registration_deadline":"2026-12-09T17:00:00Z","capacity":1,"confirmed_count":1,"remaining_slots":0,"waitlist_count":1,"registration_status":"closed","event_status":"active","is_registration_available":false,"created_at":"2026-11-27T03:00:00Z","updated_at":"2026-12-02T03:00:00Z"}}
```

### POST /workshops/{id}/cancel

Owner Organizer; không query/body. Active chưa bắt đầu -> cancelled terminal,
manual closed, mọi active registration thành cancelled với reason workshop_cancelled;
clear ticket/position, counts về 0, không promotion, không hard delete.
Repeat cancel 200 không side effect (kể cả đã qua start); active đã started: 409
`WORKSHOP_STARTED`. Các mutation khác trên event cancelled: 409 `WORKSHOP_CANCELLED`.
200 Workshop:

```json
{"data":{"id":"w1","organizer_id":"o1","title":"Workshop API","description":"Thiết kế API và FIFO.","speaker":"Bình","location":"Phòng A","category":"Software","banner_url":null,"start_at":"2026-12-10T02:00:00Z","end_at":"2026-12-10T04:00:00Z","registration_deadline":"2026-12-09T17:00:00Z","capacity":1,"confirmed_count":0,"remaining_slots":1,"waitlist_count":0,"registration_status":"closed","event_status":"cancelled","is_registration_available":false,"created_at":"2026-11-27T03:00:00Z","updated_at":"2026-12-02T03:00:00Z"}}
```

### POST /workshops/{id}/banner

Owner Organizer; workshop đã tạo, active chưa bắt đầu. Không query; multipart duy
nhất field `file`, JPEG/PNG/WebP, tối đa **5 MiB (5,242,880 bytes)** proposed.
Server kiểm nội dung thực và MIME; không nhận URL/storage path từ client.
Thành công thay banner_url, updated_at; giữ banner cũ nếu upload/DB update thất bại.
Không công bố URL mới trước khi cập nhật thành công; storage cụ thể cần nhóm chốt.
400 thiếu file, 413 `FILE_TOO_LARGE`, 415 `UNSUPPORTED_MEDIA_TYPE`,
409 `WORKSHOP_CANCELLED`/`WORKSHOP_STARTED`. Multipart minh họa:

```http
POST /api/v1/workshops/w1/banner
Authorization: Bearer <access_token>
Content-Type: multipart/form-data; boundary=example

--example
Content-Disposition: form-data; name="file"; filename="banner.png"
Content-Type: image/png

(binary PNG bytes)
--example--
```

201 (projection riêng của upload, banner_url và workshop_id string non-null):

```json
{"data":{"workshop_id":"w1","banner_url":"https://example.org/banners/w1.png"}}
```

## 6. Registration, My Workshops và roster

Prefix `/api/v1`; lỗi chung như phần 5. Mutation không có query/body, không nhận
student/status/position/timestamp; server quyết định kết quả.

### POST /workshops/{id}/registrations

Student; gate open và không active registration. Atomic create confirmed nếu còn
chỗ sau khi phục vụ queue cũ, hoặc waitlisted ở cuối. Cả hai trả **201** Registration.
409 `ALREADY_REGISTERED`, `WORKSHOP_CANCELLED`, `WORKSHOP_STARTED`,
`REGISTRATION_DEADLINE_PASSED`, `REGISTRATION_CLOSED`. Hai response có thể:

```json
{"data":{"id":"r1","workshop_id":"w1","status":"confirmed","registered_at":"2026-12-01T03:00:00Z","confirmed_at":"2026-12-01T03:00:00Z","cancelled_at":null,"cancellation_reason":null,"queue_position":null,"ticket":{"registration_id":"r1"}}}
```

```json
{"data":{"id":"r2","workshop_id":"w1","status":"waitlisted","registered_at":"2026-12-01T03:01:00Z","confirmed_at":null,"cancelled_at":null,"cancellation_reason":null,"queue_position":1,"ticket":null}}
```

### GET /me/registrations

Student; optional `status=confirmed|waitlisted|cancelled`, page/limit; chỉ của mình,
bao gồm lịch sử đăng ký lại. Sort registered_at DESC, id DESC. Không side effect.
200 Registration + workshop summary, ví dụ đủ ba trạng thái (snapshot w1 có 1
confirmed của người khác, 1 waitlisted và 1 cancelled):

```json
{"data":[{"id":"r3","workshop_id":"w1","status":"waitlisted","registered_at":"2026-12-01T03:02:00Z","confirmed_at":null,"cancelled_at":null,"cancellation_reason":null,"queue_position":1,"ticket":null,"workshop":{"id":"w1","title":"Workshop API","location":"Phòng A","category":"Software","banner_url":null,"start_at":"2026-12-10T02:00:00Z","end_at":"2026-12-10T04:00:00Z","registration_deadline":"2026-12-09T17:00:00Z","capacity":1,"confirmed_count":1,"remaining_slots":0,"waitlist_count":1,"registration_status":"open","event_status":"active","is_registration_available":true}},{"id":"r2","workshop_id":"w2","status":"confirmed","registered_at":"2026-12-01T03:01:00Z","confirmed_at":"2026-12-01T03:01:00Z","cancelled_at":null,"cancellation_reason":null,"queue_position":null,"ticket":{"registration_id":"r2"},"workshop":{"id":"w2","title":"Workshop DB","location":"Phòng B","category":"Software","banner_url":null,"start_at":"2026-12-11T02:00:00Z","end_at":"2026-12-11T04:00:00Z","registration_deadline":"2026-12-10T17:00:00Z","capacity":1,"confirmed_count":1,"remaining_slots":0,"waitlist_count":0,"registration_status":"open","event_status":"active","is_registration_available":true}},{"id":"r1","workshop_id":"w1","status":"cancelled","registered_at":"2026-12-01T03:00:00Z","confirmed_at":"2026-12-01T03:00:00Z","cancelled_at":"2026-12-01T03:01:30Z","cancellation_reason":"student_cancelled","queue_position":null,"ticket":null,"workshop":{"id":"w1","title":"Workshop API","location":"Phòng A","category":"Software","banner_url":null,"start_at":"2026-12-10T02:00:00Z","end_at":"2026-12-10T04:00:00Z","registration_deadline":"2026-12-09T17:00:00Z","capacity":1,"confirmed_count":1,"remaining_slots":0,"waitlist_count":1,"registration_status":"open","event_status":"active","is_registration_available":true}}],"pagination":{"page":1,"limit":20,"total":3}}
```

### POST /registrations/{id}/cancel

Student owner; đã cancelled trả 200 nguyên trạng không chạy promotion lần hai.
Active chỉ hủy/rút chờ khi now < start_at (kể cả gate closed/qua deadline);
sau start: 409 `CANCELLATION_NOT_ALLOWED`. Confirmed hủy giải phóng chỗ và promote
FIFO trong cùng transaction; rút waitlisted chỉ cập nhật rank, không tạo chỗ mới.
200 chỉ Registration của người gọi, không lộ identity người được promote:

```json
{"data":{"id":"r1","workshop_id":"w1","status":"cancelled","registered_at":"2026-12-01T03:00:00Z","confirmed_at":"2026-12-01T03:00:00Z","cancelled_at":"2026-12-02T03:00:00Z","cancellation_reason":"student_cancelled","queue_position":null,"ticket":null}}
```

Withdrawal có cùng shape, confirmed_at=null nếu chưa từng confirmed; repeat trả
cùng cancelled_at/reason. Event cancel đã hủy registration thì retry cũng 200.

### GET /workshops/{id}/registrations

Owner Organizer; optional `status=confirmed|waitlisted` (bỏ qua = cả hai active),
`q` 1–200 ký tự substring không phân biệt hoa thường trên display_name/email;
page/limit. Confirmed trước (confirmed_at ASC, id ASC), sau đó waitlisted theo FIFO.
Filter trước phân trang; queue_position vẫn là rank toàn bộ queue, không rank sau
filter. Không trả cancelled; không side effect. 200:

```json
{"data":[{"id":"r1","workshop_id":"w1","status":"confirmed","registered_at":"2026-12-01T03:00:00Z","confirmed_at":"2026-12-01T03:00:00Z","cancelled_at":null,"cancellation_reason":null,"queue_position":null,"ticket":{"registration_id":"r1"},"student":{"id":"u1","display_name":"An","email":"an@example.org"}},{"id":"r2","workshop_id":"w1","status":"waitlisted","registered_at":"2026-12-01T03:01:00Z","confirmed_at":null,"cancelled_at":null,"cancellation_reason":null,"queue_position":1,"ticket":null,"student":{"id":"u2","display_name":"Bình","email":"binh@example.org"}}],"pagination":{"page":1,"limit":20,"total":2}}
```

### GET /workshops/{id}/registrations/export

Owner Organizer; optional q cùng roster; không nhận page/limit/status. Xuất **toàn
bộ confirmed** matching filter, sort confirmed_at ASC, id ASC; snapshot nhất quán,
không side effect. 200 CSV; empty vẫn có header. CSV đã đủ đề xuất tối thiểu #9,
XLSX cần quyết định riêng. Lỗi trước download trả JSON envelope chung.

```http
Content-Type: text/csv; charset=utf-8
Content-Disposition: attachment; filename="attendance.csv"
Cache-Control: private, no-store

registration_id,display_name,email,registered_at
r1,"An, Nguyễn",an@example.org,2026-12-01T03:00:00Z
```

CRLF rows; quote field có dấu phẩy, quote hoặc newline; escape quote bằng `""`.
Trước CSV escaping, prefix apostrophe cho mọi cell dữ liệu người dùng mà sau bỏ
leading whitespace/control có ký tự đầu `=`, `+`, `-`, `@`, hoặc bắt đầu bằng
TAB/CR/LF. Áp dụng cả name/email, không chỉ field hiển thị; ví dụ `=1+1` -> `'=1+1`.
Giữ Unicode tiếng Việt; UTF-8 không BOM mặc định, nhu cầu BOM/Excel cần review.
Không xuất token, password, dữ liệu waitlisted hoặc thông tin không cần điểm danh.

## 7. FIFO, lifecycle và tính nguyên tử

Các quy tắc sau là nghĩa vụ implementation tương lai, chưa được triển khai.
Mỗi mutation cùng workshop (register, cancel, capacity, manual status, event cancel,
edit time) phải serialize bằng DB transaction + lock hoặc atomic RPC thích hợp.
Check quyền/lifecycle/gate, deduplicate, allocate, promote, counts và cập nhật trạng
thái commit/rollback nguyên tử; không read-then-write rời rạc dựa vào counts ở FE.

- Invariant: confirmed_count <= capacity; remaining_slots không âm; nhiều nhất
  một active registration mỗi (student, workshop), không đồng thời confirmed và
  waitlisted kể cả khi dùng hai bảng. Unique/locking strategy cần #1/#11 xác nhận.
- FIFO theo queue-entry timestamp server-generated, tie-breaker bất biến
  server-generated sequence được #1 xác nhận. Không dùng client timestamp hoặc
  timestamp không tie-breaker. API ID không mặc nhiên là thứ tự FIFO.
- Rank dynamic 1-based trong active queue; không phải identity. Khi promote giữ
  registration id/registered_at, set confirmed_at, ticket và clear queue_position.
  Khi hủy clear ticket/position, giữ lịch sử confirmed_at nếu có.
- Phục vụ queue cũ trước người mới. Capacity increase promote theo FIFO đến khi
  hết chỗ/queue; decrease dưới confirmed_count trả 409 và không đổi dữ liệu.
- Gate admission tách promotion: manual closed hoặc qua deadline chỉ chặn người
  mới; vẫn promote queue khi có hủy hợp lệ/capacity increase trước start. Cancelled
  hoặc now >= start không promote. Full không đóng gate.
- Cutoff hủy/rút chờ là start_at; event cancellation và edit cũng chỉ trước start.
  Retry student cancel hoặc event cancel đã thành công luôn trả kết quả cũ.
  Đăng ký retry khi còn active trả 409, không phát sinh queue entry mới; retry sau
  student cancel được coi là lần đăng ký mới nếu gate vẫn mở. Chưa thêm idempotency key.
- Event cancel terminal: hủy mọi active registrations và không chạy promotion;
  roster active rỗng, My Workshops hiển thị cancelled/workshop_cancelled.
- Counts, danh sách và rank trong từng response phải cùng snapshot. Sau commit FE
  refetch detail/My Workshops/roster có liên quan; không suy ra kết quả từ count cũ.

Ví dụ trước: capacity=1; A confirmed, B queue #1, C queue #2. A hủy -> A cancelled,
B confirmed (cùng ID, ticket xuất hiện), C #1, confirmed_count=1. Nếu B/C có cùng
queue timestamp thì sequence nhỏ hơn lên trước. Nếu queue rỗng: A hủy -> count=0,
remaining_slots=1. C rút queue không làm tăng remaining_slots. Đây là expected
behavior, không phải kết quả test đã chạy.

## 8. Error matrix và precedence

Mọi app endpoint có lỗi 500 chung. Ma trận sau chốt code và nơi sử dụng;
không áp dụng trực tiếp cho Supabase SDK.

| HTTP / code | Điều kiện / endpoint |
|---|---|
| 400 VALIDATION_ERROR | Query/body/date/number/enum sai, field lạ/read-only, file thiếu; mọi route có input |
| 401 UNAUTHENTICATED | Protected thiếu token; mọi request gửi token sai/hết hạn |
| 403 FORBIDDEN | Protected sai role/owner hoặc profile chưa sẵn sàng |
| 404 NOT_FOUND | Workshop/registration path không tồn tại |
| 409 ALREADY_REGISTERED | POST registrations đã có active của student |
| 409 WORKSHOP_CANCELLED | Register, workshop PATCH/status/banner trên event cancelled |
| 409 WORKSHOP_STARTED | Register, workshop PATCH/status/banner, cancel active event khi now >= start |
| 409 REGISTRATION_DEADLINE_PASSED | Register hoặc mở lại khi now >= deadline |
| 409 REGISTRATION_CLOSED | Register khi manual closed |
| 409 CAPACITY_BELOW_CONFIRMED | Workshop PATCH capacity dưới confirmed_count |
| 409 CANCELLATION_NOT_ALLOWED | Student cancel active registration khi now >= start |
| 413 FILE_TOO_LARGE | Banner vượt 5 MiB |
| 415 UNSUPPORTED_MEDIA_TYPE | JSON route có body sai Content-Type, hoặc banner sai MIME/multipart |
| 500 INTERNAL_ERROR | Lỗi bất ngờ, rollback; message generic |

Precedence: authenticate -> role -> lookup (404) -> ownership (403) -> media/size ->
input validation -> business rules trong transaction. Không tiết lộ PII qua lỗi.
Business register: event cancelled -> started -> duplicate -> deadline -> manual
closed -> allocation. Status open: cancelled -> started -> deadline. Workshop PATCH:
cancelled -> started -> capacity conflict. Cancel registration: already cancelled
trả 200 trước cutoff. Event cancel: already cancelled trả 200 trước start check.
Nếu nội dung HTTP không parse được, lớp transport có thể từ chối 400 trước auth;
không đưa thông tin resource vào lỗi parse. Không có 403 vì hết chỗ.

Ví dụ duplicate (409):

```json
{"error":{"code":"ALREADY_REGISTERED","message":"Bạn đã có đăng ký đang hoạt động."}}
```

Ví dụ validation (400; cùng shape cho date/query/enum, details dùng tên field):

```json
{"error":{"code":"VALIDATION_ERROR","message":"Dữ liệu không hợp lệ.","details":[{"field":"capacity","message":"Phải là số nguyên dương."}]}}
```

## 9. Acceptance scenarios — expected, chưa chạy runtime

| Scenario | Expected outcome |
|---|---|
| Empty list; page ngoài range; filter kết hợp | 200 []; total đúng filter; from inclusive/to exclusive; query enum/date/page sai 400 |
| Guest, student, organizer khác owner | Guest browse 200; protected thiếu token 401; student create 403; organizer khác owner roster/edit/export 403; ID thiếu 404 |
| Còn chỗ / full nhưng gate open | 201 confirmed + ticket / 201 waitlisted + rank; full không 409 |
| Duplicate kể cả concurrent cùng user | Một active duy nhất; request còn lại 409 ALREADY_REGISTERED |
| 20–50 user khác nhau tranh 1 chỗ, queue ban đầu rỗng (#13) | Đúng 1 confirmed; còn lại 201 waitlisted nếu tất cả hợp lệ, không gate change/cancel; không overbooking |
| Full -> queue -> confirmed cancel -> promote -> roster (#12) | Người chờ đầu lên confirmed cùng ID, ticket xuất hiện; roster/counts/My Workshops mới khớp |
| Queue empty; withdrawal; repeat cancel | Hủy confirmed tăng slot; rút chờ chỉ đổi rank; retry 200, không promotion lần hai |
| Timestamp tie và new arrival tranh với cancellation | Sequence quyết định FIFO; người mới không vượt queue |
| Manual closed / deadline / event cancel / đúng start | Admission bị chặn với mã ưu tiên đã định; close/deadline vẫn promote trước start; event cancel/started không promote |
| Capacity tăng/giảm; edit time/status | Tăng phục vụ queue; dưới confirmed_count 409; merged dates sai 400; event cancelled/started chặn edit |
| Re-register sau student cancel / event cancel | Student cancel + gate open tạo ID mới cuối queue; event cancel 409 |
| My Workshops ba trạng thái | Có workshop summary; confirmed ticket, waitlisted rank, cancelled reason; refetch thấy thay đổi sau commit |
| Banner boundary / media / quyền | Đúng 5 MiB hợp lệ; lớn hơn 413; MIME sai 415; khác owner 403; không thay banner khi fail |
| Export filtered/full dataset, Unicode/quotes/newlines/formula | Owner-only; chỉ confirmed; không giới hạn trang; CSV escape và chống formula injection; empty có header |
| Unexpected error giữa cancel/promote | 500 generic; rollback toàn bộ, không mất queue/overbooking |

Các scenario là tiêu chí cho #12–#14; tài liệu docs-only không chứng minh runtime,
concurrency hoặc bảo mật đã hoạt động.

## 10. Open decisions trước merge

| Needs team review | Proposed default / lý do | Owner / reviewer |
|---|---|---|
| SRS đầy đủ, field/FR-09/NFR, framework/base/naming | REST /api/v1 snake_case; không chọn framework; xác nhận field/length với SRS để tránh ép schema | Các assignee #2 / @chaengnchang |
| Auth và guest browse | SDK trực tiếp, email confirmation bật, profile server idempotent; public browse không PII; organizer provision tin cậy để tránh tự nâng quyền | @NewB-S2deeC0de (#3), @chaengnchang (#1) / @DatBui1826 |
| Identity/schema hai bảng | Opaque ID ổn định qua promotion; history và unique active xuyên bảng; queue timestamp + immutable sequence; cần map users/Auth | @chaengnchang (#1/#11) / @NewB-S2deeC0de, @Lowen-here |
| Thời gian/lifecycle/gate | UTC, cutoff start; close/deadline chặn mới nhưng vẫn promote; terminal cancel; capacity tăng promote; retry cancel 200; re-register ID mới | #2/#8/#11 / @chaengnchang |
| Upload, ticket, export, refresh | 5 MiB JPEG/PNG/WebP; đề xuất Supabase Storage; ticket reference; CSV UTF-8 không BOM; refetch sau mutation, refresh nền chưa chốt | #3/#9/#10 / @DatBui1826, @Lowen-here |

Reviewer chính issue #2: **@chaengnchang**; assignees **@NewB-S2deeC0de,
@DatBui1826, @Lowen-here**. Cần review chéo #1/#2 và đồng thuận nhóm trước merge;
chưa thể tự chứng nhận Definition of Done “được cả nhóm thông qua”.
