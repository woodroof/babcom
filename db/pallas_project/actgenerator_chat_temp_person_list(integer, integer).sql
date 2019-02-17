-- drop function pallas_project.actgenerator_chat_temp_person_list(integer, integer);

create or replace function pallas_project.actgenerator_chat_temp_person_list(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
begin
  assert in_actor_id is not null;

  v_actions_list := v_actions_list || 
                ', "chat_add_person_back": {"code": "go_back", "name": "Назад к чату", "disabled": false, '||
                '"params": {}}';

  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;
