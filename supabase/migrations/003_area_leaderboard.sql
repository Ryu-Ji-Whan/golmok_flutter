-- 골목대장: 걸은 동네 기준 리더보드 (3번째 수정)
-- Supabase 대시보드 → SQL Editor → New query 에 이 파일 전체를 붙여 넣고 Run. 여러 번 실행해도 괜찮다.
--
-- 바뀌는 점
--   · 밝힌 칸(explored)마다 "그 칸을 밝힐 때 있던 동네" 이름을 같이 저장한다 (area)
--   · 리더보드는 사람의 '내 동네'가 아니라, 그 동네에서 실제로 밝힌 칸 수로 순위를 낸다
--   · 리더보드에 내 이름 숨기기 (profiles.hide_rank)
--   · 예전 리더보드 뷰(weekly_leaderboard)는 지우고, 필요한 것만 돌려주는 함수 두 개로 바꾼다

alter table public.explored add column if not exists area text;
create index if not exists explored_area_at on public.explored (area, at);

alter table public.profiles add column if not exists hide_rank boolean not null default false;

drop view if exists public.weekly_leaderboard;

-- 한 동네의 순위: 최근 period_days일 동안 그 동네에서 새로 밝힌 칸 수
-- 숨기기를 켠 사람은 빠진다 (나 자신은 내 화면에서만 보인다)
create or replace function public.area_leaderboard(area_name text, period_days int default 7)
returns table (nickname text, character_id text, cells int, is_me boolean)
language sql
security definer
set search_path = public
stable
as $$
  select p.nickname, p.character_id, count(*)::int as cells, (p.user_id = auth.uid()) as is_me
  from public.explored e
  join public.profiles p on p.user_id = e.user_id
  where e.area = area_name
    and e.at > now() - make_interval(days => period_days)
    and (not p.hide_rank or p.user_id = auth.uid())
  group by p.user_id, p.nickname, p.character_id
  order by cells desc
  limit 100;
$$;

-- 내가 최근 period_days일 동안 걸은 동네들과 동네마다 내 순위
create or replace function public.my_areas(period_days int default 7)
returns table (area text, cells int, rank int, people int)
language sql
security definer
set search_path = public
stable
as $$
  with counts as (
    select e.area, e.user_id, count(*)::int as cells
    from public.explored e
    join public.profiles p on p.user_id = e.user_id
    where e.area is not null
      and e.at > now() - make_interval(days => period_days)
      and (not p.hide_rank or e.user_id = auth.uid())
    group by e.area, e.user_id
  ),
  ranked as (
    select area, user_id, cells,
           rank() over (partition by area order by cells desc)::int as rank,
           count(*) over (partition by area)::int as people
    from counts
  )
  select area, cells, rank, people
  from ranked
  where user_id = auth.uid()
  order by cells desc;
$$;

-- 로그인한 사람만
revoke all on function public.area_leaderboard(text, int) from public, anon;
revoke all on function public.my_areas(int) from public, anon;
grant execute on function public.area_leaderboard(text, int) to authenticated;
grant execute on function public.my_areas(int) to authenticated;
