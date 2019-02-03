-- drop function pallas_project.actgenerator_chats(integer, integer);

create or replace function pallas_project.actgenerator_chats(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
begin
  assert in_actor_id is not null;

  if pp_utils.is_in_group(in_actor_id, 'all_person') or pp_utils.is_in_group(in_actor_id, 'master') then
    v_actions_list := v_actions_list || 
      ', "create_chat": {"code": "create_chat", "name": "Создать чат", "disabled": false, '||
      '"params": {}}';
  end if;
  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;
