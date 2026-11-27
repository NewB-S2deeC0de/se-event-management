create table public.users (
    id uuid primary key references auth.users (id) on delete restrict,
    full_name text not null check (btrim(full_name) <> ''),
    role text not null default 'student' check (role in ('student', 'organizer')),
    student_code text unique check (student_code <> '' and student_code = btrim(student_code)),
    faculty_name text check (btrim(faculty_name) <> ''),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint users_student_code_required check (role <> 'student' or student_code is not null)
);

create table public.workshops (
    id bigint generated always as identity primary key,
    organizer_id uuid not null references public.users (id) on delete restrict,
    organizing_unit text not null check (btrim(organizing_unit) <> ''),
    title text not null check (btrim(title) <> ''),
    description text not null,
    location text not null check (btrim(location) <> ''),
    eligibility_notes text,
    capacity integer not null check (capacity > 0),
    confirmed_count integer not null default 0,
    status text not null default 'draft' check (status in ('draft', 'published', 'cancelled')),
    registration_enabled boolean not null default false,
    registration_opens_at timestamptz not null,
    registration_closes_at timestamptz not null,
    starts_at timestamptz not null,
    ends_at timestamptz not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint workshops_confirmed_within_capacity check (confirmed_count between 0 and capacity),
    constraint workshop_time_order check (
        registration_opens_at < registration_closes_at
        and registration_closes_at <= starts_at
        and starts_at < ends_at
    )
);

create table public.registrations (
    id bigint generated always as identity primary key,
    user_id uuid not null references public.users (id) on delete restrict,
    workshop_id bigint not null references public.workshops (id) on delete restrict,
    status text not null check (status in ('waiting', 'confirmed', 'cancelled')),
    -- The backend verifies the actor has permission to check in this workshop.
    checked_in_at timestamptz,
    checked_in_by uuid references public.users (id) on delete restrict,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint registrations_id_workshop_key unique (id, workshop_id),
    constraint registrations_check_in_consistency check (
        (checked_in_at is null and checked_in_by is null)
        or (status = 'confirmed' and checked_in_at is not null and checked_in_by is not null)
    )
);

create table public.waiting_list (
    id bigint generated always as identity primary key,
    registration_id bigint not null unique,
    workshop_id bigint not null,
    joined_at timestamptz not null,
    constraint waiting_list_registration_workshop_fkey
        foreign key (registration_id, workshop_id)
        references public.registrations (id, workshop_id) on delete cascade
);

create unique index registrations_one_active_per_workshop
    on public.registrations (user_id, workshop_id)
    where status in ('waiting', 'confirmed');

create index workshops_organizer_idx on public.workshops (organizer_id);
create index registrations_user_idx on public.registrations (user_id);
create index registrations_checked_in_by_idx on public.registrations (checked_in_by);
create index registrations_workshop_status_idx on public.registrations (workshop_id, status);
create index waiting_list_fifo_idx on public.waiting_list (workshop_id, joined_at, id);

create function public.wms_set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    new.updated_at := pg_catalog.clock_timestamp();
    return new;
end;
$$;

create trigger users_set_updated_at
    before update on public.users
    for each row execute function public.wms_set_updated_at();

create trigger workshops_set_updated_at
    before update on public.workshops
    for each row execute function public.wms_set_updated_at();

create trigger registrations_set_updated_at
    before update on public.registrations
    for each row execute function public.wms_set_updated_at();

create function public.wms_stamp_waiting_list_entry()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    new.joined_at := pg_catalog.clock_timestamp();
    return new;
end;
$$;

create trigger waiting_list_stamp_entry
    before insert on public.waiting_list
    for each row execute function public.wms_stamp_waiting_list_entry();

-- Maintain the queue in the same transaction as a registration status change.
-- This function writes to the queue on behalf of the backend.
create function public.wms_sync_waiting_list()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    if tg_op = 'UPDATE' then
        if old.status = new.status then
            return null;
        end if;
    end if;

    if new.status = 'waiting' then
        insert into public.waiting_list (registration_id, workshop_id)
        values (new.id, new.workshop_id);
    elsif tg_op = 'UPDATE' then
        delete from public.waiting_list where registration_id = old.id;
    end if;

    return null;
end;
$$;

create trigger registrations_sync_waiting_list
    after insert or update of status on public.registrations
    for each row execute function public.wms_sync_waiting_list();

-- An atomic update serializes changes to confirmed seats with capacity edits.
-- If the capacity check fails, both the registration and counter changes roll back.
create function public.wms_update_confirmed_count()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    previous_workshop_id bigint;
    next_workshop_id bigint;
begin
    if tg_op <> 'INSERT' then
        if old.status = 'confirmed' then
            previous_workshop_id := old.workshop_id;
        end if;
    end if;

    if tg_op <> 'DELETE' then
        if new.status = 'confirmed' then
            next_workshop_id := new.workshop_id;
        end if;
    end if;

    if previous_workshop_id is not distinct from next_workshop_id then
        return null;
    end if;

    if previous_workshop_id is not null and next_workshop_id is not null then
        perform 1
        from public.workshops
        where id in (previous_workshop_id, next_workshop_id)
        order by id
        for no key update;
    end if;

    if previous_workshop_id is not null then
        update public.workshops
        set confirmed_count = confirmed_count - 1
        where id = previous_workshop_id;
    end if;

    if next_workshop_id is not null then
        update public.workshops
        set confirmed_count = confirmed_count + 1
        where id = next_workshop_id;
    end if;

    return null;
end;
$$;

create trigger registrations_update_confirmed_count
    after insert or delete or update of status, workshop_id on public.registrations
    for each row execute function public.wms_update_confirmed_count();

-- All application reads and writes go through the backend.
alter table public.users enable row level security;
alter table public.workshops enable row level security;
alter table public.registrations enable row level security;
alter table public.waiting_list enable row level security;

revoke all on public.users, public.workshops, public.registrations, public.waiting_list
    from public, anon, authenticated, service_role;
revoke all on sequence public.workshops_id_seq, public.registrations_id_seq, public.waiting_list_id_seq
    from public, anon, authenticated, service_role;
revoke all on function public.wms_set_updated_at(), public.wms_stamp_waiting_list_entry(),
    public.wms_sync_waiting_list(), public.wms_update_confirmed_count()
    from public, anon, authenticated, service_role;

grant select, insert, update, delete on public.users, public.registrations
    to service_role;
grant select, delete on public.workshops to service_role;
grant insert (organizer_id, organizing_unit, title, description, location, eligibility_notes,
    capacity, status, registration_enabled, registration_opens_at, registration_closes_at,
    starts_at, ends_at, created_at, updated_at),
    update (organizer_id, organizing_unit, title, description, location, eligibility_notes,
    capacity, status, registration_enabled, registration_opens_at, registration_closes_at,
    starts_at, ends_at, created_at, updated_at)
    on public.workshops to service_role;
grant select on public.waiting_list to service_role;
grant usage on sequence public.workshops_id_seq, public.registrations_id_seq to service_role;
