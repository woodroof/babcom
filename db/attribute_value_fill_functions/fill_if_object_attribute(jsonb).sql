-- Function: attribute_value_fill_functions.fill_if_object_attribute(jsonb)

-- DROP FUNCTION attribute_value_fill_functions.fill_if_object_attribute(jsonb);

CREATE OR REPLACE FUNCTION attribute_value_fill_functions.fill_if_object_attribute(in_params jsonb)
  RETURNS void AS
$BODY$
declare
  v_object_id integer := json.get_integer(in_params, 'object_id');

  v_blocks jsonb := json.get_object_array(in_params, 'blocks');
  v_block jsonb;
  v_conditions jsonb;
  v_condition jsonb;

  v_check_attribute_id integer;
  v_check_attribute_value jsonb;
  v_checked boolean;

  v_function text;
  v_params jsonb;
begin
  for v_block in
    select value
    from jsonb_array_elements(v_blocks)
  loop
    v_conditions := json.get_opt_object_array(v_block, null, 'conditions');

    if v_conditions is null then
      v_checked := true;
    else
      for v_condition in
        select value
        from jsonb_array_elements(v_conditions)
      loop
        v_check_attribute_id := data.get_attribute_id(json.get_string(v_condition, 'attribute_code'));
        v_check_attribute_value := v_condition->'attribute_value';

        select true
        into v_checked
        from data.attribute_values
        where
          object_id = v_object_id and
          attribute_id = v_check_attribute_id and
          value_object_id is null and
          value = v_check_attribute_value;

        if v_checked is not null then
          exit;
        end if;
      end loop;
    end if;

    if v_checked is not null then
      v_function := json.get_string(v_block, 'function');
      v_params :=
        json.get_opt_object(v_block, jsonb '{}', 'params') ||
        jsonb_build_object(
          'user_object_id', json.get_integer(in_params, 'user_object_id'),
          'object_id', v_object_id,
          'attribute_id', json.get_integer(in_params, 'attribute_id'));

      execute format('select attribute_value_fill_functions.%s($1)', v_function)
      using v_params;

      return;
    end if;
  end loop;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
