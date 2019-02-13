-- drop function pallas_project.change_next_status(integer, text, integer, integer, text);

create or replace function pallas_project.change_next_status(in_object_id integer, in_status_name text, in_new_value integer, in_actor_id integer, in_reason text)
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
      data.attribute_change2jsonb('system_person_next_' || in_status_name || '_status', to_jsonb(in_new_value)),
      in_actor_id,
      in_reason);
  v_diffs :=
    v_diffs ||
    data.change_object(
      data.get_object_id(v_object_code || '_next_statuses'),
      jsonb '[]' ||
      data.attribute_change2jsonb(in_status_name || '_next_status', to_jsonb(in_new_value)),
      in_actor_id,
      in_reason);

  return v_diffs;
end;
$$
language plpgsql;
