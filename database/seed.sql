-- WMS fixtures for a disposable Supabase test project.
-- Create these four test accounts in Authentication > Users first.
-- wms-organizer@example.com, wms-student-a@example.com,
-- wms-student-b@example.com, wms-student-c@example.com
-- Run this file through the SQL Editor after applying the schema.
-- Re-running keeps the current state of existing fixture workshops.

do $$
declare
    fixture_organizer_id uuid;
    student_a_id uuid;
    student_b_id uuid;
    student_c_id uuid;
    full_workshop_id bigint;
    seed_time timestamptz := clock_timestamp();
begin
    select
        (select id from auth.users where email = 'wms-organizer@example.com'),
        (select id from auth.users where email = 'wms-student-a@example.com'),
        (select id from auth.users where email = 'wms-student-b@example.com'),
        (select id from auth.users where email = 'wms-student-c@example.com')
    into fixture_organizer_id, student_a_id, student_b_id, student_c_id;

    if fixture_organizer_id is null or student_a_id is null or student_b_id is null or student_c_id is null then
        raise exception 'Create all four WMS test accounts in Supabase Authentication before running seed.sql.';
    end if;

    insert into public.users (id, full_name, role, student_code, faculty_name)
    values
        (fixture_organizer_id, 'WMS Test Organizer', 'organizer', null, null),
        (student_a_id, 'WMS Test Student A', 'student', 'WMS-TEST-A', 'Khoa Kiem Thu'),
        (student_b_id, 'WMS Test Student B', 'student', 'WMS-TEST-B', 'Khoa Kiem Thu'),
        (student_c_id, 'WMS Test Student C', 'student', 'WMS-TEST-C', 'Khoa Kiem Thu')
    on conflict (id) do update set
        full_name = excluded.full_name,
        role = excluded.role,
        student_code = excluded.student_code,
        faculty_name = excluded.faculty_name;

    with inserted_workshops as (
        insert into public.workshops (
            organizer_id, organizing_unit, title, description, location, capacity, status,
            registration_enabled, registration_opens_at, registration_closes_at, starts_at, ends_at
        )
        select fixture_organizer_id, 'CLB Kiem Thu WMS', fixture.title, fixture.description, 'Phong Test', 1,
            'published', true, seed_time - interval '1 hour', seed_time + interval '1 day',
            seed_time + interval '2 days', seed_time + interval '2 days 2 hours'
        from (values
            ('[WMS Seed] FIFO', 'One confirmed student and two waiting students.'),
            ('[WMS Seed] Last Seat', 'One empty seat for a two-session concurrency test.')
        ) as fixture(title, description)
        where not exists (
            select 1 from public.workshops as existing
            where existing.organizer_id = fixture_organizer_id and existing.title = fixture.title
        )
        returning id, title
    )
    select id into full_workshop_id
    from inserted_workshops
    where title = '[WMS Seed] FIFO';

    if full_workshop_id is not null then
        insert into public.registrations (user_id, workshop_id, status)
        values (student_a_id, full_workshop_id, 'confirmed');

        insert into public.registrations (user_id, workshop_id, status)
        values (student_b_id, full_workshop_id, 'waiting');

        insert into public.registrations (user_id, workshop_id, status)
        values (student_c_id, full_workshop_id, 'waiting');
    end if;
end;
$$;
