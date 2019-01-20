-- drop function pallas_project.actgenerator_menu(integer, integer);

create or replace function pallas_project.actgenerator_menu(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_object_code text := data.get_object_code(in_object_id);
  v_actions_list text := '';
begin
  assert in_actor_id is not null;

  if data.get_object_code(in_actor_id) = 'anonymous' then
    v_actions_list := v_actions_list || ', "' || 'login":' || 
      '{"code": "login", "name": "Войти", "disabled": false, "params": {}, "user_params": [{"code": "password", "description": "Введите пароль", "type": "string" }]}';
  else
    if pallas_project.is_in_group(in_actor_id, 'all_person') then
      v_actions_list := v_actions_list || ', "' || 'debatles":' || 
        '{"code": "act_open_object", "name": "Дебатлы", "disabled": false, "params": {"object_code": "debatles"}}';
      v_actions_list := v_actions_list || ', "' || 'logout":' || 
        '{"code": "logout", "name": "Выход", "disabled": false, "params": {}}';
    end if;
  end if;

  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;
