-- 골목대장: 아이디로 로그인하기 (2번째 수정)
-- Supabase 대시보드 → SQL Editor → New query 에 이 파일 전체를 붙여 넣고 Run.
-- 여러 번 실행해도 괜찮다.
--
-- Supabase 로그인은 원래 이메일로만 된다. 그래서
--   1) 회원가입할 때 아이디를 계정 정보(user metadata)에 같이 보내고
--   2) 계정이 만들어지면 아래 트리거가 accounts 표에 "아이디 → 계정"을 적어 두고
--   3) 로그인은 Edge Function(login-with-username)이 아이디로 계정을 찾아 대신 로그인해 준다.
-- 이메일 주소는 바깥으로 내보내지 않는다.

-- 아이디 표: 영어 소문자·숫자·밑줄 4~20자, 겹치면 안 됨
create table if not exists public.accounts (
  username   text primary key check (username ~ '^[a-z0-9_]{4,20}$'),
  user_id    uuid not null unique references auth.users on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.accounts enable row level security;
drop policy if exists "본인 아이디 보기" on public.accounts;
create policy "본인 아이디 보기" on public.accounts for select using (auth.uid() = user_id);

-- 새 계정이 생기면 metadata의 username을 accounts 에 넣는다
-- (아이디가 이미 있으면 여기서 오류가 나서 가입 자체가 취소된다)
create or replace function public.handle_new_user_username()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(new.raw_user_meta_data ->> 'username', '') <> '' then
    insert into public.accounts (username, user_id)
    values (lower(new.raw_user_meta_data ->> 'username'), new.id);
  end if;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_username on auth.users;
create trigger on_auth_user_created_username
  after insert on auth.users
  for each row execute function public.handle_new_user_username();

-- 회원가입 화면에서 아이디 중복 확인 (있는지 없는지만 알려 준다)
create or replace function public.username_taken(name text)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (select 1 from public.accounts where username = lower(name));
$$;
grant execute on function public.username_taken(text) to anon, authenticated;
