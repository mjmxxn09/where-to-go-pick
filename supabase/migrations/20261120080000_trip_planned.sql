-- 여행마다 "가볼 곳" 목록. [{id, name, type, meta}] 담은 순서대로.
alter table public.trips
  add column planned jsonb not null default '[]'::jsonb;

alter table public.trips
  add constraint trips_planned_size check (pg_column_size(planned) < 100000);
