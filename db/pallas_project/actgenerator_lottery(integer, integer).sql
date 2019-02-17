-- drop function pallas_project.actgenerator_lottery(integer, integer);

create or replace function pallas_project.actgenerator_lottery(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_status text := json.get_string(data.get_attribute_value_for_share(in_object_id, 'lottery_status'));
  v_master boolean;
  v_economy_type text;
  v_lottery_owner text;
  v_ticket_price integer;
  v_money bigint;
  v_actions jsonb := '{}';
begin
  if v_status = 'active' then
    v_master := pp_utils.is_in_group(in_actor_id, 'master');

    if v_master then
      v_actions :=
        v_actions ||
        jsonb '{
          "finish_lottery": {
            "code": "finish_lottery",
            "name": "Завершить лотерею",
            "disabled": false,
            "warning": "Уверены, что хотите завершить лотерею?",
            "params": null
          },
          "cancel_lottery": {
            "code": "cancel_lottery",
            "name": "Отменить лотерею",
            "disabled": false,
            "warning": "Точно отменить?",
            "params": null
          }
        }';
    else
      v_economy_type := json.get_string_opt(data.get_attribute_value_for_share(in_actor_id, 'system_person_economy_type'), null);
      v_lottery_owner := json.get_string(data.get_attribute_value_for_share(in_object_id, 'system_lottery_owner'));

      if data.get_object_id(v_lottery_owner) = in_actor_id then
        v_actions :=
          v_actions ||
          jsonb '{
            "finish_lottery": {
              "code": "finish_lottery",
              "name": "Завершить лотерею",
              "disabled": false,
              "warning": "Уверены, что хотите завершить лотерею?",
              "params": null
            }
          }';
      end if;

      if v_economy_type = 'asters' then
        v_ticket_price := data.get_integer_param('lottery_ticket_price');
        v_money := json.get_bigint(data.get_attribute_value_for_share(in_actor_id, 'system_money'));

        if v_money < v_ticket_price then
          v_actions :=
            v_actions ||
            format(
              '{
                "buy_lottery_ticket": {
                  "name": "Купить лотерейный билет (%s)",
                  "disabled": true
                }
              }',
              pp_utils.format_money(v_ticket_price::bigint)
              )::jsonb;
        else
          v_actions :=
            v_actions ||
            format(
              '{
                "buy_lottery_ticket": {
                  "code": "buy_lottery_ticket",
                  "name": "Купить лотерейный билет (%s)",
                  "disabled": false,
                  "warning": "Увеличить шанс выиграть гражданство ООН всего за %s?",
                  "params": null
                }
              }',
              pp_utils.format_money(v_ticket_price::bigint),
              pp_utils.format_money(v_ticket_price::bigint))::jsonb;
        end if;
      end if;
    end if;
  end if;

  return v_actions;
end;
$$
language plpgsql;
