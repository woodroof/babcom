-- Function: data.get_object_actions(integer, integer)

-- DROP FUNCTION data.get_object_actions(integer, integer);

CREATE OR REPLACE FUNCTION data.get_object_actions(
    in_user_object_id integer,
    in_object_id integer)
  RETURNS jsonb AS
$BODY$
declare
  v_generator_info record;
  v_base_params jsonb := jsonb_build_object('user_object_id', in_user_object_id, 'object_id', in_object_id);
  v_generator_actions jsonb;
  v_actions jsonb;
begin
  assert in_user_object_id is not null;

  for v_generator_info in
    select
      id,
      code,
      function,
      params
    from data.action_generators
  loop
    execute format('select action_generators.%s($1)', v_generator_info.function)
    using v_base_params || coalesce(v_generator_info.params, jsonb '{}')
    into v_generator_actions;

    if v_generator_actions is not null then
      v_generator_actions := data.fill_actions_checksum(v_generator_actions, in_user_object_id, v_generator_info.id, v_generator_info.code);
      v_actions := coalesce(v_actions, jsonb '{}') || v_generator_actions;
    end if;
  end loop;

  return v_actions;
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
