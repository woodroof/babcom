-- drop function pallas_project.actgenerator_person(integer, integer);

create or replace function pallas_project.actgenerator_person(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_object_code text := data.get_object_code(in_object_id);
  v_master boolean := pp_utils.is_in_group(in_actor_id, 'master');
  v_economy_type jsonb;
  v_actions jsonb := jsonb '{}';
begin
  if v_master then
    v_economy_type := data.get_attribute_value_for_share(in_object_id, 'system_person_economy_type');
    if v_economy_type is not null then
      v_actions :=
        v_actions ||
        format('{
          "open_current_statuses": {
            "code": "act_open_object",
            "name": "Посмотреть текущие статусы",
            "disabled": false,
            "params": {
              "object_code": "%s_statuses"
            }
          }
        }', v_object_code)::jsonb;
      if v_economy_type != jsonb '"fixed"' then
        v_actions :=
          v_actions ||
          format('{
            "open_next_statuses": {
              "code": "act_open_object",
              "name": "Посмотреть купленные статусы на следующий цикл",
              "disabled": false,
              "params": {
                "object_code": "%s_next_statuses"
              }
            }
          }', v_object_code)::jsonb;
        if v_economy_type != jsonb '"un"' then
          v_actions :=
            v_actions ||
            format('{
              "open_transactions": {
                "code": "act_open_object",
                "name": "Посмотреть историю транзакций",
                "disabled": false,
                "params": {
                  "object_code": "%s_transactions"
                }
              }
            }', v_object_code)::jsonb;
        end if;
      end if;
    end if;
  end if;

  return v_actions;
end;
$$
language plpgsql;
