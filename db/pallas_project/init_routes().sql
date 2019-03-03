-- drop function pallas_project.init_routes();

create or replace function pallas_project.init_routes()
returns void
volatile
as
$$
begin
  insert into data.attributes(code, name, type, card_type, can_be_overridden) values
  ('route_code', 'Код маршрута', 'normal', 'full', false),
  ('route_points', null, 'hidden', 'full', false);

  -- Классы для маршрутов
  perform data.create_class(
    'route_document',
    jsonb '{
      "type": "route_document",
      "is_visible": true,
      "template": {"title": "title", "subtitle": "subtitle", "groups": [{"code": "group", "attributes": ["description", "route_code"]}]}
    }');
  perform data.create_class(
    'route',
    jsonb '{
      "type": "route",
      "is_visible": true,
      "template": {"groups": []}
    }');

  perform pallas_project.create_route(
    'Маршрут',
    'TODO — Алмазная жила',
    'TODO описание',
    jsonb '[[1,1], [1,2], [2,2]]',
    array['2ce20542-04f1-418f-99eb-3c9d2665f733']);
  perform pallas_project.create_route(
    'Маршрут',
    'TODO — Теко Марс, склад 1',
    'TODO описание',
    jsonb '[[1,1], [1,2], [2,2]]',
    array['1fbcf296-e9ad-43b0-9064-1da3ff6d326d', '8f7b1cc6-28cd-4fb1-8c81-e0ab1c0df5c9', 'ea68988b-b540-4685-aefb-cbd999f4c9ba']);
  perform pallas_project.create_route(
    'Маршрут',
    'TODO — Теко Марс, склад 2',
    'TODO описание',
    jsonb '[[1,1], [1,2], [2,2]]',
    array['1fbcf296-e9ad-43b0-9064-1da3ff6d326d', '8f7b1cc6-28cd-4fb1-8c81-e0ab1c0df5c9', 'ea68988b-b540-4685-aefb-cbd999f4c9ba']);
  perform pallas_project.create_route(
    'Маршрут',
    'TODO — Картель, склад',
    'TODO описание',
    jsonb '[[1,1], [1,2], [2,2]]',
    array['0a0dc809-7bf1-41ee-bfe7-700fd26c1c0a', '1fbcf296-e9ad-43b0-9064-1da3ff6d326d']);
end;
$$
language plpgsql;
