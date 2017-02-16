-- Function: user_api.make_action(text, integer, jsonb)

-- DROP FUNCTION user_api.make_action(text, integer, jsonb);

CREATE OR REPLACE FUNCTION user_api.make_action(
    in_client text,
    in_login_id integer,
    in_params jsonb)
  RETURNS api.result AS
$BODY$
declare
  v_user_object_id integer := api_utils.get_user_object(in_login_id, in_params);
  v_action_code text;
  v_params jsonb;
  v_user_params jsonb;

  v_generator integer;
  v_checksum text;

  v_generator_code text;

  v_ret_val api.result;
begin
  if v_user_object_id is null then
    return api_utils.create_forbidden_result('Invalid user object');
  end if;

  v_action_code := json.get_string(in_params, 'action_code');
  v_params := json.get_object(in_params, 'params');
  v_user_params := json.get_opt_object(in_params, null, 'user_params');

  v_generator := json.get_integer(v_params, 'generator');
  v_checksum := json.get_string(v_params, 'checksum');

  select code
  into v_generator_code
  from data.action_generators
  where id = v_generator;

  v_params := v_params - 'generator' - 'checksum';

  if v_generator_code is null then
    return api_utils.create_conflict_result('Invalid action generator');
  elsif v_checksum != data.create_checksum(v_user_object_id, v_generator_code, v_action_code, v_params) then
    return api_utils.create_conflict_result('Invalid checksum');
  end if;

  execute format('select * from actions.%s($1, $2, $3, $4)', v_action_code)
  using in_client, v_user_object_id, v_params, v_user_params
  into v_ret_val;

  return v_ret_val;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
