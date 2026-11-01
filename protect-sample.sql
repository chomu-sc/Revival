-- 기도와 말씀 · 미리보기 계정(sam@ple) 보호
-- Supabase 대시보드 > SQL Editor 에 이 내용을 붙여넣고 Run 하세요. 여러 번 실행해도 괜찮아요.

-- 1) 비밀번호와 이메일을 바꿀 수 없게
create or replace function public.protect_sample_account() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if lower(old.email) = 'sam@ple'
     and (new.encrypted_password is distinct from old.encrypted_password or new.email is distinct from old.email) then
    raise exception 'SAMPLE_ACCOUNT';
  end if;
  return new;
end $$;
revoke all on function public.protect_sample_account() from public, anon, authenticated;
create or replace trigger protect_sample_account before update on auth.users
for each row execute function public.protect_sample_account();

-- 2) 별명을 바꿀 수 없게 (관리자가 SQL로 바꾸는 건 가능)
create or replace function public.protect_sample_profile() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.nickname is distinct from old.nickname and auth.uid() = old.id
     and exists (select 1 from auth.users u where u.id = old.id and lower(u.email) = 'sam@ple') then
    raise exception 'SAMPLE_ACCOUNT';
  end if;
  return new;
end $$;
revoke all on function public.protect_sample_profile() from public, anon, authenticated;
create or replace trigger protect_sample_profile before update on public.profiles
for each row execute function public.protect_sample_profile();

-- 3) 앱에서 탈퇴할 수 없게
create or replace function public.delete_my_account(p_password text) returns void
language plpgsql security definer set search_path = public, extensions as $$
declare enc text; em text;
begin
  if auth.uid() is null then raise exception 'NOT_ALLOWED'; end if;
  if public.is_super_admin() then raise exception 'SUPER_ADMIN'; end if;
  select u.encrypted_password, u.email into enc, em from auth.users u where u.id = auth.uid();
  if lower(em) = 'sam@ple' then raise exception 'SAMPLE_ACCOUNT'; end if;
  if enc is null or enc = '' or extensions.crypt(coalesce(p_password, ''), enc) <> enc then
    raise exception 'BAD_PASSWORD';
  end if;
  delete from auth.users where id = auth.uid();
end $$;

-- 확인: 아래 결과에 protect_sample_account, protect_sample_profile 두 줄이 나오면 적용된 거예요
select tgname from pg_trigger where tgname like 'protect_sample%';
