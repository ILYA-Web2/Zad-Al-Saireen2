-- Run this once in the Supabase SQL editor for project rrpydyotyzezmrzrvewm.
--
-- WHY THIS MIGRATION EXISTS: YouTube API keys added from the hidden admin
-- panel used to be saved with `HiveService` — local device storage only.
-- That meant adding a key on the admin's own phone never reached anyone
-- else's install, and the only way to actually grow the shared rotation
-- pool for every user was to hardcode a new key into the source and ship
-- a brand new app version. This table replaces that entirely: it is now
-- the single real, shared source of truth for the whole key pool, for
-- every installation, added/removed instantly with no app update needed.
--
-- The app keeps a local Hive *cache* of the last successful sync purely
-- as an offline fallback (so a device with no internet at that exact
-- moment can still rotate through whatever it last saw) — but this table
-- is what's authoritative, and what the admin panel actually edits.

create table if not exists youtube_api_keys (
  id         bigint generated always as identity primary key,
  api_key    text not null unique,
  active     boolean not null default true,
  added_at   timestamptz not null default now()
);

create index if not exists youtube_api_keys_active_idx
  on youtube_api_keys (active);

alter table youtube_api_keys enable row level security;

create policy "Public read access" on youtube_api_keys
  for select using (true);

create policy "Public write access" on youtube_api_keys
  for insert with check (true);

create policy "Public update access" on youtube_api_keys
  for update using (true);

create policy "Public delete access" on youtube_api_keys
  for delete using (true);

-- Seed with the keys that used to be hardcoded in app_constants.dart, so
-- nothing breaks the moment this migration runs — the app will simply
-- start reading these same four keys from here instead of from the
-- compiled list, with zero interruption to search.
insert into youtube_api_keys (api_key) values
  ('AIzaSyC5GMw9EJmVTC8cEI9WoeeTSGJ2lkNArB0'),
  ('AIzaSyCDvGEFpnpLkj-lOXf_P5C33rEsp294G-0'),
  ('AIzaSyAenPo3qveXlSXYkImKuAl-TXdekTWVuFc'),
  ('AIzaSyDSlmc7giRWhADYH0diztszj7hJxWjXPgg')
on conflict (api_key) do nothing;
