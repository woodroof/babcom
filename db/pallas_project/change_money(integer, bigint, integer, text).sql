-- drop function pallas_project.change_money(integer, bigint, integer, text);

create or replace function pallas_project.change_money(in_object_id integer, in_new_value bigint, in_actor_id integer, in_reason text)
returns jsonb
volatile
as
$$
declare
  v_object_code text := data.get_object_code(in_object_id);
  v_diffs jsonb;
begin
  -- Изменяемые объекты: сам объект, его страница покупки статусов (для астеров и марсиан)
  v_diffs :=
    data.change_object(
      in_object_id,
      jsonb '[]' ||
      data.attribute_change2jsonb('system_money', to_jsonb(in_new_value)) ||
      data.attribute_change2jsonb('money', to_jsonb(in_new_value), in_object_id) ||
      data.attribute_change2jsonb('money', to_jsonb(in_new_value), 'master'),
      in_actor_id,
      in_reason);
  if data.is_object_exists(v_object_code || '_next_statuses') then
    v_diffs :=
      v_diffs ||
      data.change_object(
        data.get_object_id(v_object_code || '_next_statuses'),
        jsonb '[]' ||
        data.attribute_change2jsonb('money', to_jsonb(in_new_value)),
        in_actor_id,
        in_reason);
  end if;

  return v_diffs;
end;
$$
language plpgsql;
