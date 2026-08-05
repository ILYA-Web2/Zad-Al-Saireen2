-- Run this once in the Supabase SQL editor for project rrpydyotyzezmrzrvewm.
-- Adds the intermediate search-result cache table used by MediaCacheService
-- so repeated searches for the same term cost zero YouTube API quota.

create table if not exists media_cache (
  query      text primary key,
  results    jsonb not null,
  cached_at  timestamptz not null default now()
);

-- Public read/write via the anon key, matching how this app already uses
-- Supabase for favorites/downloads/settings. If you'd rather not allow
-- anonymous writes, remove the insert/update policy below and results will
-- simply always fall through to Firebase/YouTube/Piped/Invidious instead —
-- caching is best-effort everywhere in the app, nothing depends on it.
alter table media_cache enable row level security;

create policy "Public read access" on media_cache
  for select using (true);

create policy "Public write access" on media_cache
  for insert with check (true);

create policy "Public update access" on media_cache
  for update using (true);
