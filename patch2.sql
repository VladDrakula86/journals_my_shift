-- Виконати в Supabase -> SQL Editor (один раз): видалення користувачів власником
create or replace function public.delete_user(target uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not app.is_owner() then
    raise exception 'Только владелец может удалять пользователей';
  end if;
  if target = auth.uid() then
    raise exception 'Нельзя удалить самого себя';
  end if;
  if exists (select 1 from public.profiles where id = target and role = 'owner') then
    raise exception 'Нельзя удалить владельца';
  end if;
  delete from auth.users where id = target;  -- профіль видаляється каскадом
end $$;

revoke all on function public.delete_user(uuid) from public, anon;
grant execute on function public.delete_user(uuid) to authenticated;
