-- Виконати в Supabase -> SQL Editor (один раз, після patch.sql і patch2.sql)
-- Профіль користувача, бригади (№ зміни) і право запису "тільки бригада поточної зміни свого цеху"

-- 1) нові поля профілю та бригади
alter table public.profiles
  add column if not exists experience smallint check (experience between 0 and 80),
  add column if not exists about text check (char_length(about) <= 500),
  add column if not exists avatar text,
  add column if not exists discord text check (char_length(discord) <= 64),
  add column if not exists team text;
alter table public.shifts add column if not exists team text;

create table if not exists public.teams (name text primary key, sort int not null default 0);
alter table public.teams enable row level security;
drop policy if exists teams_read on public.teams;
drop policy if exists teams_write on public.teams;
create policy teams_read on public.teams for select to authenticated using (true);
create policy teams_write on public.teams for all to authenticated using (app.is_owner()) with check (app.is_owner());
grant select, insert, update, delete on public.teams to authenticated;
insert into public.teams(name, sort) values ('1 (А)',1),('2 (Б)',2),('3 (В)',3),('4 (Г)',4),('5 (Д)',5) on conflict do nothing;

-- 2) допоміжні функції
create or replace function app.same_dept(j uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists(select 1 from profiles p join journals jr on jr.id = j
    where p.id = auth.uid() and (p.approved or p.role = 'owner')
      and jr.dept_id is not null and jr.dept_id = p.dept_id)
$$;

-- пише тільки той, чия бригада = бригада поточної (відкритої) зміни, і цех = цех журналу
create or replace function app.on_shift(s uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists(
    select 1 from shifts sh
    join journals j on j.id = sh.journal_id
    join profiles p on p.id = auth.uid()
    where sh.id = s and not sh.closed
      and (p.approved or p.role = 'owner')
      and p.team is not null and p.team = sh.team
      and j.dept_id is not null and j.dept_id = p.dept_id)
$$;

-- відкрити нову зміну: своя бригада, свій цех, попередня зміна закрита й прийнята
create or replace function app.can_open_shift(j uuid, t text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists(select 1 from profiles p join journals jr on jr.id = j
      where p.id = auth.uid() and (p.approved or p.role = 'owner') and p.team is not null
        and p.team = t and jr.dept_id is not null and jr.dept_id = p.dept_id)
    and not exists(select 1 from shifts s where s.journal_id = j and (not s.closed or s.acc_by is null))
$$;

drop policy if exists s_ins on public.shifts;
create policy s_ins on public.shifts for insert to authenticated
  with check (app.is_owner() or (created_by = auth.uid() and app.can_open_shift(journal_id, team)));

-- 3) захисні тригери
create or replace function app.guard_shift() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or app.is_owner() then return new; end if;
  if not app.is_approved() then raise exception 'Нет прав'; end if;
  if new.created_by is distinct from old.created_by
     or new.journal_id is distinct from old.journal_id
     or new.team is distinct from old.team then
    raise exception 'Нельзя менять автора, журнал и бригаду смены';
  end if;
  if old.closed and not new.closed then raise exception 'Закрытую смену нельзя открыть снова'; end if;
  if not (old.created_by = auth.uid() or app.on_shift(old.id)
          or old.hand_by = auth.uid() or old.acc_by = auth.uid()
          or (old.closed and old.acc_by is null and app.same_dept(old.journal_id))) then
    raise exception 'Только члены смены могут менять смену';
  end if;
  if new.closed and not old.closed and not app.on_shift(old.id) then
    raise exception 'Завершить смену может только член смены';
  end if;
  if new.hand_by is distinct from old.hand_by and new.hand_by is distinct from auth.uid() then
    raise exception 'Нельзя подписывать сдачу смены за другого';
  end if;
  if new.acc_by is distinct from old.acc_by
     and (new.acc_by is distinct from auth.uid() or new.acc_by = new.hand_by
          or not app.same_dept(old.journal_id)) then
    raise exception 'Принять смену может другой человек из этого цеха, за себя';
  end if;
  return new;
end $$;

create or replace function app.guard_profile() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or app.is_owner() then return new; end if;
  if new.role is distinct from old.role then
    raise exception 'Менять роль может только владелец';
  end if;
  if new.id = auth.uid() then
    if new.approved is distinct from old.approved
       or new.position is distinct from old.position
       or new.team is distinct from old.team
       or new.font is distinct from old.font
       or (old.approved and new.dept_id is distinct from old.dept_id) then
      raise exception 'Нельзя менять собственные права (должность, смену, цех, доступ)';
    end if;
    return new;
  end if;
  if new.full_name is distinct from old.full_name
     or new.signature is distinct from old.signature
     or new.dept_id is distinct from old.dept_id
     or new.about is distinct from old.about
     or new.avatar is distinct from old.avatar
     or new.discord is distinct from old.discord
     or new.experience is distinct from old.experience then
    raise exception 'Можно менять только подтверждение, должность и смену';
  end if;
  return new;
end $$;
