-- Run this once in the Supabase SQL editor for project rernamtqmbfzdhzgjyps.
--
-- This table backs the "التنزيلات" tab and the automatic background
-- caching that now happens the moment any video is opened (no manual
-- download button anymore) — `DownloadModel.toMap()` in the app matches
-- these columns exactly.

create table if not exists downloads (
  id                bigint generated always as identity primary key,
  video_id          text not null unique,
  title             text not null,
  channel_name      text,
  thumbnail_url     text,
  category          text not null default 'audio',
  downloaded_at     timestamptz not null default now(),
  local_path        text,
  file_size_bytes   bigint not null default 0,
  created_at        timestamptz not null default now()
);

create index if not exists downloads_video_id_idx on downloads (video_id);

alter table downloads enable row level security;

create policy "Public read access" on downloads
  for select using (true);

create policy "Public write access" on downloads
  for insert with check (true);

create policy "Public update access" on downloads
  for update using (true);

create policy "Public delete access" on downloads
  for delete using (true);
