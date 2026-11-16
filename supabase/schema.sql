-- 골목대장 서버 데이터베이스 (Supabase / PostgreSQL)
-- Supabase 대시보드 → SQL Editor → New query 에 이 파일 전체를 붙여 넣고 Run.
-- 앱은 폰 안 SQLite(lib/data/db.dart)에 먼저 저장하고, 로그인돼 있으면 같은 내용을 여기에도 올린다.
-- 사용자 구분은 Supabase 로그인(auth.users)의 id. user_id 는 비워 두면 로그인한 사람 id가 자동으로 들어간다.

create table if not exists profiles (
  user_id      uuid primary key default auth.uid() references auth.users on delete cascade,
  nickname     text not null unique check (char_length(nickname) between 2 and 10),
  character_id text not null,
  area_name    text not null,
  provider     text not null,
  marketing    boolean not null default false,
  joined_at    timestamptz not null default now()
);

-- 앱이 만든 id('walk_…', 'spot_…')를 그대로 쓰도록 id는 text
create table if not exists walks (
  id          text primary key,
  user_id     uuid not null default auth.uid() references auth.users on delete cascade,
  started_at  timestamptz not null,
  ended_at    timestamptz,
  distance_m  real not null default 0,
  new_cells   int not null default 0,
  path        jsonb not null default '[]'   -- [[경도, 위도], ...]
);

create table if not exists spots (
  id          text primary key,
  user_id     uuid not null default auth.uid() references auth.users on delete cascade,
  walk_id     text,
  lat         double precision not null,
  lng         double precision not null,
  sticker_id  text not null,
  title       text not null,
  memo        text not null default '',
  photo       text,
  visibility  text not null default 'all' check (visibility in ('all', 'friends', 'me')),
  shared      boolean not null default false,
  created_at  timestamptz not null default now()
);

-- 밝힌 칸 (50m 격자, '행:열')
create table if not exists explored (
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  cell    text not null,
  at      timestamptz not null default now(),
  primary key (user_id, cell)
);

-- kind: owned(스티커) / stamp(스탬프) / reward(보상) / store(방문 가게)
create table if not exists marks (
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  kind    text not null,
  id      text not null,
  at      timestamptz not null default now(),
  primary key (user_id, kind, id)
);

create table if not exists coupons (
  id        text primary key,
  user_id   uuid not null default auth.uid() references auth.users on delete cascade,
  store_id  text not null,
  title     text not null,
  issued_at timestamptz not null default now(),
  used_at   timestamptz
);

-- 행 단위 보안: 자기 데이터만 읽고 쓴다.
alter table profiles enable row level security;
alter table walks    enable row level security;
alter table spots    enable row level security;
alter table explored enable row level security;
alter table marks    enable row level security;
alter table coupons  enable row level security;

drop policy if exists "본인" on profiles;
drop policy if exists "본인" on walks;
drop policy if exists "본인" on spots;
drop policy if exists "본인" on explored;
drop policy if exists "본인" on marks;
drop policy if exists "본인" on coupons;
create policy "본인" on profiles for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "본인" on walks    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "본인" on spots    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "본인" on explored for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "본인" on marks    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "본인" on coupons  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- 닉네임 중복 확인 (다른 사람 프로필을 통째로 열지 않고 있는지만 알려 준다)
create or replace function nickname_taken(name text) returns boolean
language sql security definer set search_path = public stable as $$
  select exists (select 1 from profiles where lower(nickname) = lower(name));
$$;
grant execute on function nickname_taken(text) to anon, authenticated;

-- 골목 피드: 전체 공개로 공유한 기록 + 글쓴이 닉네임·캐릭터·동네 (정확한 좌표는 내보내지 않음)
create or replace view public_feed as
  select s.id, s.sticker_id, s.title, s.memo, s.created_at,
         p.nickname, p.character_id, p.area_name
  from spots s join profiles p on p.user_id = s.user_id
  where s.shared and s.visibility = 'all'
  order by s.created_at desc
  limit 100;

-- 이번 주 동네 리더보드 (밝힌 칸 수)
create or replace view weekly_leaderboard as
  select p.area_name, p.nickname, p.character_id, count(e.cell)::int as cells
  from profiles p join explored e on e.user_id = p.user_id
  where e.at > now() - interval '7 days'
  group by p.area_name, p.nickname, p.character_id;

-- 두 화면은 로그인한 사람만 볼 수 있다.
revoke all on public_feed, weekly_leaderboard from anon;
grant select on public_feed, weekly_leaderboard to authenticated;

-- 이후 수정: supabase/migrations/ 폴더의 파일을 번호 순서대로 SQL Editor에서 실행한다.
--   002_username_login.sql : 아이디로 로그인 (accounts 표, 아이디 중복 확인)
--   003_area_leaderboard.sql : 걸은 동네 기준 리더보드 (explored.area, 리더보드 함수, 나 숨기기)
