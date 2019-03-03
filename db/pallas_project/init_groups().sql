-- drop function pallas_project.init_groups();

create or replace function pallas_project.init_groups()
returns void
volatile
as
$$
begin
  -- Класс для группы
  perform data.create_class('group',
  jsonb '{
    "is_visible": true,
    "mini_card_template": {
      "title": "title",
      "groups": [{"code": "group_group1", "actions": ["debatle_add_audience_group", "debatle_del_audience_group"]}]
      }
    }');

  -- Группы персон
  perform data.create_object('all_person', jsonb '{"priority": 10, "title": "Все"}', 'group');
  perform data.create_object('player', jsonb '{"priority": 15, "title": "Все"}', 'group');
  perform data.create_object('aster', jsonb '{"priority": 20, "title": "Астеры"}', 'group');
  perform data.create_object('un', jsonb '{"priority": 30, "title": "Граждане ООН"}', 'group');
  perform data.create_object('mcr', jsonb '{"priority": 40, "title": "Марсиане"}', 'group');
  perform data.create_object('opa', jsonb '{"priority": 50, "title": "СВП"}', 'group');
  perform data.create_object('cartel', jsonb '{"priority": 60, "title": "Картель"}', 'group');
  perform data.create_object('rider', jsonb '{"priority": 70, "title": "Ридеры"}', 'group');
  perform data.create_object('master', jsonb '{"priority": 190, "title": "Мастера"}', 'group');

  perform data.create_object('judge', jsonb '{"priority": 75, "title": "Судьи"}', 'group');
  perform data.create_object('doctor', jsonb '{"priority": 76, "title": "Врачи"}', 'group');
  perform data.create_object('unofficial_doctor', jsonb '{"priority": 74, "title": "Неофициальные врачи"}', 'group');
  perform data.create_object('customs_officer', jsonb '{"priority": 72, "title": "Таможенники"}', 'group');

  perform data.create_object('miners', jsonb '{"priority": 77, "title": "Шахтёры"}', 'group');
  perform data.create_object('loaders', jsonb '{"priority": 78, "title": "Грузчики"}', 'group');
end;
$$
language plpgsql;
