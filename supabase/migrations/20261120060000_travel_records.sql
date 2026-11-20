-- 여행 기록: 여행, 체크인, 여행 카드 꾸미기.
--
-- 사용자 구분은 토큰의 sub 값(문자열)으로 한다.
--   - 픽클 계정:  'pickle:<subjectId>'  (Edge Function pickle-exchange가 발급)
--   - 게스트(개발용 익명 로그인): Supabase Auth의 사용자 UUID
-- auth.uid()는 sub를 uuid로 바꾸려다 실패하므로 쓰지 않고 auth.jwt()->>'sub'를 쓴다.

create or replace function public.current_owner() returns text
  language sql stable
  set search_path = ''
as $$ select nullif(auth.jwt() ->> 'sub', '') $$;

create or replace function public.touch_updated_at() returns trigger
  language plpgsql
  set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ------------------------------------------------------------------ 여행

create table public.trips (
  user_id       text        not null default public.current_owner(),
  id            text        not null,
  city_id       text        not null,
  city_name     text        not null,
  province_name text        not null,
  start_date    date        not null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  primary key (user_id, id),
  constraint trips_id_len check (char_length(id) between 1 and 80)
);

-- ------------------------------------------------------------------ 체크인

create table public.check_ins (
  user_id       text        not null default public.current_owner(),
  trip_id       text        not null,
  id            text        not null,          -- 장소 id(한 여행에서 같은 장소는 한 번)
  place_name    text        not null,
  place_type    text        not null,          -- PlaceType 이름(beach, cafe …)
  checked_in_at timestamptz not null,
  updated_at    timestamptz not null default now(),
  primary key (user_id, trip_id, id),
  foreign key (user_id, trip_id) references public.trips (user_id, id) on delete cascade
);

-- ------------------------------------------------------------------ 여행 카드 꾸미기

-- page_key는 앱의 cardPageKey(여행·보기 방식·쪽) 값. 스티커와 옮긴 장소 막대를 JSON 그대로 둔다.
create table public.card_decorations (
  user_id    text        not null default public.current_owner(),
  page_key   text        not null,
  stickers   jsonb       not null default '[]'::jsonb,
  stop_edits jsonb       not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (user_id, page_key),
  constraint card_decorations_size check (pg_column_size(stickers) + pg_column_size(stop_edits) < 200000)
);

create trigger trips_touch before update on public.trips
  for each row execute function public.touch_updated_at();
create trigger check_ins_touch before update on public.check_ins
  for each row execute function public.touch_updated_at();
create trigger card_decorations_touch before update on public.card_decorations
  for each row execute function public.touch_updated_at();

-- ------------------------------------------------------------------ 권한: 내 것만

alter table public.trips            enable row level security;
alter table public.check_ins        enable row level security;
alter table public.card_decorations enable row level security;

create policy "own trips" on public.trips
  for all to authenticated
  using (user_id = (select public.current_owner()))
  with check (user_id = (select public.current_owner()));

create policy "own check-ins" on public.check_ins
  for all to authenticated
  using (user_id = (select public.current_owner()))
  with check (user_id = (select public.current_owner()));

create policy "own card decorations" on public.card_decorations
  for all to authenticated
  using (user_id = (select public.current_owner()))
  with check (user_id = (select public.current_owner()));

-- 새 테이블 자동 공개를 꺼 두었으므로 필요한 권한만 직접 연다. anon(로그인 안 함)에는 아무것도 주지 않는다.
grant select, insert, update, delete on public.trips            to authenticated;
grant select, insert, update, delete on public.check_ins        to authenticated;
grant select, insert, update, delete on public.card_decorations to authenticated;
grant execute on function public.current_owner() to authenticated;
revoke all on function public.current_owner() from anon, public;
