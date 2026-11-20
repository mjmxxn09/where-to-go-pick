-- 여행을 만들 때 정한 기간(일 수). 1 = 당일, 3 = 2박 3일. null이면 정하지 않음.
alter table public.trips
  add column planned_days smallint
    check (planned_days is null or planned_days between 1 and 30);
