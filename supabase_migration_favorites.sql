-- Run this once in the Supabase SQL editor for project rernamtqmbfzdhzgjyps.
-- Backs the favorites feature — matches SupabaseService.addFavorite() exactly.

create table if not exists favorites (
  id                bigint generated always as identity primary key,
  video_id          text not null unique,
  video_title       text,
  video_thumbnail   text,
  channel_name      text,
  description       text,
  created_at        timestamptz not null default now()
);

create index if not exists favorites_video_id_idx on favorites (video_id);

alter table favorites enable row level security;

create policy "Public read access" on favorites for select using (true);
create policy "Public write access" on favorites for insert with check (true);
create policy "Public update access" on favorites for update using (true);
create policy "Public delete access" on favorites for delete using (true);
