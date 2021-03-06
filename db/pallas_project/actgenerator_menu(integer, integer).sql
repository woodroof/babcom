-- drop function pallas_project.actgenerator_menu(integer, integer);

create or replace function pallas_project.actgenerator_menu(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actor_code text := data.get_object_code(in_actor_id);
  v_actions jsonb := '{}';
  v_is_master boolean;
  v_economy_type text;
  v_original_person_id jsonb := data.get_attribute_value(in_actor_id, 'system_person_original_id');
begin
  -- Тут порядок не важен, т.к. он задаётся в шаблоне

  if v_actor_code = 'anonymous' then
    v_actions :=
      v_actions ||
      jsonb '{"login": {"code": "login", "name": "Войти", "disabled": false, "params": {}, "user_params": [{"code": "password", "description": "Введите пароль", "type": "string", "restrictions": {"password": true}}]}}';
  else
    v_is_master := pp_utils.is_in_group(in_actor_id, 'master');
    if not v_is_master then
      v_economy_type := json.get_string_opt(data.get_attribute_value_for_share(in_actor_id, 'system_person_economy_type'), null);
    end if;

    if not v_is_master then
      if v_economy_type is not null then
        v_actions :=
          v_actions ||
          format(
            '{
              "statuses": {"code": "act_open_object", "name": "Статусы", "disabled": false, "params": {"object_code": "%s_statuses"}}
            }',
          v_actor_code)::jsonb;
      end if;

      v_actions :=
        v_actions ||
        format(
          '{
            "profile": {"code": "act_open_object", "name": "Профиль", "disabled": false, "params": {"object_code": "%s"}}
          }',
          v_actor_code)::jsonb;
      v_actions :=
        v_actions ||
        format('{
          "chats": {"code": "act_open_object", "name": "Чаты", "disabled": false, "params": {"object_code": "%s_chats"}},
          "master_chats": {"code": "act_open_object", "name": "Связь с мастерами", "disabled": false, "params": {"object_code": "%s_master_chats"}},
          "important_notifications": {"code": "act_open_object", "name": "Важные уведомления", "disabled": false, "params": {"object_code": "%s_important_chat"}}
          }',
          v_actor_code,
          v_actor_code,
          v_actor_code)::jsonb;

      if v_original_person_id is null then
        v_actions :=
          v_actions ||
          format(
            '{
              "med_health": {"code": "act_open_object", "name": "💔 Состояние здоровья 💔", "disabled": false, "params": {"object_code": "%s_med_health"}}
            }',
            v_actor_code)::jsonb;
      end if;

      if v_economy_type != 'un' and v_economy_type != 'fixed' then
        v_actions :=
          v_actions ||
          format(
            '{
              "transactions": {"code": "act_open_object", "name": "🏦 История транзакций 🏦", "disabled": false, "params": {"object_code": "%s_transactions"}}
            }',
            v_actor_code)::jsonb;
      end if;

      if v_economy_type not in ('fixed', 'fixed_with_money') then
        v_actions :=
          v_actions ||
          format(
            '{
              "next_statuses": {"code": "act_open_object", "name": "Покупка статусов", "disabled": false, "params": {"object_code": "%s_next_statuses"}}
            }',
            v_actor_code)::jsonb;

        declare
          v_contracts jsonb := data.get_raw_attribute_value_for_share(v_actor_code || '_contracts', 'content');
        begin
          if v_contracts != jsonb '[]' then
            v_actions :=
              v_actions ||
              format(
                '{
                  "my_contracts": {"code": "act_open_object", "name": "Контракты", "disabled": false, "params": {"object_code": "%s_contracts"}}
                }',
                v_actor_code)::jsonb;
          end if;
        end;
      end if;
    else
      v_actions :=
        v_actions ||
       format('{
          "chats": {"code": "act_open_object", "name": "Отслеживаемые игровые чаты", "disabled": false, "params": {"object_code": "%s_chats"}},
          "all_chats": {"code": "act_open_object", "name": "Все игровые чаты", "disabled": false, "params": {"object_code": "all_chats"}},
          "master_chats": {"code": "act_open_object", "name": "Мастерские чаты", "disabled": false, "params": {"object_code": "%s_master_chats"}},
          "all_contracts": {"code": "act_open_object", "name": "Все контракты", "disabled": false, "params": {"object_code": "contracts"}},
          "cycle_checklist": {"code": "act_open_object", "name": "Чеклист", "disabled": false, "params": {"object_code": "cycle_checklist"}},
          "med_drugs": {"code": "act_open_object", "name": "Наркотики", "disabled": false, "params": {"object_code": "med_drugs"}},
          "prices": {"code": "act_open_object", "name": "Цены", "disabled": false, "params": {"object_code": "prices"}},
          "equipment": {"code": "act_open_object", "name": "Оборудование", "disabled": false, "params": {"object_code": "equipment"}}
        }',
        v_actor_code,
        v_actor_code)::jsonb;
      v_actions := v_actions || 
        ('{"notify_everyone": {"code": "notify_everyone", "name": "Уведомление для всех", "disabled": false, '||
                '"params": {}, "user_params": [{"code": "message", "description": "Введите текст уведомления", "type": "string"}]}}')::jsonb;
      if data.get_boolean_param('game_in_progress') then
        v_actions :=
          v_actions ||
          jsonb '{
            "finish_game": {
              "code": "finish_game",
              "name": "☠️ ЗАВЕРШИТЬ ИГРУ ☠️",
              "warning": "Это действие разошлёт уведомление ВСЕМ ИГРОКАМ и прекратит работу экономики. Продолжить?",
              "params": null,
              "user_params": [
                {"code": "confirm", "description": "Введите сюда \"ДА\"", "type": "string"}
              ]}
          }';
      end if;
    end if;

    declare
      v_notification_count integer := json.get_integer(data.get_attribute_value_for_share(in_actor_id, 'system_person_notification_count'));
    begin
      if v_notification_count > 0 then
        v_actions :=
          v_actions ||
          format(
            '{
              "notifications": {"code": "act_open_object", "name": "🔥 Уведомления 🔥 (%s)", "disabled": false, "params": {"object_code": "%s_notifications"}}
            }',
            v_notification_count,
            v_actor_code)::jsonb;
      end if;
    end;

    declare
      v_lottery_id integer := data.get_object_id('lottery');
      v_lottery_status text := json.get_string(data.get_attribute_value_for_share(v_lottery_id, 'lottery_status'));
      v_generate boolean := false;
      v_lottery_owner text;
    begin
      if v_lottery_status = 'active' then
        if v_is_master or v_economy_type = 'asters' then
          v_generate := true;
        else
          v_lottery_owner := json.get_string(data.get_attribute_value_for_share(v_lottery_id, 'system_lottery_owner'));
          if v_lottery_owner = v_actor_code then
            v_generate := true;
          end if;
        end if;

        if v_generate then
          v_actions :=
            v_actions ||
            jsonb '{
              "lottery": {"code": "act_open_object", "name": "🇺🇳 Лотерея гражданства 🇺🇳", "disabled": false, "params": {"object_code": "lottery"}}
            }';
        end if;
      end if;
    end;

    declare
      v_groups jsonb := data.get_raw_attribute_value_for_share(data.get_object_id(v_actor_code || '_my_organizations'), 'content');
    begin
      if v_groups != jsonb '[]' then
        v_actions :=
          v_actions ||
          format(
            '{
              "my_organizations": {"code": "act_open_object", "name": "🏛 Мои организации 🏛", "disabled": false, "params": {"object_code": "%s"}}
            }',
            v_actor_code || '_my_organizations')::jsonb;
      end if;
    end;

    v_actions :=
      v_actions ||
      jsonb '{
        "debatles": {"code": "act_open_object", "name": "Дебатлы", "disabled": false, "params": {"object_code": "debatles"}},
        "documents": {"code": "act_open_object", "name": "Документы", "disabled": false, "params": {"object_code": "documents"}},
        "news": {"code": "act_open_object", "name": "Новости", "disabled": false, "params": {"object_code": "news"}},
        "claims": {"code": "act_open_object", "name": "Судебные иски", "disabled": false, "params": {"object_code": "claims"}},
        "mine": {"code": "act_open_object", "name": "Карта", "disabled": false, "params": {"object_code": "mine"}},
        "logout": {"code": "logout", "name": "Выход", "disabled": false, "params": {}}
      }';
    if pp_utils.is_in_group(in_actor_id, 'doctor') or pp_utils.is_in_group(in_actor_id, 'unofficial_doctor') then
      v_actions :=
        v_actions ||
        jsonb '{
          "medicine": {"code": "med_open_medicine", "name": "💉 Медицина 💉", "disabled": false, "params": {}}
        }';
    end if;
    if v_is_master or pp_utils.is_in_group(in_actor_id, 'customs_officer') then
      v_actions :=
        v_actions ||
        jsonb '{
          "customs": {"code": "act_open_object", "name": "Таможня", "disabled": false, "params": {"object_code": "customs"}}
        }';
    end if;

  end if;

  v_actions :=
    v_actions ||
    jsonb '{
      "persons": {"code": "act_open_object", "name": "Люди", "disabled": false, "params": {"object_code": "persons"}},
      "districts": {"code": "act_open_object", "name": "Районы", "disabled": false, "params": {"object_code": "districts"}},
      "organizations": {"code": "act_open_object", "name": "Организации", "disabled": false, "params": {"object_code": "organizations"}}
    }';

  return v_actions;
end;
$$
language plpgsql;
