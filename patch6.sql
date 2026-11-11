-- Виконати в Supabase -> SQL Editor (один раз, після patch5.sql)
-- Вкладка «Документи»: сховище PDF і таблиця з назвами

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('documents', 'documents', false, 20971520, array['application/pdf'])
on conflict (id) do update
  set file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

create table if not exists public.documents (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 1 and 200),
  path text not null unique,
  size bigint,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now()
);
alter table public.documents enable row level security;
drop policy if exists documents_read on public.documents;
drop policy if exists documents_write on public.documents;
create policy documents_read on public.documents for select to authenticated using (app.is_approved());
create policy documents_write on public.documents for all to authenticated
  using (app.is_owner()) with check (app.is_owner());
grant select, insert, update, delete on public.documents to authenticated;

-- файли: читають підтверджені, завантажує/видаляє лише власник
drop policy if exists docs_obj_read on storage.objects;
drop policy if exists docs_obj_ins on storage.objects;
drop policy if exists docs_obj_upd on storage.objects;
drop policy if exists docs_obj_del on storage.objects;
create policy docs_obj_read on storage.objects for select to authenticated
  using (bucket_id = 'documents' and app.is_approved());
create policy docs_obj_ins on storage.objects for insert to authenticated
  with check (bucket_id = 'documents' and app.is_owner());
create policy docs_obj_upd on storage.objects for update to authenticated
  using (bucket_id = 'documents' and app.is_owner()) with check (bucket_id = 'documents' and app.is_owner());
create policy docs_obj_del on storage.objects for delete to authenticated
  using (bucket_id = 'documents' and app.is_owner());
