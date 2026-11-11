-- Виконати в Supabase -> SQL Editor (один раз, після patch3.sql)
-- Налаштування поточної зміни та графік змін

create table if not exists public.settings (
  key text primary key,
  value jsonb not null default '{}',
  updated_at timestamptz not null default now()
);
alter table public.settings enable row level security;
drop policy if exists settings_read on public.settings;
drop policy if exists settings_write on public.settings;
create policy settings_read on public.settings for select to authenticated using (app.is_approved());
create policy settings_write on public.settings for all to authenticated
  using (app.is_owner()) with check (app.is_owner());
grant select, insert, update, delete on public.settings to authenticated;
