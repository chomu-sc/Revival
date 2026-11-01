-- 기도와 말씀 · Supabase 데이터베이스
-- Supabase 대시보드 > SQL Editor 에 이 파일 전체를 붙여넣고 Run 하세요. 여러 번 실행해도 괜찮아요.
-- 총 관리자 지정은 맨 아래 「총 관리자 지정」을 보세요.

-- ─── 하루 기준: 한국 시간 새벽 3시에 날짜가 바뀌어요 ───
create or replace function public.app_today() returns date
language sql stable as $$ select ((now() at time zone 'Asia/Seoul') - interval '3 hours')::date $$;

-- ─── 성경 66권 ───
create table if not exists public.bible_books (
  id smallint primary key,
  name text not null,
  chapters smallint not null,
  testament text not null check (testament in ('OT','NT'))
);
alter table public.bible_books enable row level security;
drop policy if exists "books: readable" on public.bible_books;
create policy "books: readable" on public.bible_books for select to authenticated using (true);
insert into public.bible_books (id, name, chapters, testament) values
  (1, '창세기', 50, 'OT'),
  (2, '출애굽기', 40, 'OT'),
  (3, '레위기', 27, 'OT'),
  (4, '민수기', 36, 'OT'),
  (5, '신명기', 34, 'OT'),
  (6, '여호수아', 24, 'OT'),
  (7, '사사기', 21, 'OT'),
  (8, '룻기', 4, 'OT'),
  (9, '사무엘상', 31, 'OT'),
  (10, '사무엘하', 24, 'OT'),
  (11, '열왕기상', 22, 'OT'),
  (12, '열왕기하', 25, 'OT'),
  (13, '역대상', 29, 'OT'),
  (14, '역대하', 36, 'OT'),
  (15, '에스라', 10, 'OT'),
  (16, '느헤미야', 13, 'OT'),
  (17, '에스더', 10, 'OT'),
  (18, '욥기', 42, 'OT'),
  (19, '시편', 150, 'OT'),
  (20, '잠언', 31, 'OT'),
  (21, '전도서', 12, 'OT'),
  (22, '아가', 8, 'OT'),
  (23, '이사야', 66, 'OT'),
  (24, '예레미야', 52, 'OT'),
  (25, '예레미야애가', 5, 'OT'),
  (26, '에스겔', 48, 'OT'),
  (27, '다니엘', 12, 'OT'),
  (28, '호세아', 14, 'OT'),
  (29, '요엘', 3, 'OT'),
  (30, '아모스', 9, 'OT'),
  (31, '오바댜', 1, 'OT'),
  (32, '요나', 4, 'OT'),
  (33, '미가', 7, 'OT'),
  (34, '나훔', 3, 'OT'),
  (35, '하박국', 3, 'OT'),
  (36, '스바냐', 3, 'OT'),
  (37, '학개', 2, 'OT'),
  (38, '스가랴', 14, 'OT'),
  (39, '말라기', 4, 'OT'),
  (40, '마태복음', 28, 'NT'),
  (41, '마가복음', 16, 'NT'),
  (42, '누가복음', 24, 'NT'),
  (43, '요한복음', 21, 'NT'),
  (44, '사도행전', 28, 'NT'),
  (45, '로마서', 16, 'NT'),
  (46, '고린도전서', 16, 'NT'),
  (47, '고린도후서', 13, 'NT'),
  (48, '갈라디아서', 6, 'NT'),
  (49, '에베소서', 6, 'NT'),
  (50, '빌립보서', 4, 'NT'),
  (51, '골로새서', 4, 'NT'),
  (52, '데살로니가전서', 5, 'NT'),
  (53, '데살로니가후서', 3, 'NT'),
  (54, '디모데전서', 6, 'NT'),
  (55, '디모데후서', 4, 'NT'),
  (56, '디도서', 3, 'NT'),
  (57, '빌레몬서', 1, 'NT'),
  (58, '히브리서', 13, 'NT'),
  (59, '야고보서', 5, 'NT'),
  (60, '베드로전서', 5, 'NT'),
  (61, '베드로후서', 3, 'NT'),
  (62, '요한일서', 5, 'NT'),
  (63, '요한이서', 1, 'NT'),
  (64, '요한삼서', 1, 'NT'),
  (65, '유다서', 1, 'NT'),
  (66, '요한계시록', 22, 'NT')
on conflict (id) do update set name = excluded.name, chapters = excluded.chapters, testament = excluded.testament;

-- ─── 프로필 (별명, 통독 목표, 기본 공개 설정, 총 관리자 여부) ───
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nickname text check (nickname is null or char_length(trim(nickname)) between 2 and 12),
  plan_start date not null default make_date(extract(year from (now() at time zone 'Asia/Seoul'))::int, 1, 1),
  plan_end   date not null default make_date(extract(year from (now() at time zone 'Asia/Seoul'))::int, 12, 31),
  plan_scope text not null default 'ALL' check (plan_scope in ('OT','NT','ALL')),
  plan_times smallint not null default 1 check (plan_times between 1 and 10),
  prayer_anon_default boolean not null default false,
  answer_public_default boolean not null default true,
  created_at timestamptz not null default now(),
  check (plan_end >= plan_start)
);
alter table public.profiles add column if not exists is_super_admin boolean not null default false;
create unique index if not exists profiles_nickname_unique on public.profiles (lower(trim(nickname)));
alter table public.profiles enable row level security;
drop policy if exists "profiles: read own" on public.profiles;
create policy "profiles: read own" on public.profiles for select to authenticated using (id = auth.uid());
drop policy if exists "profiles: update own" on public.profiles;
create policy "profiles: update own" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
-- 사용자는 이 칸들만 바꿀 수 있어요 (총 관리자 여부는 못 바꿔요)
revoke update on public.profiles from authenticated, anon;
grant update (nickname, plan_start, plan_end, plan_scope, plan_times, prayer_anon_default, answer_public_default) on public.profiles to authenticated;

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id) values (new.id) on conflict do nothing;
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();
insert into public.profiles (id) select id from auth.users on conflict do nothing;

-- ─── 서버(그룹)와 멤버 ───
create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 1 and 30),
  code text not null unique,
  created_at timestamptz not null default now()
);
alter table public.groups enable row level security;   -- 아래 함수로만 다뤄요

create table if not exists public.group_members (
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('member','admin')),
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);
create index if not exists group_members_user_idx on public.group_members (user_id);
alter table public.group_members enable row level security;   -- 아래 함수로만 다뤄요

create or replace function public.is_super_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select p.is_super_admin from profiles p where p.id = auth.uid()), false)
$$;
create or replace function public.is_member(p_group uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from group_members m where m.group_id = p_group and m.user_id = auth.uid())
$$;
create or replace function public.can_view_group(p_group uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and (public.is_super_admin() or public.is_member(p_group))
$$;
create or replace function public.can_moderate(p_group uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and (public.is_super_admin() or exists (
    select 1 from group_members m where m.group_id = p_group and m.user_id = auth.uid() and m.role = 'admin'))
$$;

create or replace function public.new_group_code() returns text
language plpgsql security definer set search_path = public as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  c text;
begin
  loop
    c := '';
    for i in 1..6 loop
      c := c || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from groups g where g.code = c);
  end loop;
  return c;
end $$;

-- 서버 목록은 총 관리자만 볼 수 있어요 (다른 사람은 다른 서버가 있는지 알 수 없어요)
create or replace function public.my_groups()
returns table (id uuid, name text, code text, my_role text, member_count bigint)
language sql stable security definer set search_path = public as $$
  select g.id, g.name, g.code,
    (select m.role from group_members m where m.group_id = g.id and m.user_id = auth.uid()),
    (select count(*) from group_members m where m.group_id = g.id)
  from groups g
  where auth.uid() is not null and public.is_super_admin()
  order by g.created_at
$$;

-- 지금 들어와 있는 서버 하나의 정보 (입장 코드는 관리자에게만)
create or replace function public.group_info(p_group uuid)
returns table (id uuid, name text, code text, my_role text, member_count bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.can_view_group(p_group) then raise exception 'NOT_MEMBER'; end if;
  return query
    select g.id, g.name,
      case when public.can_moderate(g.id) then g.code end,
      (select m.role from group_members m where m.group_id = g.id and m.user_id = auth.uid()),
      (select count(*) from group_members m where m.group_id = g.id)
    from groups g where g.id = p_group;
end $$;

create or replace function public.join_group(p_code text) returns uuid
language plpgsql security definer set search_path = public as $$
declare g uuid;
begin
  if auth.uid() is null then raise exception 'NOT_ALLOWED'; end if;
  select id into g from groups where code = upper(trim(p_code));
  if g is null then raise exception 'BAD_CODE'; end if;
  insert into group_members (group_id, user_id) values (g, auth.uid()) on conflict do nothing;
  return g;
end $$;

create or replace function public.leave_group(p_group uuid) returns void
language sql security definer set search_path = public as $$
  delete from group_members where group_id = p_group and user_id = auth.uid()
$$;

-- 총 관리자만: 서버 만들기·이름 바꾸기·지우기·관리자 임명
create or replace function public.create_group(p_name text) returns uuid
language plpgsql security definer set search_path = public as $$
declare g uuid;
begin
  if not public.is_super_admin() then raise exception 'NOT_ALLOWED'; end if;
  insert into groups (name, code) values (trim(p_name), public.new_group_code()) returning id into g;
  insert into group_members (group_id, user_id, role) values (g, auth.uid(), 'admin');
  return g;
end $$;

create or replace function public.rename_group(p_group uuid, p_name text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_super_admin() then raise exception 'NOT_ALLOWED'; end if;
  update groups set name = trim(p_name) where id = p_group;
end $$;

create or replace function public.delete_group(p_group uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_super_admin() then raise exception 'NOT_ALLOWED'; end if;
  delete from groups where id = p_group;
end $$;

create or replace function public.set_member_role(p_group uuid, p_user uuid, p_role text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_super_admin() then raise exception 'NOT_ALLOWED'; end if;
  if p_role not in ('member','admin') then raise exception 'NOT_ALLOWED'; end if;
  update group_members set role = p_role where group_id = p_group and user_id = p_user;
end $$;

-- 서버 관리자와 총 관리자: 멤버 보기·내보내기·초대 코드 바꾸기
create or replace function public.group_members_list(p_group uuid)
returns table (user_id uuid, nickname text, role text, joined_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.can_moderate(p_group) then raise exception 'NOT_ALLOWED'; end if;
  return query
    select m.user_id, p.nickname, m.role, m.joined_at
    from group_members m join profiles p on p.id = m.user_id
    where m.group_id = p_group
    order by (m.role = 'admin') desc, p.nickname;
end $$;

create or replace function public.remove_member(p_group uuid, p_user uuid) returns void
language plpgsql security definer set search_path = public as $$
declare target_role text;
begin
  if not public.can_moderate(p_group) then raise exception 'NOT_ALLOWED'; end if;
  select role into target_role from group_members where group_id = p_group and user_id = p_user;
  if target_role = 'admin' and not public.is_super_admin() then raise exception 'NOT_ALLOWED'; end if;
  if p_user = auth.uid() then raise exception 'NOT_ALLOWED'; end if;
  delete from group_members where group_id = p_group and user_id = p_user;
end $$;

create or replace function public.regenerate_group_code(p_group uuid) returns text
language plpgsql security definer set search_path = public as $$
declare c text;
begin
  if not public.can_moderate(p_group) then raise exception 'NOT_ALLOWED'; end if;
  c := public.new_group_code();
  update groups set code = c where id = p_group;
  return c;
end $$;

-- ─── 기도제목 (서버마다 따로) ───
create table if not exists public.prayers (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  content text not null check (char_length(trim(content)) between 1 and 500),
  is_anonymous boolean not null default false,
  ends_at timestamptz not null default now() + interval '7 days',
  created_at timestamptz not null default now(),
  answer text check (answer in ('O','X','WAIT','HISWAY','NONE')),
  answer_comment text check (answer_comment is null or char_length(answer_comment) <= 300),
  answered_at timestamptz,
  answer_public boolean not null default true
);
alter table public.prayers add column if not exists group_id uuid references public.groups(id) on delete cascade;
create index if not exists prayers_group_idx on public.prayers (group_id, created_at desc);
create index if not exists prayers_user_idx on public.prayers (user_id);
alter table public.prayers enable row level security;
drop policy if exists "prayers: read own" on public.prayers;
create policy "prayers: read own" on public.prayers for select to authenticated using (user_id = auth.uid());
drop policy if exists "prayers: insert own" on public.prayers;
create policy "prayers: insert own" on public.prayers for insert to authenticated
  with check (user_id = auth.uid() and group_id is not null and public.can_view_group(group_id));
drop policy if exists "prayers: update own" on public.prayers;
create policy "prayers: update own" on public.prayers for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "prayers: delete own" on public.prayers;
create policy "prayers: delete own" on public.prayers for delete to authenticated using (user_id = auth.uid());
-- 작성자는 내용과 응답만 바꿀 수 있어요 (서버를 옮길 수는 없어요)
revoke update on public.prayers from authenticated, anon;
grant update (content, is_anonymous, ends_at, answer, answer_comment, answered_at, answer_public) on public.prayers to authenticated;

-- 관리자 삭제: 서버 관리자는 자기 서버, 총 관리자는 모든 서버
create or replace function public.mod_delete_prayer(p_prayer bigint) returns void
language plpgsql security definer set search_path = public as $$
declare g uuid; owner uuid;
begin
  select group_id, user_id into g, owner from prayers where id = p_prayer;
  if owner is null then return; end if;
  if not (owner = auth.uid() or public.is_super_admin() or (g is not null and public.can_moderate(g))) then
    raise exception 'NOT_ALLOWED';
  end if;
  delete from prayers where id = p_prayer;
end $$;

-- ─── 기도 체크 (사람마다 따로 1시간에 한 번, 그 서버 멤버만) ───
create table if not exists public.prayer_marks (
  id bigint generated always as identity primary key,
  prayer_id bigint not null references public.prayers(id) on delete cascade,
  user_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);
create index if not exists prayer_marks_prayer_idx on public.prayer_marks (prayer_id);
create index if not exists prayer_marks_user_idx on public.prayer_marks (user_id, prayer_id, created_at desc);
alter table public.prayer_marks enable row level security;
drop policy if exists "marks: read own" on public.prayer_marks;
create policy "marks: read own" on public.prayer_marks for select to authenticated using (user_id = auth.uid());
drop policy if exists "marks: insert own" on public.prayer_marks;
create policy "marks: insert own" on public.prayer_marks for insert to authenticated with check (user_id = auth.uid());

create or replace function public.check_prayer_mark() returns trigger
language plpgsql security definer set search_path = public as $$
declare g uuid;
begin
  new.created_at := now();
  select p.group_id into g from prayers p where p.id = new.prayer_id and p.answer is null and p.ends_at > now();
  if not found then raise exception 'PRAYER_CLOSED'; end if;
  if g is null or not public.can_view_group(g) then raise exception 'NOT_MEMBER'; end if;
  perform pg_advisory_xact_lock(hashtext(new.user_id::text || ':' || new.prayer_id::text));
  if exists (select 1 from prayer_marks m where m.prayer_id = new.prayer_id and m.user_id = new.user_id and m.created_at > now() - interval '1 hour') then
    raise exception 'TOO_SOON';
  end if;
  return new;
end $$;
drop trigger if exists prayer_marks_check on public.prayer_marks;
create trigger prayer_marks_check before insert on public.prayer_marks for each row execute function public.check_prayer_mark();

-- ─── 성경 읽기 기록 (개인 기록, 서버와 상관없이 하나) ───
create table if not exists public.readings (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  book smallint not null references public.bible_books(id),
  chapter smallint not null check (chapter >= 1),
  read_on date not null default public.app_today(),
  created_at timestamptz not null default now()
);
create index if not exists readings_user_idx on public.readings (user_id, read_on);
alter table public.readings enable row level security;
drop policy if exists "readings: read own" on public.readings;
create policy "readings: read own" on public.readings for select to authenticated using (user_id = auth.uid());
drop policy if exists "readings: insert own" on public.readings;
create policy "readings: insert own" on public.readings for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "readings: delete own" on public.readings;
create policy "readings: delete own" on public.readings for delete to authenticated using (user_id = auth.uid());

create or replace function public.check_reading() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.read_on := app_today();
  if not exists (select 1 from bible_books b where b.id = new.book and new.chapter <= b.chapters) then
    raise exception 'BAD_CHAPTER';
  end if;
  return new;
end $$;
drop trigger if exists readings_check on public.readings;
create trigger readings_check before insert on public.readings for each row execute function public.check_reading();

-- ─── 서버의 기도제목 목록 (진행 중 + 내 것 + 공개된 응답) ───
drop function if exists public.get_prayers();
drop function if exists public.get_prayers(uuid);
create or replace function public.get_prayers(p_group uuid)
returns table (
  id bigint, content text, author text, is_mine boolean, is_anonymous boolean,
  ends_at timestamptz, created_at timestamptz, mark_count bigint, my_mark_count bigint, my_last_mark timestamptz,
  answer text, answer_comment text, answered_at timestamptz, answer_public boolean
)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.can_view_group(p_group) then raise exception 'NOT_MEMBER'; end if;
  return query
  select p.id, p.content,
    case when p.is_anonymous and p.user_id <> auth.uid() then null else pr.nickname end,
    p.user_id = auth.uid(), p.is_anonymous, p.ends_at, p.created_at,
    (select count(*) from prayer_marks m where m.prayer_id = p.id),
    (select count(*) from prayer_marks m where m.prayer_id = p.id and m.user_id = auth.uid()),
    (select max(m.created_at) from prayer_marks m where m.prayer_id = p.id and m.user_id = auth.uid()),
    p.answer, p.answer_comment, p.answered_at, p.answer_public
  from prayers p join profiles pr on pr.id = p.user_id
  where p.group_id = p_group
    and (p.user_id = auth.uid()
         or (p.answer is null and p.ends_at > now())
         or (p.answer in ('O','X','WAIT','HISWAY') and p.answer_public))
  order by p.created_at desc
  limit 1000;
end $$;

-- ─── 함께 읽는 사람들 (그 서버 멤버의 별명별 진행률) ───
drop function if exists public.reading_board();
create or replace function public.reading_board(p_group uuid)
returns table (nickname text, pct numeric, is_me boolean)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.can_view_group(p_group) then raise exception 'NOT_MEMBER'; end if;
  return query
  with mem as (
    select pr.* from profiles pr join group_members gm on gm.user_id = pr.id
    where gm.group_id = p_group and pr.nickname is not null
  ),
  ch as (
    select b.id as book, gs.n as chapter, b.testament
    from bible_books b cross join lateral generate_series(1, b.chapters) as gs(n)
  ),
  cnt as (
    select r.user_id, r.book, r.chapter, count(*) as c
    from readings r join mem on mem.id = r.user_id
    where r.read_on between mem.plan_start and mem.plan_end
    group by r.user_id, r.book, r.chapter
  ),
  prog as (
    select mem.id,
      sum(least(coalesce(cnt.c, 0), mem.plan_times))::numeric as done,
      (count(*) * mem.plan_times)::numeric as total
    from mem
    join ch on (mem.plan_scope = 'ALL' or ch.testament = mem.plan_scope)
    left join cnt on cnt.user_id = mem.id and cnt.book = ch.book and cnt.chapter = ch.chapter
    group by mem.id, mem.plan_times
  )
  select mem.nickname, (floor(prog.done * 1000 / nullif(prog.total, 0)) / 10)::numeric(6,1), mem.id = auth.uid()
  from mem join prog on prog.id = mem.id
  order by 2 desc nulls last, 1;
end $$;

-- 오늘 성경을 읽은 사람 수 (누가 읽었는지는 알려주지 않아요)
create or replace function public.group_today_readers(p_group uuid) returns integer
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.can_view_group(p_group) then raise exception 'NOT_MEMBER'; end if;
  return (select count(distinct r.user_id)::int
          from readings r join group_members gm on gm.user_id = r.user_id
          where gm.group_id = p_group and r.read_on = app_today());
end $$;

-- ─── 함수 실행 권한: 로그인한 사용자만 ───
do $$
declare f text;
begin
  foreach f in array array[
    'is_super_admin()', 'is_member(uuid)', 'can_view_group(uuid)', 'can_moderate(uuid)',
    'my_groups()', 'group_info(uuid)', 'join_group(text)', 'leave_group(uuid)', 'create_group(text)', 'rename_group(uuid, text)',
    'delete_group(uuid)', 'set_member_role(uuid, uuid, text)', 'group_members_list(uuid)', 'remove_member(uuid, uuid)',
    'regenerate_group_code(uuid)', 'mod_delete_prayer(bigint)', 'get_prayers(uuid)', 'reading_board(uuid)', 'group_today_readers(uuid)'
  ] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  revoke all on function public.new_group_code() from public, anon, authenticated;
end $$;

-- ─── 총 관리자 지정 ───
-- SQL Editor 에서만 실행할 수 있어요. 앱에서 그 이메일로 가입한 다음, 아래 한 줄을 따로 실행하세요.
create or replace function public.make_super_admin(p_email text) returns text
language plpgsql security definer set search_path = public as $$
declare uid uuid;
begin
  select id into uid from auth.users where lower(email) = lower(trim(p_email));
  if uid is null then return '아직 가입하지 않은 이메일이에요. 앱에서 먼저 가입해 주세요.'; end if;
  insert into profiles (id) values (uid) on conflict do nothing;
  update profiles set is_super_admin = true where id = uid;
  return '총 관리자로 지정했어요.';
end $$;
revoke all on function public.make_super_admin(text) from public, anon, authenticated;

-- 가입한 뒤 실행:  select public.make_super_admin('joseungchan164@gmail.com');

-- ─── 보안 정리: 트리거 함수는 직접 호출할 수 없게, 검색 경로 고정 ───
alter function public.app_today() set search_path = public;
revoke all on function public.check_prayer_mark() from public, anon, authenticated;
revoke all on function public.check_reading() from public, anon, authenticated;
revoke all on function public.handle_new_user() from public, anon, authenticated;

-- ─── 회원가입 때 넣은 입장 코드로 바로 서버에 들어가기 ───
create or replace function public.check_group_code(p_code text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from groups where code = upper(trim(p_code)))
$$;
revoke all on function public.check_group_code(text) from public;
grant execute on function public.check_group_code(text) to anon, authenticated;

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id) values (new.id) on conflict do nothing;
  if coalesce(new.raw_user_meta_data ->> 'join_code', '') <> '' then
    insert into public.group_members (group_id, user_id)
    select g.id, new.id from public.groups g where g.code = upper(trim(new.raw_user_meta_data ->> 'join_code'))
    on conflict do nothing;
  end if;
  return new;
end $$;
revoke all on function public.handle_new_user() from public, anon, authenticated;

-- 로그인하면 마지막으로 들어간 서버가 열려요
create or replace function public.my_last_group() returns uuid
language sql stable security definer set search_path = public as $$
  select group_id from group_members where user_id = auth.uid() order by joined_at desc limit 1
$$;
revoke all on function public.my_last_group() from public, anon;
grant execute on function public.my_last_group() to authenticated;

-- ─── 문의하기 (개발자에게 일방향으로 전달) ───
drop function if exists public.reply_inquiry(bigint, text);
drop function if exists public.mark_inquiries_seen();
create table if not exists public.inquiries (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  group_id uuid references public.groups(id) on delete set null,
  content text not null check (char_length(trim(content)) between 1 and 1000),
  created_at timestamptz not null default now(),
  reply text check (reply is null or char_length(reply) <= 1000),
  replied_at timestamptz,
  reply_seen boolean not null default false
);
create index if not exists inquiries_user_idx on public.inquiries (user_id, created_at desc);
alter table public.inquiries enable row level security;
drop policy if exists "inquiries: read own" on public.inquiries;
create policy "inquiries: read own" on public.inquiries for select to authenticated using (user_id = auth.uid());
drop policy if exists "inquiries: insert own" on public.inquiries;
create policy "inquiries: insert own" on public.inquiries for insert to authenticated
  with check (user_id = auth.uid() and (group_id is null or public.can_view_group(group_id)));
revoke update, delete on public.inquiries from authenticated, anon;

create or replace function public.admin_inquiries()
returns table (id bigint, nickname text, email text, group_name text, content text, created_at timestamptz, reply text, replied_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_super_admin() then raise exception 'NOT_ALLOWED'; end if;
  return query
    select q.id, p.nickname, u.email::text, g.name, q.content, q.created_at, q.reply, q.replied_at
    from inquiries q join profiles p on p.id = q.user_id join auth.users u on u.id = q.user_id
    left join groups g on g.id = q.group_id
    order by q.created_at desc
    limit 500;
end $$;

revoke all on function public.admin_inquiries() from public, anon;
grant execute on function public.admin_inquiries() to authenticated;

-- ─── 회원 탈퇴 (비밀번호를 서버에서 확인) ───
create or replace function public.delete_my_account(p_password text) returns void
language plpgsql security definer set search_path = public, extensions as $$
declare enc text;
begin
  if auth.uid() is null then raise exception 'NOT_ALLOWED'; end if;
  if public.is_super_admin() then raise exception 'SUPER_ADMIN'; end if;
  select u.encrypted_password into enc from auth.users u where u.id = auth.uid();
  if enc is null or enc = '' or extensions.crypt(coalesce(p_password, ''), enc) <> enc then
    raise exception 'BAD_PASSWORD';
  end if;
  delete from auth.users where id = auth.uid();
end $$;
revoke all on function public.delete_my_account(text) from public, anon;
grant execute on function public.delete_my_account(text) to authenticated;

-- ─── 푸시 알림 (총 관리자에게 새 문의 알림) ───
create table if not exists public.push_subscriptions (
  endpoint text primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  p256dh text not null,
  auth text not null,
  created_at timestamptz not null default now()
);
create index if not exists push_subscriptions_user_idx on public.push_subscriptions (user_id);
alter table public.push_subscriptions enable row level security;
revoke all on public.push_subscriptions from anon, authenticated;

-- 서버 함수만 읽는 비밀 저장소 (VAPID 키). 값은 SQL Editor에서 따로 넣어요.
create table if not exists public.app_secrets (key text primary key, value text not null);
alter table public.app_secrets enable row level security;
revoke all on public.app_secrets from anon, authenticated;

create table if not exists public.inquiry_notified (
  inquiry_id bigint primary key references public.inquiries(id) on delete cascade,
  notified_at timestamptz not null default now()
);
alter table public.inquiry_notified enable row level security;
revoke all on public.inquiry_notified from anon, authenticated;

create or replace function public.save_push_subscription(p_endpoint text, p_p256dh text, p_auth text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'NOT_ALLOWED'; end if;
  if coalesce(p_endpoint, '') !~ '^https://' or length(p_endpoint) > 1000 then raise exception 'BAD_SUBSCRIPTION'; end if;
  insert into push_subscriptions (endpoint, user_id, p256dh, auth)
  values (p_endpoint, auth.uid(), p_p256dh, p_auth)
  on conflict (endpoint) do update set user_id = excluded.user_id, p256dh = excluded.p256dh, auth = excluded.auth, created_at = now();
end $$;
create or replace function public.remove_push_subscription(p_endpoint text) returns void
language sql security definer set search_path = public as $$
  delete from push_subscriptions where endpoint = p_endpoint and user_id = auth.uid()
$$;
create or replace function public.has_push_subscription(p_endpoint text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from push_subscriptions where endpoint = p_endpoint and user_id = auth.uid())
$$;
revoke all on function public.save_push_subscription(text, text, text) from public, anon;
revoke all on function public.remove_push_subscription(text) from public, anon;
revoke all on function public.has_push_subscription(text) from public, anon;
grant execute on function public.save_push_subscription(text, text, text) to authenticated;
grant execute on function public.remove_push_subscription(text) to authenticated;
grant execute on function public.has_push_subscription(text) to authenticated;
