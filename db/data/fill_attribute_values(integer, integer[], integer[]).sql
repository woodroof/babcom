-- Function: data.fill_attribute_values(integer, integer[], integer[])

-- DROP FUNCTION data.fill_attribute_values(integer, integer[], integer[]);

CREATE OR REPLACE FUNCTION data.fill_attribute_values(
    in_user_object_id integer,
    in_object_ids integer[],
    in_attribute_ids integer[])
  RETURNS void AS
$BODY$
declare
  v_object_count integer;
  v_function_info record;
  v_object_id integer;
begin
  assert in_user_object_id is not null;
  assert in_object_ids is not null;
  assert in_attribute_ids is not null;

  in_object_ids := intarray.uniq(intarray.sort(in_object_ids));

  select count(1)
  into v_object_count
  from data.objects
  where id = any(in_object_ids);

  if v_object_count != array_length(in_object_ids, 1) then
    raise exception 'Can''t fill attributes for unknown object';
  end if;

  for v_function_info in
    select attribute_id, function, params
    from data.attribute_value_fill_functions
    where attribute_id = any(in_attribute_ids)
  loop
    foreach v_object_id in array in_object_ids loop
      assert v_object_id is not null;

      execute 'select attribute_value_fill_functions.' || v_function_info.function || '($1)'
      using
        coalesce(v_function_info.params, jsonb '{}') ||
        jsonb_build_object('user_object_id', in_user_object_id, 'object_id', v_object_id, 'attribute_id', v_function_info.attribute_id);
    end loop;
  end loop;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
