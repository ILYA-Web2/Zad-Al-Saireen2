-- Run this once in the Supabase SQL editor for project rernamtqmbfzdhzgjyps.
--
-- NOTE (please read, two real issues fixed/flagged here):
--
-- 1) `saveSettings()` in the app upserts a plain Dart Map — but Postgres
--    is NOT schemaless the way Firebase/Hive are. Sending a key that
--    isn't an actual column (e.g. `is_dark_mode`) would fail outright
--    with a "column does not exist" error. This migration defines the
--    real columns matching every settings key the app currently reads
--    from Hive (`AppConstants.prefIsDarkMode/prefFontSize/prefLineHeight
--    /prefSelectedReciter`), so those upserts actually succeed.
--
-- 2) `getSettings()`/`saveSettings()` still have NO per-device scoping —
--    a single shared row for literally everyone, the same class of bug
--    that used to make "recent searches" global before device_id fixed
--    it. This works today (one shared settings row), but should get the
--    same device_id-scoped treatment in a future pass instead of being
--    silently left as the one remaining shared-state issue. Left as a
--    single-row table on purpose for now to match the app's current
--    (unscoped) read/write calls exactly, so nothing else breaks.

create table if not exists user_settings (
  id                bigint generated always as identity primary key,
  is_dark_mode      boolean,
  font_size         double precision,
  line_height       double precision,
  selected_reciter  text,
  updated_at        timestamptz not null default now()
);

alter table user_settings enable row level security;

create policy "Public read access" on user_settings for select using (true);
create policy "Public write access" on user_settings for insert with check (true);
create policy "Public update access" on user_settings for update using (true);

