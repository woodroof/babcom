-- Function: action_generators.generate_if_string_attribute(jsonb)

-- DROP FUNCTION action_generators.generate_if_string_attribute(jsonb);

CREATE OR REPLACE FUNCTION action_generators.generate_if_string_attribute(in_params jsonb)
  RETURNS jsonb AS
$BODY$
declare
  v_object_id integer := json.get_opt_integer(in_params, null, 'object_id');

  v_check_attribute_code text;
  v_check_attribute_id integer;

  v_user_object_id integer;

  v_attributes jsonb;
  v_attribute_info record;

  v_attribute_value jsonb;
  v_attribute_block jsonb;

  v_function_block jsonb;

  v_function text;
  v_params jsonb;

  v_next_val jsonb;
  v_ret_val jsonb;
begin
  if v_object_id is null then
    return null;
  end if;

  v_user_object_id := json.get_integer(in_params, 'user_object_id');
  v_attributes := json.get_object(in_params, 'attributes');

  for v_attribute_info in
    select key, value
    from jsonb_each(v_attributes)
  loop
    v_attribute_value := data.get_raw_attribute_value(v_object_id, data.get_attribute_id(v_attribute_info.key), null);

    if v_attribute_value is not null then
      v_attribute_block := json.get_opt_object_array(v_attribute_info.value, null, json.get_string(v_attribute_value));

      if v_attribute_block is not null then
        for v_function_block in
          select value
          from jsonb_array_elements(v_attribute_block)
        loop
          v_function := json.get_string(v_function_block, 'function');
          v_params :=
            json.get_opt_object(v_function_block, jsonb '{}', 'params') ||
            jsonb_build_object(
              'user_object_id', v_user_object_id,
              'object_id', v_object_id);

          execute format('select action_generators.%s($1)', v_function)
          using v_params
          into v_next_val;

          if v_next_val is not null then
            v_ret_val := coalesce(v_ret_val, jsonb '{}') || v_next_val;
          end if;
        end loop;
      end if;
    end if;
  end loop;

  return v_ret_val;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
