# ERD cơ sở dữ liệu WMS

```mermaid
erDiagram
    USERS ||--o{ WORKSHOPS : manages
    USERS ||--o{ REGISTRATIONS : registers
    USERS o|--o{ REGISTRATIONS : checks_in
    WORKSHOPS ||--o{ REGISTRATIONS : receives
    REGISTRATIONS ||--o| WAITING_LIST : has_queue_entry

    USERS {
        uuid id PK, FK "auth.users.id"
        text full_name
        text role
        text student_code UK
        text faculty_name
        timestamptz created_at
        timestamptz updated_at
    }

    WORKSHOPS {
        bigint id PK
        uuid organizer_id FK
        text organizing_unit
        text title
        text description
        text location
        text eligibility_notes
        integer capacity
        integer confirmed_count
        text status
        boolean registration_enabled
        timestamptz registration_opens_at
        timestamptz registration_closes_at
        timestamptz starts_at
        timestamptz ends_at
        timestamptz created_at
        timestamptz updated_at
    }

    REGISTRATIONS {
        bigint id PK
        uuid user_id FK
        bigint workshop_id FK
        text status
        timestamptz checked_in_at
        uuid checked_in_by FK
        timestamptz created_at
        timestamptz updated_at
    }

    WAITING_LIST {
        bigint id PK
        bigint registration_id FK, UK
        bigint workshop_id FK
        timestamptz joined_at
    }
```

- `users.student_code` bắt buộc với vai trò `student` và duy nhất khi có giá trị. `faculty_name` có thể để trống.
- `workshops.confirmed_count` do trigger cập nhật cùng giao dịch với đăng ký. Ràng buộc `0 <= confirmed_count <= capacity` cũng chặn việc giảm sức chứa thấp hơn số suất đã xác nhận.
- `registrations.checked_in_by` tham chiếu `users.id`. Một đăng ký đã điểm danh phải có cả thời điểm và người thực hiện, đồng thời ở trạng thái `confirmed`. Backend kiểm tra quyền điểm danh trên từng workshop.
- `waiting_list (registration_id, workshop_id)` là khóa ngoại ghép trỏ đến `registrations (id, workshop_id)`. Điều này giữ mục chờ thuộc đúng workshop. Thứ tự FIFO trong từng workshop là `joined_at, id`.
