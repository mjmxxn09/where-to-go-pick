-- "여행 마치기"를 누른 때. null이면 진행 중.
alter table public.trips
  add column ended_at timestamptz;
