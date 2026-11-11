-- Виконати в Supabase -> SQL Editor (один раз, після patch4.sql)
-- До трьох підписів на користувача

alter table public.profiles add column if not exists signatures jsonb;

-- інші користувачі (начальник цеху) не можуть міняти чужі підписи
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
     or new.signatures is distinct from old.signatures
     or new.dept_id is distinct from old.dept_id
     or new.about is distinct from old.about
     or new.avatar is distinct from old.avatar
     or new.discord is distinct from old.discord
     or new.experience is distinct from old.experience then
    raise exception 'Можно менять только подтверждение, должность и смену';
  end if;
  return new;
end $$;

-- у журналі змін не зберігаємо великі картинки (підписи, аватар)
create or replace function app.audit() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.audit_log(actor, action, tbl, row_id, old_row, new_row)
  values (auth.uid(), tg_op, tg_table_name,
          coalesce(to_jsonb(new)->>'id', to_jsonb(old)->>'id'),
          case when tg_op <> 'INSERT' then to_jsonb(old) - 'signature' - 'signatures' - 'avatar' end,
          case when tg_op <> 'DELETE' then to_jsonb(new) - 'signature' - 'signatures' - 'avatar' end);
  return coalesce(new, old);
end $$;
