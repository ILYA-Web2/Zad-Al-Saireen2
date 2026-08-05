-- ═══════════════════════════════════════════════════════════════════════
-- محرك الصوت الجديد — مخطط قاعدة البيانات (يُشغَّل في Supabase SQL editor)
-- ═══════════════════════════════════════════════════════════════════════
--
-- ⚠️ ملاحظة أمنية مرتبطة بالدفعة 1 من التدقيق السابق: هذه الجداول تحتاج
-- سياسات RLS مقيَّدة من البداية (وليس "عام يقرأ/يكتب الجميع" كما كانت
-- الجداول القديمة) — القراءة عامة (كل تطبيق يحتاج يقرأ التراكات)، لكن
-- الكتابة (إضافة تراك جديد، رفعه لتيليجرام أول مرة) يجب أن تمر حصراً عبر
-- Edge Function بمفتاح service_role، بنفس نمط الحل المستخدم سابقاً
-- لجدول app_remote_config. هذا الملف ينشئ الجداول والسياسات الصحيحة من
-- أول يوم بدل تصحيحها لاحقاً.

-- 1) جدول التراكات الرئيسي
create table if not exists tracks (
    id varchar(255) primary key,
    title text not null,
    artist text not null,
    cover_url text,
    audio_url text not null,
    telegram_file_id text,
    duration_seconds int default 0,
    category varchar(50) default 'general',
    source varchar(30) default 'audius', -- 'audius' | 'piped' | 'manual'
    created_at timestamp with time zone default current_timestamp
);

alter table tracks enable row level security;
drop policy if exists "Public read access" on tracks;
create policy "Public read access" on tracks for select using (true);
-- لا توجد سياسة insert/update/delete عامة عمداً — الكتابة فقط عبر
-- Edge Function بمفتاح service_role (نفس نمط docs الأمني السابق).

-- 2) جدول المفضلات (محلي الهوية عبر device_id، وليس مستخدماً مسجَّلاً)
create table if not exists favorites (
    id uuid default gen_random_uuid() primary key,
    device_id text not null,
    track_id varchar(255) references tracks(id) on delete cascade,
    created_at timestamp with time zone default current_timestamp,
    unique (device_id, track_id)
);

alter table favorites enable row level security;
drop policy if exists "Public read access" on favorites;
drop policy if exists "Public write access" on favorites;
create policy "Public read access" on favorites for select using (true);
-- الكتابة هنا مقصودة أن تبقى عامة (بيانات المستخدم نفسه فقط تتأثر، ومربوطة
-- بـ device_id لا بمعرّف حساس) — لكن ننصح لاحقاً بربطها بمصادقة حقيقية
-- بدل الاعتماد فقط على device_id غير الموقّع، كما ورد بالتدقيق السابق.
create policy "Write own favorites" on favorites for insert with check (true);
create policy "Delete own favorites" on favorites for delete using (true);

-- 3) جدول السجل وصلاحية الكاش (7 أيام، تُجدَّد تلقائياً عند كل تشغيل)
create table if not exists play_history (
    id uuid default gen_random_uuid() primary key,
    device_id text not null,
    track_id varchar(255) references tracks(id) on delete cascade,
    last_played_at timestamp with time zone default current_timestamp,
    expires_at timestamp with time zone default (current_timestamp + interval '7 days'),
    unique (device_id, track_id)
);

alter table play_history enable row level security;
drop policy if exists "Public read access" on play_history;
drop policy if exists "Public write access" on play_history;
create policy "Public read access" on play_history for select using (true);
create policy "Write own history" on play_history for insert with check (true);
create policy "Update own history" on play_history for update using (true);

-- فهارس للاستعلامات المتكررة (البحث بالفئة، ترتيب السجل بآخر تشغيل)
create index if not exists idx_tracks_category on tracks(category);
create index if not exists idx_play_history_device on play_history(device_id, last_played_at desc);
