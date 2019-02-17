-- drop function pallas_project.actgenerator_next_statuses(integer, integer);

create or replace function pallas_project.actgenerator_next_statuses(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_master boolean := pp_utils.is_in_group(in_actor_id, 'master');
  v_economy_type text;
  v_coins integer;
  v_money integer;
  v_coin_price integer;
  v_status_name text;
  v_actions jsonb := jsonb '{}';
begin
  if not v_master then
    v_economy_type := json.get_string(data.get_attribute_value_for_share(in_actor_id, 'system_person_economy_type'));

    if v_economy_type = 'un' then
      v_coins := json.get_integer(data.get_attribute_value_for_share(in_actor_id, 'system_person_coin'));
    else
      v_money := json.get_integer(data.get_attribute_value_for_share(in_actor_id, 'system_money'));
      v_coin_price := data.get_integer_param('coin_price');
    end if;
  end if;

  for v_status_name in
  (
    select value
    from unnest(array['life_support', 'health_care', 'recreation', 'police', 'administrative_services']) a(value)
  )
  loop
    declare
      v_status_prices integer[] := data.get_integer_array_param(v_status_name || '_status_prices');
      v_status integer := json.get_integer(data.get_attribute_value_for_share(in_object_id, v_status_name || '_next_status'));
      v_price bigint;
      v_too_expensive boolean;
      v_action record;
    begin
      assert array_length(v_status_prices, 1) = 3;
      assert v_status in (0, 1, 2, 3);

      if v_master then
        -- todo установка статусов
      else
        v_price := 0;

        for v_action in
        (
          select
            value,
            (case when value = 1 then 'bronze' when value = 2 then 'silver' else 'gold' end) action_suffix,
            (case when value = 1 then 'бронзовый' when value = 2 then 'серебряный' else 'золотой' end) description
          from unnest(array[1, 2, 3]) a(value)
        )
        loop
          if v_status < v_action.value then
            v_price := v_price + v_status_prices[v_action.value] * (case when v_economy_type = 'un' then 1 else v_coin_price end);
            v_too_expensive := (case when v_economy_type = 'un' then v_coins < v_price else v_money < v_price end);

            if v_too_expensive then
              v_actions :=
                v_actions ||
                format(
                  '{
                    "%s_%s": {
                      "name": "Купить %s статус (%s)",
                      "disabled": true
                    }
                  }',
                  v_status_name,
                  v_action.action_suffix,
                  v_action.description,
                  v_price)::jsonb;
            else
              v_actions :=
                v_actions ||
                format(
                  '{
                    "%s_%s": {
                      "code": "buy_status",
                      "name": "Купить %s статус (%s)",
                      "disabled": false,
                      "warning": "Вы действительно хотите купить %s статус за %s?",
                      "params": {"status_name": "%s", "value": %s}
                    }
                  }',
                  v_status_name,
                  v_action.action_suffix,
                  v_action.description,
                  (case when v_economy_type = 'un' then v_price::text else pp_utils.format_money(v_price) end),
                  v_action.description,
                  (case when v_economy_type = 'un' then v_price || ' ' || pp_utils.add_word_ending('коин', v_price) else pp_utils.format_money(v_price) end),
                  v_status_name,
                  v_action.value)::jsonb;
            end if;
          end if;
        end loop;
      end if;
    end;
  end loop;

  return v_actions;
end;
$$
language plpgsql;
