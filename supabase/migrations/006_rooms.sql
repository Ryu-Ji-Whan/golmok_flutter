-- 골목대장: 친구 방 (6번째 수정)
-- Supabase 대시보드 → SQL Editor → New query 에 이 파일 전체를 붙여 넣고 Run. 여러 번 실행해도 괜찮다.
--
-- 만드는 것
--   · rooms        : 친구들끼리 만든 방 (이름, 6자리 초대 코드). 한 방에 최대 10명
--   · room_members : 방 사람 (member = 들어옴 / invited = 친구가 초대함, 수락 전). hide_route = 내 경로 숨기기
--   · room_spots   : 방에 올린 스티커 기록 (위치·스티커·제목·메모, 사진은 아직 안 감)
--
-- 지키는 것
--   · 방 사람끼리만 서로의 "오늘"(한국 시간 0시부터) 걸은 경로가 보인다. 방 밖 사람에게는 여전히 안 보인다.
--   · 방마다 "내 경로 숨기기"를 켜면 그 방 사람에게도 안 보인다.
--   · 방을 나가면 그 사람이 방에 올린 스티커도 지운다.
--   · 표는 직접 읽고 쓸 수 없고(정책 없음), 아래 함수로만 쓴다.

create table if not exists public.rooms (
  id         uuid primary key default gen_random_uuid(),
  name       text not null check (char_length(name) between 1 and 20),
  code       text not null unique,
  owner      uuid references auth.users on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.room_members (
  room_id    uuid not null references public.rooms on delete cascade,
  user_id    uuid not null references auth.users on delete cascade,
  state      text not null default 'member' check (state in ('member', 'invited')),
  hide_route boolean not null default false,
  invited_by uuid references auth.users on delete set null,
  joined_at  timestamptz not null default now(),
  primary key (room_id, user_id)
);
create index if not exists room_members_user on public.room_members (user_id);

create table if not exists public.room_spots (
  id         uuid primary key default gen_random_uuid(),
  room_id    uuid not null references public.rooms on delete cascade,
  user_id    uuid not null references auth.users on delete cascade,
  spot_id    text not null,
  lat        double precision not null,
  lng        double precision not null,
  sticker_id text not null,
  title      text not null check (char_length(title) <= 40),
  memo       text not null default '' check (char_length(memo) <= 500),
  created_at timestamptz not null default now(),
  unique (room_id, user_id, spot_id)
);
create index if not exists room_spots_room on public.room_spots (room_id);

alter table public.rooms enable row level security;
alter table public.room_members enable row level security;
alter table public.room_spots enable row level security;

-- 내가 이 방 사람인지
create or replace function public.in_room(r uuid)
returns boolean
language sql security definer set search_path = public stable
as $$
  select exists (select 1 from public.room_members where room_id = r and user_id = auth.uid() and state = 'member');
$$;
revoke all on function public.in_room(uuid) from public, anon;
grant execute on function public.in_room(uuid) to authenticated;

-- 방 만들기 → 방 id와 초대 코드
create or replace function public.create_room(p_name text)
returns table (id uuid, code text)
language plpgsql security definer set search_path = public
as $$
declare
  c text;
  rid uuid;
begin
  if auth.uid() is null then raise exception 'login required'; end if;
  if (select count(*) from public.room_members m where m.user_id = auth.uid() and m.state = 'member') >= 20 then
    raise exception 'too many rooms';
  end if;
  loop
    -- 헷갈리는 글자(0 O 1 I)는 뺀 6자리
    c := (select string_agg(substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', 1 + floor(random() * 32)::int, 1), '') from generate_series(1, 6));
    exit when not exists (select 1 from public.rooms r where r.code = c);
  end loop;
  insert into public.rooms (name, code, owner) values (trim(p_name), c, auth.uid()) returning rooms.id into rid;
  insert into public.room_members (room_id, user_id, state) values (rid, auth.uid(), 'member');
  return query select rid, c;
end;
$$;
revoke all on function public.create_room(text) from public, anon;
grant execute on function public.create_room(text) to authenticated;

-- 초대 코드로 들어가기. 돌려주는 값: ok / already / full / no_room
create or replace function public.join_room(p_code text)
returns text
language plpgsql security definer set search_path = public
as $$
declare
  rid uuid;
begin
  if auth.uid() is null then raise exception 'login required'; end if;
  select r.id into rid from public.rooms r where r.code = upper(trim(p_code));
  if rid is null then return 'no_room'; end if;
  if public.in_room(rid) then return 'already'; end if;
  if (select count(*) from public.room_members m where m.room_id = rid and m.state = 'member') >= 10 then return 'full'; end if;
  insert into public.room_members (room_id, user_id, state) values (rid, auth.uid(), 'member')
    on conflict (room_id, user_id) do update set state = 'member', joined_at = now();
  return 'ok';
end;
$$;
revoke all on function public.join_room(text) from public, anon;
grant execute on function public.join_room(text) to authenticated;

-- 친구를 방에 초대. 돌려주는 값: ok / already / full / not_friend
create or replace function public.invite_to_room(p_room uuid, p_friend uuid)
returns text
language plpgsql security definer set search_path = public
as $$
begin
  if not public.in_room(p_room) then raise exception 'not a member'; end if;
  if not public.are_friends(auth.uid(), p_friend) then return 'not_friend'; end if;
  if exists (select 1 from public.room_members m where m.room_id = p_room and m.user_id = p_friend) then return 'already'; end if;
  if (select count(*) from public.room_members m where m.room_id = p_room and m.state = 'member') >= 10 then return 'full'; end if;
  insert into public.room_members (room_id, user_id, state, invited_by) values (p_room, p_friend, 'invited', auth.uid());
  return 'ok';
end;
$$;
revoke all on function public.invite_to_room(uuid, uuid) from public, anon;
grant execute on function public.invite_to_room(uuid, uuid) to authenticated;

-- 초대 받기·거절. 돌려주는 값: ok / full / no_invite
create or replace function public.answer_room_invite(p_room uuid, p_accept boolean)
returns text
language plpgsql security definer set search_path = public
as $$
begin
  if not exists (select 1 from public.room_members m where m.room_id = p_room and m.user_id = auth.uid() and m.state = 'invited') then
    return 'no_invite';
  end if;
  if not p_accept then
    delete from public.room_members m where m.room_id = p_room and m.user_id = auth.uid();
    return 'ok';
  end if;
  if (select count(*) from public.room_members m where m.room_id = p_room and m.state = 'member') >= 10 then return 'full'; end if;
  update public.room_members m set state = 'member', joined_at = now() where m.room_id = p_room and m.user_id = auth.uid();
  return 'ok';
end;
$$;
revoke all on function public.answer_room_invite(uuid, boolean) from public, anon;
grant execute on function public.answer_room_invite(uuid, boolean) to authenticated;

-- 방 나가기 (내가 올린 스티커도 지움). 마지막 사람이 나가면 방도 지운다. 방장이 나가면 가장 먼저 들어온 사람이 방장
create or replace function public.leave_room(p_room uuid)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  delete from public.room_spots s where s.room_id = p_room and s.user_id = auth.uid();
  delete from public.room_members m where m.room_id = p_room and m.user_id = auth.uid();
  if not exists (select 1 from public.room_members m where m.room_id = p_room and m.state = 'member') then
    delete from public.rooms r where r.id = p_room;
  elsif (select r.owner from public.rooms r where r.id = p_room) = auth.uid() then
    update public.rooms r set owner = (
      select m.user_id from public.room_members m where m.room_id = p_room and m.state = 'member' order by m.joined_at limit 1
    ) where r.id = p_room;
  end if;
end;
$$;
revoke all on function public.leave_room(uuid) from public, anon;
grant execute on function public.leave_room(uuid) to authenticated;

-- 내 방 목록 (들어간 방 + 초대 받은 방)
create or replace function public.my_rooms()
returns table (id uuid, name text, code text, state text, members int, is_owner boolean, hide_route boolean, invited_by text)
language sql security definer set search_path = public stable
as $$
  select r.id, r.name,
         case when me.state = 'member' then r.code else '' end,
         me.state,
         (select count(*)::int from public.room_members x where x.room_id = r.id and x.state = 'member'),
         r.owner = auth.uid(),
         me.hide_route,
         coalesce((select p.nickname from public.profiles p where p.user_id = me.invited_by), '')
  from public.room_members me join public.rooms r on r.id = me.room_id
  where me.user_id = auth.uid()
  order by me.state = 'member', me.joined_at desc; -- 초대 받은 방이 먼저
$$;
revoke all on function public.my_rooms() from public, anon;
grant execute on function public.my_rooms() to authenticated;

-- 방 사람 목록
create or replace function public.room_people(p_room uuid)
returns table (user_id uuid, nickname text, character_id text, is_me boolean, hide_route boolean)
language sql security definer set search_path = public stable
as $$
  select m.user_id, coalesce(p.nickname, '알 수 없음'), coalesce(p.character_id, 'a00'), m.user_id = auth.uid(), m.hide_route
  from public.room_members m left join public.profiles p on p.user_id = m.user_id
  where m.room_id = p_room and m.state = 'member' and public.in_room(p_room)
  order by m.joined_at;
$$;
revoke all on function public.room_people(uuid) from public, anon;
grant execute on function public.room_people(uuid) to authenticated;

-- 방 사람들의 오늘(한국 시간) 산책 경로. 경로 숨기기를 켠 사람은 빠진다. 산책 하나가 한 줄
create or replace function public.room_today(p_room uuid)
returns table (user_id uuid, path jsonb, distance_m real)
language sql security definer set search_path = public stable
as $$
  select w.user_id, w.path, w.distance_m
  from public.room_members m join public.walks w on w.user_id = m.user_id
  where m.room_id = p_room and m.state = 'member' and not m.hide_route
    and public.in_room(p_room)
    and w.started_at >= (date_trunc('day', now() at time zone 'Asia/Seoul') at time zone 'Asia/Seoul')
  order by w.started_at;
$$;
revoke all on function public.room_today(uuid) from public, anon;
grant execute on function public.room_today(uuid) to authenticated;

-- 이 방에서 내 경로 숨기기
create or replace function public.set_room_route_hidden(p_room uuid, p_hide boolean)
returns void
language sql security definer set search_path = public
as $$
  update public.room_members m set hide_route = p_hide where m.room_id = p_room and m.user_id = auth.uid();
$$;
revoke all on function public.set_room_route_hidden(uuid, boolean) from public, anon;
grant execute on function public.set_room_route_hidden(uuid, boolean) to authenticated;

-- 방에 내 스티커 기록 올리기 (같은 기록을 다시 올리면 고친 내용으로 바뀜)
create or replace function public.share_to_room(p_room uuid, p_spot text, p_lat double precision, p_lng double precision,
                                                p_sticker text, p_title text, p_memo text)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not public.in_room(p_room) then raise exception 'not a member'; end if;
  if (select count(*) from public.room_spots s where s.room_id = p_room) >= 500 then raise exception 'room full of stickers'; end if;
  insert into public.room_spots (room_id, user_id, spot_id, lat, lng, sticker_id, title, memo)
  values (p_room, auth.uid(), p_spot, p_lat, p_lng, p_sticker, left(p_title, 40), left(coalesce(p_memo, ''), 500))
  on conflict (room_id, user_id, spot_id) do update
    set lat = excluded.lat, lng = excluded.lng, sticker_id = excluded.sticker_id, title = excluded.title, memo = excluded.memo;
end;
$$;
revoke all on function public.share_to_room(uuid, text, double precision, double precision, text, text, text) from public, anon;
grant execute on function public.share_to_room(uuid, text, double precision, double precision, text, text, text) to authenticated;

-- 방에서 내가 올린 스티커 내리기
create or replace function public.unshare_room_spot(p_id uuid)
returns void
language sql security definer set search_path = public
as $$
  delete from public.room_spots s where s.id = p_id and s.user_id = auth.uid();
$$;
revoke all on function public.unshare_room_spot(uuid) from public, anon;
grant execute on function public.unshare_room_spot(uuid) to authenticated;

-- 방에 올라온 스티커 목록
create or replace function public.room_stickers(p_room uuid)
returns table (id uuid, user_id uuid, spot_id text, nickname text, character_id text, lat double precision, lng double precision,
               sticker_id text, title text, memo text, created_at timestamptz, is_mine boolean)
language sql security definer set search_path = public stable
as $$
  select s.id, s.user_id, s.spot_id, coalesce(p.nickname, '알 수 없음'), coalesce(p.character_id, 'a00'), s.lat, s.lng,
         s.sticker_id, s.title, s.memo, s.created_at, s.user_id = auth.uid()
  from public.room_spots s left join public.profiles p on p.user_id = s.user_id
  where s.room_id = p_room and public.in_room(p_room)
  order by s.created_at desc;
$$;
revoke all on function public.room_stickers(uuid) from public, anon;
grant execute on function public.room_stickers(uuid) to authenticated;
