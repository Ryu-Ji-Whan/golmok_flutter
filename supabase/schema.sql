-- 골목대장 서버 데이터베이스 초안 (Supabase / PostgreSQL)
-- 지금 앱은 폰 안 SQLite(lib/data/db.dart)에 저장한다. 서버를 붙일 때 이 표들을 만들고
-- 같은 이름의 칸을 그대로 옮기면 된다. 사용자 구분은 Supabase 로그인(auth.users) id로 한다.

create table profiles (
  user_id      uuid primary key references auth.users on delete cascade,
  nickname     text not null unique check (char_length(nickname) between 2 and 10),
  character_id text not null,
  area_name    text not null,
  provider     text not null,             -- kakao / apple / google
  marketing    boolean not null default false,
  joined_at    timestamptz not null default now()
);

create table walks (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users on delete cascade,
  started_at  timestamptz not null,
  ended_at    timestamptz,
  distance_m  real not null default 0,
  new_cells   int not null default 0,
  path        jsonb not null default '[]'  -- [[경도, 위도], ...]
);

create table spots (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users on delete cascade,
  walk_id     uuid references walks on delete set null,
  lat         double precision not null,
  lng         double precision not null,
  sticker_id  text not null,
  title       text not null,
  memo        text not null default '',
  photo_url   text,
  visibility  text not null default 'all' check (visibility in ('all', 'friends', 'me')),
  shared      boolean not null default false,
  created_at  timestamptz not null default now()
);

-- 밝힌 칸 (50m 격자, '행:열')
create table explored (
  user_id uuid not null references auth.users on delete cascade,
  cell    text not null,
  at      timestamptz not null default now(),
  primary key (user_id, cell)
);

-- owned(스티커) / stamp(스탬프) / reward(보상) / store(방문 가게)
create table marks (
  user_id uuid not null references auth.users on delete cascade,
  kind    text not null,
  id      text not null,
  at      timestamptz not null default now(),
  primary key (user_id, kind, id)
);

create table coupons (
  id        uuid primary key default gen_random_uuid(),
  user_id   uuid not null references auth.users on delete cascade,
  store_id  text not null,
  title     text not null,
  issued_at timestamptz not null default now(),
  used_at   timestamptz
);

-- 이번 주 동네 리더보드 (밝힌 칸 수)
create view weekly_leaderboard as
  select p.area_name, p.nickname, p.character_id, count(e.cell) as cells
  from profiles p join explored e on e.user_id = p.user_id
  where e.at > now() - interval '7 days'
  group by p.area_name, p.nickname, p.character_id;

-- 행 단위 보안: 자기 데이터만 읽고 쓰기. 공유한 기록은 모두가 읽기.
alter table profiles enable row level security;
alter table walks    enable row level security;
alter table spots    enable row level security;
alter table explored enable row level security;
alter table marks    enable row level security;
alter table coupons  enable row level security;

create policy "본인" on profiles for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "닉네임 공개" on profiles for select using (true);
create policy "본인" on walks    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "본인" on spots    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "피드" on spots    for select using (shared and visibility = 'all');
create policy "본인" on explored for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "본인" on marks    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "본인" on coupons  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
