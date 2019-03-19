-- drop function pallas_project.update_person_list();

create or replace function pallas_project.update_person_list()
returns void
volatile
as
$$
declare
  v_list jsonb;
  v_master_list jsonb;
begin
  -- Список для игроков
  select jsonb_agg(o.code order by data.get_attribute_value(o.id, 'title'))
  into v_list
  from data.object_objects oo
  join data.objects o on
    o.id = oo.object_id
  where
    oo.parent_object_id = data.get_object_id('player') and
    oo.object_id != oo.parent_object_id;

  -- Список для мастеров
  select jsonb_agg(o.code order by data.get_attribute_value(o.id, 'title'))
  into v_master_list
  from data.object_objects oo
  join data.objects o on
    o.id = oo.object_id
  where
    oo.parent_object_id = data.get_object_id('all_person') and
    oo.object_id != oo.parent_object_id;

  -- Создаём объект
  perform data.change_object_and_notify(
    data.get_object_id('persons'),
    jsonb '[]' ||
    data.attribute_change2jsonb('content', v_list) ||
    data.attribute_change2jsonb('content', v_master_list, 'master'));
end;
$$
language plpgsql;
