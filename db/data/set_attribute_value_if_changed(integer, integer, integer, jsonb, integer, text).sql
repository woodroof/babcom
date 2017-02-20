-- Function: data.set_attribute_value_if_changed(integer, integer, integer, jsonb, integer, text)

-- DROP FUNCTION data.set_attribute_value_if_changed(integer, integer, integer, jsonb, integer, text);

CREATE OR REPLACE FUNCTION data.set_attribute_value_if_changed(
    in_object_id integer,
    in_attribute_id integer,
    in_value_object_id integer,
    in_value jsonb,
    in_user_object_id integer DEFAULT NULL::integer,
    in_reason text DEFAULT NULL::text)
  RETURNS void AS
$BODY$
declare
  v_attribute_value_info record;
  v_change_function_info record;
  v_inserted boolean := false;
begin
  assert in_object_id is not null;
  assert in_attribute_id is not null;

  if in_value_object_id is null then
    select id, value, start_time, start_reason, start_object_id
    into v_attribute_value_info
    from data.attribute_values
    where
      object_id = in_object_id and
      attribute_id = in_attribute_id and
      value_object_id is null
    for update;
  else
    select id, value, start_time, start_reason, start_object_id
    into v_attribute_value_info
    from data.attribute_values
    where
      object_id = in_object_id and
      attribute_id = in_attribute_id and
      value_object_id = in_value_object_id
    for update;
  end if;

  loop
    if v_inserted or not v_attribute_value_info is null then
      exit;
    end if;

    begin
      insert into data.attribute_values(
        object_id,
        attribute_id,
        value_object_id,
        value,
        start_time,
        start_reason,
        start_object_id)
      values (
        in_object_id,
        in_attribute_id,
        in_value_object_id,
        in_value,
        now(),
        in_reason,
        in_user_object_id);

      v_inserted := true;
    exception when unique_violation then
      if in_value_object_id is null then
        select id, value, start_time, start_reason, start_object_id
        into v_attribute_value_info
        from data.attribute_values
        where
          object_id = in_object_id and
          attribute_id = in_attribute_id and
          value_object_id is null
        for update;
      else
        select id, value, start_time, start_reason, start_object_id
        into v_attribute_value_info
        from data.attribute_values
        where
          object_id = in_object_id and
          attribute_id = in_attribute_id and
          value_object_id = in_value_object_id
        for update;
      end if;
    end;
  end loop;

  if not v_inserted then
    if
      (v_attribute_value_info.value is null and in_value is null) or
      v_attribute_value_info.value = in_value
    then
      return;
    end if;

    insert into data.attribute_values_journal(
      object_id,
      attribute_id,
      value_object_id,
      value,
      start_time,
      start_reason,
      start_object_id,
      end_time,
      end_reason,
      end_object_id)
    values (
      in_object_id,
      in_attribute_id,
      in_value_object_id,
      v_attribute_value_info.value,
      v_attribute_value_info.start_time,
      v_attribute_value_info.start_reason,
      v_attribute_value_info.start_object_id,
      now(),
      in_reason,
      in_user_object_id);

    update data.attribute_values
    set
      value = in_value,
      start_time = now(),
      start_reason = in_reason,
      start_object_id = in_user_object_id
    where id = v_attribute_value_info.id;
  end if;

  for v_change_function_info in
    select
      function,
      params
    from data.attribute_value_change_functions
    where attribute_id = in_attribute_id
  loop
    execute format('select attribute_value_change_functions.%s($1)', v_change_function_info.function)
    using
      coalesce(v_change_function_info.params, jsonb '{}') ||
      jsonb_build_object(
        'user_object_id', in_user_object_id,
        'object_id', in_object_id,
        'attribute_id', in_attribute_id,
        'value_object_id', in_value_object_id,
        'old_value', v_attribute_value_info.value,
        'new_value', in_value);
  end loop;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
