-- 골목대장: 친구 + 스티커 보내기 (5번째 수정)
-- Supabase 대시보드 → SQL Editor → New query 에 이 파일 전체를 붙여 넣고 Run. 여러 번 실행해도 괜찮다.
--
-- 만드는 것
--   · friend_links : 친구 요청·친구 관계 (a가 b에게 요청, accepted = 수락됨)
--   · gifts        : 친구에게 보낸 스티커 기록 (정확한 위치·스티커·제목·메모·사진). 받는 사람이 받거나 거절하면 지운다.
--   · 저장소 gifts : 보낸 기록의 사진. "받는 사람 id/파일" 경로로 올린다. 받는 사람만(그리고 올린 사람) 볼 수 있다.
--   · spots.from_name : 친구에게 받은 기록이면 보낸 사람 닉네임
--
-- 지키는 것
--   · 친구 찾기는 아이디 또는 닉네임을 정확히 입력해야만 된다 (목록으로 훑어볼 수 없음)
--   · 다른 사람의 경로·좌표는 여전히 볼 수 없다. 내가 친구에게 직접 보낸 기록 한 곳만 그 친구에게 간다.
--   · 친구가 아니면 보낼 수 없다.

-- ── 친구 ──
create table if not exists public.friend_links (
  a          uuid not null references auth.users on delete cascade, -- 요청한 사람
  b          uuid not null references auth.users on delete cascade, -- 요청 받은 사람
  accepted   boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (a, b),
  check (a <> b)
);
create index if not exists friend_links_b on public.friend_links (b);

alter table public.friend_links enable row level security;
drop policy if exists "내 친구 관계 보기" on public.friend_links;
create policy "내 친구 관계 보기" on public.friend_links for select using (auth.uid() in (a, b));
-- 쓰기는 아래 함수로만 한다 (정책 없음 = 직접 쓰기 막힘)

create or replace function public.are_friends(x uuid, y uuid)
returns boolean
language sql security definer set search_path = public stable
as $$
  select exists (
    select 1 from public.friend_links
    where accepted and ((a = x and b = y) or (a = y and b = x))
  );
$$;
revoke all on function public.are_friends(uuid, uuid) from public, anon;
grant execute on function public.are_friends(uuid, uuid) to authenticated;

-- 아이디 또는 닉네임으로 한 사람 찾기 (정확히 같은 것만, 나는 빼고)
create or replace function public.find_friend(q text)
returns table (user_id uuid, nickname text, character_id text)
language sql security definer set search_path = public stable
as $$
  select p.user_id, p.nickname, p.character_id
  from public.profiles p
  left join public.accounts ac on ac.user_id = p.user_id
  where p.user_id <> auth.uid()
    and (ac.username = lower(trim(q)) or lower(p.nickname) = lower(trim(q)))
  limit 1;
$$;
revoke all on function public.find_friend(text) from public, anon;
grant execute on function public.find_friend(text) to authenticated;

-- 친구 요청. 돌려주는 값: sent(보냄) / accepted(상대가 먼저 요청해서 바로 친구) / already(이미 친구) / self / too_many
create or replace function public.request_friend(target uuid)
returns text
language plpgsql security definer set search_path = public
as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'login required'; end if;
  if target = me then return 'self'; end if;
  if public.are_friends(me, target) then return 'already'; end if;
  if exists (select 1 from public.friend_links where a = target and b = me) then
    update public.friend_links set accepted = true where a = target and b = me;
    return 'accepted';
  end if;
  if (select count(*) from public.friend_links where a = me and not accepted and created_at > now() - interval '1 day') >= 30 then
    return 'too_many';
  end if;
  insert into public.friend_links (a, b) values (me, target) on conflict do nothing;
  return 'sent';
end;
$$;
revoke all on function public.request_friend(uuid) from public, anon;
grant execute on function public.request_friend(uuid) to authenticated;

-- 받은 요청 수락(ok = true) / 거절(ok = false)
create or replace function public.answer_friend(other uuid, ok boolean)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if ok then
    update public.friend_links set accepted = true where a = other and b = auth.uid();
  else
    delete from public.friend_links where a = other and b = auth.uid() and not accepted;
  end if;
end;
$$;
revoke all on function public.answer_friend(uuid, boolean) from public, anon;
grant execute on function public.answer_friend(uuid, boolean) to authenticated;

-- 친구 끊기 / 보낸 요청 취소
create or replace function public.remove_friend(other uuid)
returns void
language sql security definer set search_path = public
as $$
  delete from public.friend_links
  where (a = auth.uid() and b = other) or (a = other and b = auth.uid());
$$;
revoke all on function public.remove_friend(uuid) from public, anon;
grant execute on function public.remove_friend(uuid) to authenticated;

-- 내 친구 목록. state: friend(친구) / sent(내가 보낸 요청) / received(받은 요청)
create or replace function public.my_friends()
returns table (user_id uuid, nickname text, character_id text, state text, since timestamptz)
language sql security definer set search_path = public stable
as $$
  select p.user_id, p.nickname, p.character_id,
         case when f.accepted then 'friend' when f.a = auth.uid() then 'sent' else 'received' end,
         f.created_at
  from public.friend_links f
  join public.profiles p on p.user_id = case when f.a = auth.uid() then f.b else f.a end
  where auth.uid() in (f.a, f.b)
  order by f.accepted, p.nickname;
$$;
revoke all on function public.my_friends() from public, anon;
grant execute on function public.my_friends() to authenticated;

-- ── 보낸 스티커 ──
create table if not exists public.gifts (
  id         uuid primary key default gen_random_uuid(),
  from_user  uuid not null default auth.uid() references auth.users on delete cascade,
  to_user    uuid not null references auth.users on delete cascade,
  lat        double precision not null check (lat between -90 and 90),
  lng        double precision not null check (lng between -180 and 180),
  sticker_id text not null check (char_length(sticker_id) <= 40),
  title      text not null check (char_length(title) <= 60),
  memo       text not null default '' check (char_length(memo) <= 1000),
  photo      text check (photo is null or photo like to_user::text || '/%'),
  made_at    timestamptz not null default now(),
  created_at timestamptz not null default now()
);
create index if not exists gifts_to_user on public.gifts (to_user, created_at);

alter table public.gifts enable row level security;
drop policy if exists "보낸 사람·받는 사람만 보기" on public.gifts;
drop policy if exists "친구에게만 보내기" on public.gifts;
drop policy if exists "보낸 사람·받는 사람만 지우기" on public.gifts;
create policy "보낸 사람·받는 사람만 보기" on public.gifts for select using (auth.uid() in (from_user, to_user));
create policy "친구에게만 보내기" on public.gifts for insert
  with check (from_user = auth.uid() and public.are_friends(from_user, to_user));
create policy "보낸 사람·받는 사람만 지우기" on public.gifts for delete using (auth.uid() in (from_user, to_user));

-- 나에게 온 스티커 + 보낸 사람 닉네임·캐릭터
create or replace function public.my_gifts()
returns table (id uuid, from_nickname text, from_character text, lat double precision, lng double precision,
               sticker_id text, title text, memo text, photo text, made_at timestamptz, created_at timestamptz)
language sql security definer set search_path = public stable
as $$
  select g.id, coalesce(p.nickname, '알 수 없음'), coalesce(p.character_id, 'a00'), g.lat, g.lng,
         g.sticker_id, g.title, g.memo, g.photo, g.made_at, g.created_at
  from public.gifts g
  left join public.profiles p on p.user_id = g.from_user
  where g.to_user = auth.uid()
  order by g.created_at;
$$;
revoke all on function public.my_gifts() from public, anon;
grant execute on function public.my_gifts() to authenticated;

-- ── 받은 기록 표시 ──
alter table public.spots add column if not exists from_name text;

-- ── 사진 저장소 ──
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('gifts', 'gifts', false, 10485760, array['image/png', 'image/jpeg'])
on conflict (id) do nothing;

-- 경로 첫 칸(받는 사람 id)이 내 친구인지
create or replace function public.gift_path_ok(path text)
returns boolean
language plpgsql security definer set search_path = public stable
as $$
begin
  return public.are_friends(auth.uid(), split_part(path, '/', 1)::uuid);
exception when others then
  return false;
end;
$$;
revoke all on function public.gift_path_ok(text) from public, anon;
grant execute on function public.gift_path_ok(text) to authenticated;

drop policy if exists "골목대장 선물 사진 올리기" on storage.objects;
drop policy if exists "골목대장 선물 사진 보기" on storage.objects;
drop policy if exists "골목대장 선물 사진 지우기" on storage.objects;
create policy "골목대장 선물 사진 올리기" on storage.objects for insert to authenticated
  with check (bucket_id = 'gifts' and public.gift_path_ok(name));
create policy "골목대장 선물 사진 보기" on storage.objects for select to authenticated
  using (bucket_id = 'gifts' and (split_part(name, '/', 1) = auth.uid()::text or owner_id = auth.uid()::text));
create policy "골목대장 선물 사진 지우기" on storage.objects for delete to authenticated
  using (bucket_id = 'gifts' and (split_part(name, '/', 1) = auth.uid()::text or owner_id = auth.uid()::text));
