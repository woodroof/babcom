-- drop function pallas_project.actgenerator_menu(integer, integer);

create or replace function pallas_project.actgenerator_menu(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_object_code text := data.get_object_code(in_object_id);
  v_actions jsonb := '{}';
  v_is_master boolean := pp_utils.is_in_group(in_actor_id, 'master');
begin
  assert in_actor_id is not null;

  if data.get_object_code(in_actor_id) = 'anonymous' then
    v_actions :=
      v_actions ||
      jsonb '{"login": {"code": "login", "name": "Войти", "disabled": false, "params": {}, "user_params": [{"code": "password", "description": "Введите пароль", "type": "string", "restrictions": {"password": true}}]}}';
  else
    if v_is_master or pp_utils.is_in_group(in_actor_id, 'all_person') then
      v_actions :=
        v_actions ||
        jsonb '{
          "statuses": {"code": "act_open_object", "name": "Статусы", "disabled": false, "params": {"object_code": "statuses"}},
          "debatles": {"code": "act_open_object", "name": "Дебатлы", "disabled": false, "params": {"object_code": "debatles"}},
          "chats": {"code": "act_open_object", "name": "Чаты", "disabled": false, "params": {"object_code": "chats"}},
          "all_chats": {"code": "act_open_object", "name": "Все чаты", "disabled": false, "params": {"object_code": "all_chats"}},
          "logout": {"code": "logout", "name": "Выход", "disabled": false, "params": {}}
        }';
    end if;
  end if;

  return v_actions;
end;
$$
language plpgsql;
