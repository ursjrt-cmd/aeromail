-- AERO Mail + Studio schema
-- Run this entire file in Supabase Dashboard -> SQL Editor -> New query.

create extension if not exists pgcrypto;

create table if not exists public.mail_domains (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  domain text not null unique,
  provider_domain_id text not null unique,
  provider_status text not null default 'pending',
  dns_records jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.mailboxes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  domain_id uuid not null references public.mail_domains(id) on delete cascade,
  address text not null unique,
  display_name text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  mailbox_id uuid not null references public.mailboxes(id) on delete cascade,
  direction text not null check (direction in ('inbound','outbound','draft')),
  provider_message_id text,
  from_address text not null,
  to_addresses text[] not null default '{}',
  cc_addresses text[] not null default '{}',
  bcc_addresses text[] not null default '{}',
  subject text not null default '(no subject)',
  text_body text,
  html_body text,
  folder text not null default 'inbox',
  is_read boolean not null default false,
  is_starred boolean not null default false,
  sent_at timestamptz,
  created_at timestamptz not null default now(),
  constraint messages_provider_unique unique (mailbox_id, provider_message_id)
);

create index if not exists messages_mailbox_created_idx on public.messages(mailbox_id, created_at desc);
create index if not exists messages_mailbox_folder_idx on public.messages(mailbox_id, folder, created_at desc);

create table if not exists public.message_attachments (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.messages(id) on delete cascade,
  file_name text not null,
  content_type text,
  size_bytes bigint,
  storage_path text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.sites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  slug text not null unique,
  custom_domain text unique,
  domain_verification_token text,
  custom_domain_verified boolean not null default false,
  is_published boolean not null default false,
  plugins jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.site_pages (
  id uuid primary key default gen_random_uuid(),
  site_id uuid not null references public.sites(id) on delete cascade,
  title text not null,
  slug text not null,
  is_home boolean not null default false,
  is_published boolean not null default true,
  blocks jsonb not null default '[]'::jsonb,
  seo_title text,
  seo_description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(site_id, slug)
);

create index if not exists site_pages_site_slug_idx on public.site_pages(site_id, slug);

-- Row level security: a signed-in user only sees their own mail and sites.
alter table public.mail_domains enable row level security;
alter table public.mailboxes enable row level security;
alter table public.messages enable row level security;
alter table public.message_attachments enable row level security;
alter table public.sites enable row level security;
alter table public.site_pages enable row level security;

create policy "Users manage their mail domains" on public.mail_domains
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Users manage their mailboxes" on public.mailboxes
  for all using (auth.uid() = user_id)
  with check (auth.uid() = user_id and exists (
    select 1 from public.mail_domains d where d.id = domain_id and d.user_id = auth.uid()
  ));

create policy "Users read their messages" on public.messages
  for select using (exists (
    select 1 from public.mailboxes b where b.id = mailbox_id and b.user_id = auth.uid()
  ));

create policy "Users create their messages" on public.messages
  for insert with check (exists (
    select 1 from public.mailboxes b where b.id = mailbox_id and b.user_id = auth.uid()
  ));

create policy "Users update their messages" on public.messages
  for update using (exists (
    select 1 from public.mailboxes b where b.id = mailbox_id and b.user_id = auth.uid()
  )) with check (exists (
    select 1 from public.mailboxes b where b.id = mailbox_id and b.user_id = auth.uid()
  ));

create policy "Users read their attachments" on public.message_attachments
  for select using (exists (
    select 1 from public.messages m
    join public.mailboxes b on b.id = m.mailbox_id
    where m.id = message_id and b.user_id = auth.uid()
  ));

create policy "Users manage their sites" on public.sites
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Users manage pages in their sites" on public.site_pages
  for all using (exists (
    select 1 from public.sites s where s.id = site_id and s.user_id = auth.uid()
  )) with check (exists (
    select 1 from public.sites s where s.id = site_id and s.user_id = auth.uid()
  ));

-- Public visitors can only read published websites and published pages.
create policy "Public can view published sites" on public.sites
  for select using (is_published = true);

create policy "Public can view published pages" on public.site_pages
  for select using (is_published = true and exists (
    select 1 from public.sites s where s.id = site_id and s.is_published = true
  ));

-- Private file bucket. Uploads are done server-side with the service-role key.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('mail-attachments', 'mail-attachments', false, 20971520,
  array['application/pdf','image/png','image/jpeg','image/gif','image/webp','text/plain','application/zip','application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document'])
on conflict (id) do update set public = false, file_size_limit = 20971520;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('site-assets', 'site-assets', true, 10485760,
  array['image/png','image/jpeg','image/gif','image/webp','image/svg+xml'])
on conflict (id) do update set public = true, file_size_limit = 10485760;

create policy "Users can upload their site assets" on storage.objects
  for insert with check (
    bucket_id = 'site-assets'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can update their site assets" on storage.objects
  for update using (
    bucket_id = 'site-assets'
    and (storage.foldername(name))[1] = auth.uid()::text
  ) with check (
    bucket_id = 'site-assets'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can delete their site assets" on storage.objects
  for delete using (
    bucket_id = 'site-assets'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can read their mail attachment objects" on storage.objects
  for select using (
    bucket_id = 'mail-attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Keep update timestamps accurate when rows are edited by APIs.
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists mail_domains_updated_at on public.mail_domains;
create trigger mail_domains_updated_at before update on public.mail_domains
for each row execute function public.set_updated_at();

drop trigger if exists sites_updated_at on public.sites;
create trigger sites_updated_at before update on public.sites
for each row execute function public.set_updated_at();

drop trigger if exists site_pages_updated_at on public.site_pages;
create trigger site_pages_updated_at before update on public.site_pages
for each row execute function public.set_updated_at();
