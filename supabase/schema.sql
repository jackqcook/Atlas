-- Atlas Database Schema
-- Run this in your Supabase SQL editor

-- Users (mirrors auth.users, holds app-level profile)
create table public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  phone text unique not null,
  display_name text not null default 'Member',
  avatar_url text,
  public_key text not null default '',
  created_at timestamptz not null default now()
);

-- Groups
create table public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text not null default '',
  constitution text not null default '',
  invite_code text unique not null,
  created_at timestamptz not null default now()
);

-- Memberships
create table public.memberships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  group_id uuid not null references public.groups(id) on delete cascade,
  role text not null default 'initiate' check (role in ('initiate', 'member', 'council', 'founder')),
  invited_by_id uuid references public.users(id) on delete set null,
  joined_at timestamptz not null default now(),
  unique (user_id, group_id)
);

-- Channels
create table public.channels (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  name text not null,
  type text not null default 'general' check (type in ('general', 'announcements', 'governance')),
  created_at timestamptz not null default now()
);

-- Messages
create table public.messages (
  id uuid primary key default gen_random_uuid(),
  channel_id uuid not null references public.channels(id) on delete cascade,
  sender_id uuid not null references public.users(id) on delete cascade,
  content text not null,
  thread_id uuid references public.messages(id) on delete set null,
  created_at timestamptz not null default now()
);

-- Proposals
create table public.proposals (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  proposer_id uuid not null references public.users(id) on delete cascade,
  title text not null,
  body text not null default '',
  type text not null default 'general' check (type in ('invite_member', 'remove_member', 'change_rules', 'general')),
  status text not null default 'open' check (status in ('open', 'passed', 'rejected', 'expired')),
  voting_deadline timestamptz not null,
  yes_count int not null default 0,
  no_count int not null default 0,
  abstain_count int not null default 0,
  created_at timestamptz not null default now()
);

-- Votes
create table public.votes (
  id uuid primary key default gen_random_uuid(),
  proposal_id uuid not null references public.proposals(id) on delete cascade,
  voter_id uuid not null references public.users(id) on delete cascade,
  choice text not null check (choice in ('yes', 'no', 'abstain')),
  created_at timestamptz not null default now(),
  unique (proposal_id, voter_id)
);

-- Indexes
create index on public.memberships(user_id);
create index on public.memberships(group_id);
create index on public.messages(channel_id, created_at desc);
create index on public.proposals(group_id, created_at desc);
create index on public.votes(proposal_id);

-- Row Level Security
alter table public.users enable row level security;
alter table public.groups enable row level security;
alter table public.memberships enable row level security;
alter table public.channels enable row level security;
alter table public.messages enable row level security;
alter table public.proposals enable row level security;
alter table public.votes enable row level security;

-- Users: readable by all authenticated, writable by self
create policy "users_read" on public.users for select using (auth.role() = 'authenticated');
create policy "users_insert" on public.users for insert with check (auth.uid() = id);
create policy "users_update" on public.users for update using (auth.uid() = id);

-- Groups: readable by members, writable by authenticated
create policy "groups_read" on public.groups for select using (
  exists (select 1 from public.memberships where group_id = id and user_id = auth.uid())
);
create policy "groups_insert" on public.groups for insert with check (auth.role() = 'authenticated');

-- Memberships: readable by group members
create policy "memberships_read" on public.memberships for select using (
  user_id = auth.uid()
  or exists (select 1 from public.memberships m2 where m2.group_id = group_id and m2.user_id = auth.uid())
);
create policy "memberships_insert" on public.memberships for insert with check (auth.role() = 'authenticated');
create policy "memberships_update" on public.memberships for update using (
  exists (select 1 from public.memberships where group_id = group_id and user_id = auth.uid() and role in ('council', 'founder'))
);

-- Channels: readable/writable by group members
create policy "channels_read" on public.channels for select using (
  exists (select 1 from public.memberships where group_id = channels.group_id and user_id = auth.uid())
);
create policy "channels_insert" on public.channels for insert with check (auth.role() = 'authenticated');

-- Messages: readable/writable by group members
create policy "messages_read" on public.messages for select using (
  exists (
    select 1 from public.channels c
    join public.memberships m on m.group_id = c.group_id
    where c.id = messages.channel_id and m.user_id = auth.uid()
  )
);
create policy "messages_insert" on public.messages for insert with check (
  auth.uid() = sender_id
  and exists (
    select 1 from public.channels c
    join public.memberships m on m.group_id = c.group_id
    where c.id = channel_id and m.user_id = auth.uid()
  )
);

-- Proposals: readable/writable by group members
create policy "proposals_read" on public.proposals for select using (
  exists (select 1 from public.memberships where group_id = proposals.group_id and user_id = auth.uid())
);
create policy "proposals_insert" on public.proposals for insert with check (
  auth.uid() = proposer_id
  and exists (select 1 from public.memberships where group_id = proposals.group_id and user_id = auth.uid() and role != 'initiate')
);

-- Votes: readable/writable by group members
create policy "votes_read" on public.votes for select using (
  exists (
    select 1 from public.proposals p
    join public.memberships m on m.group_id = p.group_id
    where p.id = votes.proposal_id and m.user_id = auth.uid()
  )
);
create policy "votes_insert" on public.votes for insert with check (auth.uid() = voter_id);
create policy "votes_update" on public.votes for update using (auth.uid() = voter_id);

-- Realtime: enable for messages table
alter publication supabase_realtime add table public.messages;
