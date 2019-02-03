-- drop function pallas_project.actgenerator_anonymous(integer, integer);

create or replace function pallas_project.actgenerator_anonymous(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_object_code text := data.get_object_code(in_object_id);
  v_actions_list text := '';
begin
  assert in_actor_id is not null;

  /*v_actions_list := v_actions_list || ', "' || 'create_random_person":' || 
    '{"code": "create_random_person", "name": "Нажми меня", "disabled": false, "params": {}}';*/
  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;
