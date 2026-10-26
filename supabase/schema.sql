
-- WORPRO database schema for Supabase
-- Starter version: test before using real customer data.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  role text not null default 'customer'
    check (role in ('customer','worker','team','admin')),
  created_at timestamptz not null default now()
);

create table if not exists public.worker_applications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  full_name text not null,
  phone text not null,
  service_name text not null,
  experience_years integer not null default 0
    check (experience_years between 0 and 60),
  area text not null default '',
  registration_fee_due integer not null default 25
    check (registration_fee_due = 25),
  fee_paid boolean not null default false,
  status text not null default 'pending'
    check (status in ('pending','approved','rejected','suspended')),
  created_at timestamptz not null default now()
);

create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references auth.users(id) on delete restrict,
  service_name text not null,
  customer_name text not null,
  customer_phone text not null,
  service_date date,
  customer_address text not null default '',
  work_details text not null,
  status text not null default 'new'
    check (status in ('new','assigned','accepted','in_progress','completed','cancelled')),
  quoted_amount numeric(10,2) not null default 0
    check (quoted_amount >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Workers receive job details without customer phone/address.
create table if not exists public.worker_booking_assignments (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  worker_id uuid not null references auth.users(id) on delete cascade,
  service_name text not null,
  work_details text not null,
  service_date date,
  status text not null default 'offered'
    check (status in ('offered','accepted','declined','in_progress','completed')),
  commission_amount numeric(10,2) not null default 0
    check (commission_amount >= 0),
  commission_paid boolean not null default false,
  created_at timestamptz not null default now(),
  unique (booking_id, worker_id)
);

create table if not exists public.ledger_entries (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid references public.bookings(id) on delete set null,
  worker_id uuid references auth.users(id) on delete set null,
  entry_type text not null
    check (entry_type in ('registration_fee','commission_due','commission_paid','customer_payment','refund','adjustment')),
  amount numeric(10,2) not null check (amount >= 0),
  note text not null default '',
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  subject text not null,
  details text not null,
  status text not null default 'open'
    check (status in ('open','in_progress','resolved','closed')),
  created_at timestamptz not null default now()
);

create or replace function public.current_role()
returns text
language sql stable security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid()
$$;

create or replace function public.is_staff()
returns boolean
language sql stable security definer
set search_path = public
as $$
  select coalesce(public.current_role() in ('team','admin'), false)
$$;

-- Every new account starts as a customer.
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name',''),
    'customer'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.worker_applications enable row level security;
alter table public.bookings enable row level security;
alter table public.worker_booking_assignments enable row level security;
alter table public.ledger_entries enable row level security;
alter table public.support_tickets enable row level security;

-- Profiles
create policy "profiles_read_own_or_staff"
on public.profiles for select to authenticated
using (id = auth.uid() or public.is_staff());

create policy "profiles_update_own_basic"
on public.profiles for update to authenticated
using (id = auth.uid())
with check (id = auth.uid() and role = public.current_role());

-- Worker applications
create policy "worker_app_read_own_or_staff"
on public.worker_applications for select to authenticated
using (user_id = auth.uid() or public.is_staff());

create policy "worker_app_insert_own"
on public.worker_applications for insert to authenticated
with check (
  user_id = auth.uid()
  and status = 'pending'
  and fee_paid = false
  and registration_fee_due = 25
);

create policy "worker_app_update_own_pending"
on public.worker_applications for update to authenticated
using (user_id = auth.uid() and status = 'pending')
with check (
  user_id = auth.uid()
  and status = 'pending'
  and fee_paid = false
);

create policy "worker_app_staff_all"
on public.worker_applications for all to authenticated
using (public.is_staff())
with check (public.is_staff());

-- Bookings: workers must not query this table directly.
create policy "bookings_customer_read"
on public.bookings for select to authenticated
using (customer_id = auth.uid() or public.is_staff());

create policy "bookings_customer_insert"
on public.bookings for insert to authenticated
with check (customer_id = auth.uid() and status = 'new');

create policy "bookings_staff_manage"
on public.bookings for all to authenticated
using (public.is_staff())
with check (public.is_staff());

-- Worker assignments contain no customer phone or address.
create policy "assignments_worker_read_own"
on public.worker_booking_assignments for select to authenticated
using (worker_id = auth.uid() or public.is_staff());

create policy "assignments_staff_manage"
on public.worker_booking_assignments for all to authenticated
using (public.is_staff())
with check (public.is_staff());

create policy "assignments_worker_update_status"
on public.worker_booking_assignments for update to authenticated
using (worker_id = auth.uid())
with check (worker_id = auth.uid());

-- Accounting
create policy "ledger_read_staff_or_worker"
on public.ledger_entries for select to authenticated
using (public.is_staff() or worker_id = auth.uid());

create policy "ledger_staff_manage"
on public.ledger_entries for all to authenticated
using (public.is_staff())
with check (public.is_staff());

-- Support requests
create policy "tickets_read_own_or_staff"
on public.support_tickets for select to authenticated
using (user_id = auth.uid() or public.is_staff());

create policy "tickets_insert_own"
on public.support_tickets for insert to authenticated
with check (user_id = auth.uid());

create policy "tickets_staff_manage"
on public.support_tickets for all to authenticated
using (public.is_staff())
with check (public.is_staff());

-- Admin view. Review permissions before production use.
create or replace view public.admin_booking_view
with (security_invoker = true) as
select
  id, customer_id, service_name, customer_name, customer_phone,
  service_date, customer_address, work_details, status,
  quoted_amount, created_at
from public.bookings;

-- Set the first admin manually in Supabase SQL Editor.
-- Create your account first, then find its UUID under Authentication > Users.
-- Replace UUID below with your own account UUID:
-- update public.profiles set role = 'admin'
-- where id = 'PASTE-USER-UUID-HERE';
