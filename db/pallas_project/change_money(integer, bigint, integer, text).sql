-- drop function pallas_project.change_money(integer, bigint, integer, text);

create or replace function pallas_project.change_money(in_object_id integer, in_new_value bigint, in_actor_id integer, in_reason text)
returns jsonb
volatile
as
$$
declare
  v_object_code text := data.get_object_code(in_object_id);
  v_changes jsonb :=
    jsonb '[]' ||
    data.attribute_change2jsonb('system_money', to_jsonb(in_new_value));
  v_money_attr_id integer := data.get_attribute_id('money');
  v_value_object_id integer;
  v_diffs jsonb;
begin
  -- Изменяемые объекты: сам объект, его страница покупки статусов (для астеров и марсиан)
  for v_value_object_id in
  (
    select value_object_id
    from data.attribute_values
    where
      object_id = in_object_id and
      attribute_id = v_money_attr_id and
      value_object_id is not null
  )
  loop
    v_changes := v_changes || data.attribute_change2jsonb(v_money_attr_id, to_jsonb(in_new_value), v_value_object_id);
  end loop;

  v_diffs :=
    data.change_object(
      in_object_id,
      v_changes,
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
