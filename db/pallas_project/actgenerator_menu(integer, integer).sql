-- drop function pallas_project.actgenerator_menu(integer, integer);

create or replace function pallas_project.actgenerator_menu(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_object_code text := data.get_object_code(in_object_id);
  v_actor_code text := data.get_object_code(in_actor_id);
  v_actions jsonb := '{}';
  v_is_master boolean := pp_utils.is_in_group(in_actor_id, 'master');
begin
  assert in_actor_id is not null;

  -- Тут порядок не важен, т.к. он задаётся в шаблоне

  if v_actor_code = 'anonymous' then
    v_actions :=
      v_actions ||
      jsonb '{"login": {"code": "login", "name": "Войти", "disabled": false, "params": {}, "user_params": [{"code": "password", "description": "Введите пароль", "type": "string", "restrictions": {"password": true}}]}}';
  elsif v_is_master or pp_utils.is_in_group(in_actor_id, 'all_person') then
    if not v_is_master then
      v_actions :=
        v_actions ||
        format(
          '{
            "statuses": {"code": "act_open_object", "name": "Статусы", "disabled": false, "params": {"object_code": "%s_statuses"}}
          }',
          v_actor_code)::jsonb;
      v_actions :=
        v_actions ||
        jsonb '{
          "chats": {"code": "act_open_object", "name": "Чаты", "disabled": false, "params": {"object_code": "chats"}},
          "master_chats": {"code": "act_open_object", "name": "Связь с мастерами", "disabled": false, "params": {"object_code": "master_chats"}}
        }';
    else
      v_actions :=
        v_actions ||
        jsonb '{
          "chats": {"code": "act_open_object", "name": " Отслеживаемые игровые чаты", "disabled": false, "params": {"object_code": "chats"}},
          "all_chats": {"code": "act_open_object", "name": "Все игровые чаты", "disabled": false, "params": {"object_code": "all_chats"}},
          "master_chats": {"code": "act_open_object", "name": "Мастерские чаты", "disabled": false, "params": {"object_code": "master_chats"}}
        }';
    end if;

    v_actions :=
      v_actions ||
      jsonb '{
        "debatles": {"code": "act_open_object", "name": "Дебатлы", "disabled": false, "params": {"object_code": "debatles"}},
        "chats": {"code": "act_open_object", "name": "Чаты", "disabled": false, "params": {"object_code": "chats"}},
        "logout": {"code": "logout", "name": "Выход", "disabled": false, "params": {}}
      }';
  end if;

  v_actions :=
    v_actions ||
    jsonb '{"persons": {"code": "act_open_object", "name": "Люди", "disabled": false, "params": {"object_code": "persons"}}}';

  return v_actions;
end;
$$
language plpgsql;
