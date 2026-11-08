-- Виконати в Supabase -> SQL Editor ПІСЛЯ schema.sql (один раз)

-- 1) читання даних тільки для підтверджених користувачів (свій профіль бачить кожен)
drop policy if exists prof_read on public.profiles;
create policy prof_read on public.profiles for select to authenticated
  using (id = auth.uid() or app.is_approved());
drop policy if exists j_read on public.journals;
create policy j_read on public.journals for select to authenticated using (app.is_approved());
drop policy if exists s_read on public.shifts;
create policy s_read on public.shifts for select to authenticated using (app.is_approved());
drop policy if exists e_read on public.entries;
create policy e_read on public.entries for select to authenticated using (app.is_approved());

-- 2) список цехів для форми реєстрації (до входу)
drop policy if exists dept_read_anon on public.departments;
create policy dept_read_anon on public.departments for select to anon using (true);
grant select on public.departments to anon;
