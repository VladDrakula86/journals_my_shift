-- Виконати один раз: Supabase → SQL Editor → вставити → Run.

-- 1) Хто може завантажувати PDF-журнали у вкладці «Документы»:
--    власник сайту, ГИС, Генеральний директор.
--    Якщо посади на сайті називаються інакше — змініть список в дужках.
create or replace function public.can_upload_docs()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and (p.role = 'owner'
           or p.position in ('ГИС','ГІС','Гис','Генеральный директор','Генеральний директор'))
  );
$$;

drop policy if exists "docs insert by managers" on public.documents;
create policy "docs insert by managers" on public.documents
  for insert to authenticated with check (public.can_upload_docs());

drop policy if exists "docs files upload by managers" on storage.objects;
create policy "docs files upload by managers" on storage.objects
  for insert to authenticated with check (bucket_id = 'documents' and public.can_upload_docs());

-- 2) Тип журналу (оперативний / обліку / правопорушень / вимірів)
alter table public.journals add column if not exists kind text;

-- 3) Журнали «вне зміни» (для неоперативного персоналу)
--    Писати можуть лише власник і посади, позначені в налаштуваннях журналу («Кто может редактировать»).
alter table public.journals add column if not exists offshift boolean not null default false;

create or replace function public.can_write_offshift(jid text)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1
    from public.journals j, public.profiles p
    where j.id::text = jid
      and coalesce(j.offshift, false)
      and p.id = auth.uid()
      and (p.role = 'owner'
           or (coalesce(p.approved, false) and to_jsonb(j.edit_pos) ? p.position))
  );
$$;

drop policy if exists "offshift entries insert" on public.entries;
create policy "offshift entries insert" on public.entries
  for insert to authenticated with check (public.can_write_offshift(journal_id::text));

drop policy if exists "offshift entries update" on public.entries;
create policy "offshift entries update" on public.entries
  for update to authenticated
  using (author::text = auth.uid()::text and public.can_write_offshift(journal_id::text))
  with check (author::text = auth.uid()::text and public.can_write_offshift(journal_id::text));

drop policy if exists "offshift entries delete" on public.entries;
create policy "offshift entries delete" on public.entries
  for delete to authenticated
  using (author::text = auth.uid()::text and public.can_write_offshift(journal_id::text));
