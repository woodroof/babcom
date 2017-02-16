-- Function: data.fill_actions_checksum(jsonb, integer, integer, text)

-- DROP FUNCTION data.fill_actions_checksum(jsonb, integer, integer, text);

CREATE OR REPLACE FUNCTION data.fill_actions_checksum(
    in_actions jsonb,
    in_user_object_id integer,
    in_generator_id integer,
    in_generator_code text)
  RETURNS jsonb AS
$BODY$
declare
  v_action record;
  v_ret_val jsonb := jsonb '{}';
begin
  assert in_actions is not null;
  assert in_user_object_id is not null;
  assert in_generator_id is not null;
  assert in_generator_code is not null;

  for v_action in
    select *
    from jsonb_each(in_actions)
  loop
    v_ret_val :=
      v_ret_val ||
      jsonb_build_object(
        v_action.key,
        v_action.value ||
        jsonb_build_object(
          'params',
          coalesce(json.get_opt_object(v_action.value, null, 'params'), jsonb '{}') ||
          jsonb_build_object(
            'generator',
            in_generator_id,
            'checksum',
            data.create_checksum(in_user_object_id, in_generator_code, json.get_string(v_action.value, 'code'), json.get_opt_object(v_action.value, null, 'params')))));
  end loop;

  return v_ret_val;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
