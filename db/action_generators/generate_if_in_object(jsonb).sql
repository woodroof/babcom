-- Function: action_generators.generate_if_in_object(jsonb)

-- DROP FUNCTION action_generators.generate_if_in_object(jsonb);

CREATE OR REPLACE FUNCTION action_generators.generate_if_in_object(in_params jsonb)
  RETURNS jsonb AS
$BODY$
declare
  v_object_id integer := json.get_opt_integer(in_params, null, 'object_id');
  v_user_object_id integer;
  v_condition boolean;
  v_ret_val jsonb;
begin
  if v_object_id is null then
    return null;
  end if;

  v_user_object_id := json.get_integer(in_params, 'user_object_id');

  select true
  into v_condition
  where exists(
    select 1
    from data.object_objects
    where
      parent_object_id = v_object_id and
      object_id = v_user_object_id
  );

  if v_condition is null then
    return null;
  end if;

  execute format('select action_generators.%s($1)', json.get_string(in_params, 'function'))
  using
    json.get_opt_object(in_params, jsonb '{}', 'params') ||
    jsonb_build_object(
      'user_object_id', v_user_object_id,
      'object_id', v_object_id)
  into v_ret_val;

  return v_ret_val;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
