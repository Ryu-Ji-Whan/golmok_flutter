-- 골목대장: 리더보드를 "걸은 거리" 기준으로 (4번째 수정)
-- 003_area_leaderboard.sql 을 먼저 실행한 뒤, 이 파일 전체를 SQL Editor에 붙여 넣고 Run. 여러 번 실행해도 괜찮다.
--
-- 바뀌는 점
--   · 동네마다, 날짜마다 걸은 거리(m)를 쌓는다 (area_steps)
--   · 리더보드 순위 = 최근 7일 동안 그 동네에서 걸은 거리 (예전: 밝힌 칸 수)
--   · 날짜는 한국 시간 기준

create table if not exists public.area_steps (
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  area    text not null,
  day     date not null,
  meters  real not null default 0,
  primary key (user_id, area, day)
);
create index if not exists area_steps_area_day on public.area_steps (area, day);

alter table public.area_steps enable row level security;
drop policy if exists "본인" on public.area_steps;
create policy "본인" on public.area_steps for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- 앱이 걸은 만큼 더하기 (한 번에 최대 20km까지만 받는다)
create or replace function public.add_area_meters(area_name text, on_day date, add_m real)
returns void
language sql
security invoker
set search_path = public
as $$
  insert into public.area_steps (user_id, area, day, meters)
  values (auth.uid(), area_name, on_day, least(greatest(add_m, 0), 20000))
  on conflict (user_id, area, day)
  do update set meters = public.area_steps.meters + excluded.meters;
$$;
revoke all on function public.add_area_meters(text, date, real) from public, anon;
grant execute on function public.add_area_meters(text, date, real) to authenticated;

-- 돌려주는 칸이 바뀌므로 지우고 다시 만든다
drop function if exists public.area_leaderboard(text, int);
drop function if exists public.my_areas(int);

-- 한 동네의 순위: 최근 period_days일 동안 그 동네에서 걸은 거리
create function public.area_leaderboard(area_name text, period_days int default 7)
returns table (nickname text, character_id text, meters int, is_me boolean)
language sql
security definer
set search_path = public
stable
as $$
  select p.nickname, p.character_id, round(sum(s.meters))::int as meters, (p.user_id = auth.uid()) as is_me
  from public.area_steps s
  join public.profiles p on p.user_id = s.user_id
  where s.area = area_name
    and s.day > (now() at time zone 'Asia/Seoul')::date - period_days
    and (not p.hide_rank or p.user_id = auth.uid())
  group by p.user_id, p.nickname, p.character_id
  having sum(s.meters) >= 1
  order by meters desc
  limit 100;
$$;

-- 내가 최근 period_days일 동안 걸은 동네들과 동네마다 내 순위
create function public.my_areas(period_days int default 7)
returns table (area text, meters int, rank int, people int)
language sql
security definer
set search_path = public
stable
as $$
  with sums as (
    select s.area, s.user_id, round(sum(s.meters))::int as meters
    from public.area_steps s
    join public.profiles p on p.user_id = s.user_id
    where s.day > (now() at time zone 'Asia/Seoul')::date - period_days
      and (not p.hide_rank or s.user_id = auth.uid())
    group by s.area, s.user_id
    having sum(s.meters) >= 1
  ),
  ranked as (
    select area, user_id, meters,
           rank() over (partition by area order by meters desc)::int as rank,
           count(*) over (partition by area)::int as people
    from sums
  )
  select area, meters, rank, people
  from ranked
  where user_id = auth.uid()
  order by meters desc;
$$;

revoke all on function public.area_leaderboard(text, int) from public, anon;
revoke all on function public.my_areas(int) from public, anon;
grant execute on function public.area_leaderboard(text, int) to authenticated;
grant execute on function public.my_areas(int) to authenticated;
