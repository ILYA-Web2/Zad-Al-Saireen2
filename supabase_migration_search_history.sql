-- Run this once in the Supabase SQL editor for project rrpydyotyzezmrzrvewm.
--
-- This table did NOT exist before this migration — the app was calling
-- `search_history` as a raw, unmanaged table name with no schema behind
-- it, so every save/read silently failed (caught and swallowed) and
-- "recent searches" always fell back to the same static keyword list for
-- every single user. This migration, together with the app-side fix that
-- now scopes every row by device_id, is what actually makes "my recent
-- searches" real and per-installation instead of failing silently.
--
-- NOTE: the app already treats local Hive storage as the source of truth
-- for what the search bar displays — this table is only a best-effort
-- cloud mirror (e.g. for future admin analytics or cross-device recovery
-- after a reinstall), so if this migration is skipped the app keeps
-- working perfectly fine on local history alone.

create table if not exists search_history (
  id           bigint generated always as identity primary key,
  device_id    text not null,
  query        text not null,
  searched_at  timestamptz not null default now(),
  unique (device_id, query)
);

create index if not exists search_history_device_id_idx
  on search_history (device_id, searched_at desc);

alter table search_history enable row level security;

create policy "Public read access" on search_history
  for select using (true);

create policy "Public write access" on search_history
  for insert with check (true);

create policy "Public update access" on search_history
  for update using (true);
