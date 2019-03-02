-- drop function pallas_project.init_routes();

create or replace function pallas_project.init_routes()
returns void
volatile
as
$$
begin
  -- todo
  -- маршрут до алмазной жилы 2ce20542-04f1-418f-99eb-3c9d2665f733
  -- Карта со складами Теко Марс (два маршрута) 1fbcf296-e9ad-43b0-9064-1da3ff6d326d 8f7b1cc6-28cd-4fb1-8c81-e0ab1c0df5c9 ea68988b-b540-4685-aefb-cbd999f4c9ba
  -- путь к складу картеля 0a0dc809-7bf1-41ee-bfe7-700fd26c1c0a 1fbcf296-e9ad-43b0-9064-1da3ff6d326d
end;
$$
language plpgsql;
