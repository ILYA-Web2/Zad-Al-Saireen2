-- Run this once in the Supabase SQL editor. Powers the hidden admin panel:
-- remote per-section kill-switch + forced update, and broadcast
-- notifications. If this migration is skipped, the admin panel still
-- opens (the secret code always works, it's purely local), but every
-- write action inside it will show a real error instead of silently
-- pretending to succeed.

-- A single-row table (id is always 1) holding the whole app's remote
-- config, so a fresh row never needs to be created by the app itself.
create table if not exists app_remote_config (
  id                    bigint primary key default 1,
  disabled_sections     jsonb not null default '[]'::jsonb,
  maintenance_message   text not null default '',
  force_update          boolean not null default false,
  update_url            text not null default '',
  latest_version        text not null default '',
  updated_at            timestamptz not null default now(),
  constraint single_row check (id = 1)
);

insert into app_remote_config (id) values (1)
  on conflict (id) do nothing;

alter table app_remote_config enable row level security;

create policy "Public read access" on app_remote_config
  for select using (true);

create policy "Public write access" on app_remote_config
  for all using (true) with check (true);

-- Broadcast notifications shown as a full-screen, dismiss-once popup to
-- every installation (like a game's event popup), and listed afterwards
-- in the in-app "الإشعارات" screen.
create table if not exists admin_notifications (
  id           bigint generated always as identity primary key,
  title        text not null,
  body         text not null,
  image_url    text,
  link_url     text,
  active       boolean not null default true,
  created_at   timestamptz not null default now()
);

create index if not exists admin_notifications_active_idx
  on admin_notifications (active, created_at desc);

alter table admin_notifications enable row level security;

create policy "Public read access" on admin_notifications
  for select using (true);

create policy "Public write access" on admin_notifications
  for insert with check (true);

create policy "Public update access" on admin_notifications
  for update using (true);
