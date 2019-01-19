-- drop function pallas_project.actgenerator_debatle_temp_person_list(integer, integer);

create or replace function pallas_project.actgenerator_debatle_temp_person_list(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
  v_person1_id integer;
  v_is_master boolean;
  v_debatle_code text;
  v_debatle_status text;
begin
  assert in_actor_id is not null;

  v_actions_list := v_actions_list || 
                ', "debatle_change_person_back": {"code": "go_back", "name": "Отмена", "disabled": false, '||
                '"params": {}}';

  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language 'plpgsql';
