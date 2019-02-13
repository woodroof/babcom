-- drop function pallas_project.change_coins(integer, integer, integer, text);

create or replace function pallas_project.change_coins(in_object_id integer, in_new_value integer, in_actor_id integer, in_reason text)
returns jsonb
volatile
as
$$
declare
  v_object_code text := data.get_object_code(in_object_id);
  v_diffs jsonb;
begin
  -- Изменяемые объекты: сам объект, его страница покупки статусов
  v_diffs :=
    data.change_object(
      in_object_id,
      jsonb '[]' ||
      data.attribute_change2jsonb('system_person_coin', to_jsonb(in_new_value)) ||
      data.attribute_change2jsonb('person_coin', to_jsonb(in_new_value), in_object_id) ||
      data.attribute_change2jsonb('person_coin', to_jsonb(in_new_value), 'master'),
      in_actor_id,
      in_reason);
  v_diffs :=
    v_diffs ||
    data.change_object(
      data.get_object_id(v_object_code || '_next_statuses'),
      jsonb '[]' ||
      data.attribute_change2jsonb('person_coin', to_jsonb(in_new_value)),
      in_actor_id,
      in_reason);

  return v_diffs;
end;
$$
language plpgsql;
