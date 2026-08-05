-- Run this once in the Supabase SQL editor for project rrpydyotyzezmrzrvewm.
--
-- A minimal, fully hidden "account" — really just one row per unique
-- installation (the same device_id already used for search history),
-- created/touched silently every time the app opens. Nothing about this
-- is ever shown to the person using the app; it exists purely so the
-- admin stats tab has a real "how many people actually use this app"
-- number instead of the old proxy (distinct device_ids that happened to
-- search something, which under-counts anyone who only browsed).
--
-- This is intentionally NOT a real account system yet (no email,
-- password, profile, or anything user-facing) — just the minimal
-- anonymous identity + a door left open to build a visible account
-- system on top of the same device_id later if that's ever wanted.

create table if not exists app_users (
  device_id       text primary key,
  first_seen_at   timestamptz not null default now(),
  last_seen_at    timestamptz not null default now(),
  open_count      integer not null default 1,
  platform        text
);

create index if not exists app_users_last_seen_idx
  on app_users (last_seen_at desc);

alter table app_users enable row level security;

create policy "Public read access" on app_users
  for select using (true);

create policy "Public write access" on app_users
  for insert with check (true);

create policy "Public update access" on app_users
  for update using (true);
