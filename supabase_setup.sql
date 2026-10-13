-- نفّذ هذا الملف في Supabase:
-- Dashboard -> SQL Editor -> New query -> الصق -> Run

-- ===== 1. جدول العملاء =====
create table if not exists public.customers (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  phone         text not null,
  address       text not null default '',
  router_number text not null default '',
  router_type   text not null default '',
  location_url  text not null default '',
  plan          text not null default '10 Mbps',
  status        text not null default 'active',
  notes         text not null default '',
  created_at    timestamptz not null default now(),
  constraint customers_phone_check check (phone ~ '^[0-9]{9}$')
);

alter table public.customers enable row level security;

grant select, insert, update, delete on public.customers to anon;

drop policy if exists "customers_select" on public.customers;
drop policy if exists "customers_insert" on public.customers;
drop policy if exists "customers_update" on public.customers;
drop policy if exists "customers_delete" on public.customers;

create policy "customers_select" on public.customers
  for select to anon using (true);
create policy "customers_insert" on public.customers
  for insert to anon with check (true);
create policy "customers_update" on public.customers
  for update to anon using (true) with check (true);
create policy "customers_delete" on public.customers
  for delete to anon using (true);


-- ===== 2. سجل النشاط المشترك (للإشعارات وعرض التعديلات عند الجميع) =====
create table if not exists public.activity_log (
  id            uuid primary key default gen_random_uuid(),
  actor_id      text not null,
  actor_name    text not null default '',
  action        text not null,
  customer_name text not null default '',
  details       text not null default '',
  created_at    timestamptz not null default now()
);

create index if not exists activity_log_created_at_idx
  on public.activity_log (created_at);

alter table public.activity_log enable row level security;

-- القراءة والإضافة فقط
grant select, insert on public.activity_log to anon;

drop policy if exists "activity_select" on public.activity_log;
drop policy if exists "activity_insert" on public.activity_log;

create policy "activity_select" on public.activity_log
  for select to anon using (true);
create policy "activity_insert" on public.activity_log
  for insert to anon with check (true);
