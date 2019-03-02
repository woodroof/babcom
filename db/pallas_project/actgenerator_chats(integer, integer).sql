-- drop function pallas_project.actgenerator_chats(integer, integer);

create or replace function pallas_project.actgenerator_chats(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
  v_actor_code text := data.get_object_code(in_actor_id);
  v_object_code text := data.get_object_code(in_object_id);
begin
  assert in_actor_id is not null;

  if (v_object_code = v_actor_code || '_chats' and pp_utils.is_in_group(in_actor_id, 'all_person')) 
    or pp_utils.is_in_group(in_actor_id, 'master') then
    v_actions_list := v_actions_list || 
      format(', "create_chat": {"code": "create_chat", "name": "Создать чат", "disabled": false, "params": {%s}}',
             case v_object_code when 'master_chats' then '"chat_is_master": true' else '' end
            );
  end if;
  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;
