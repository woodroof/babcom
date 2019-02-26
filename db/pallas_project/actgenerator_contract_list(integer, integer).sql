-- drop function pallas_project.actgenerator_contract_list(integer, integer);

create or replace function pallas_project.actgenerator_contract_list(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_object_code text := data.get_object_code(in_object_id);
  v_org_code text := substring(v_object_code for length(v_object_code) - length('_contracts'));
  v_type text := json.get_string(data.get_attribute_value(v_org_code, 'type'));
  v_is_head boolean;
  v_is_economist boolean;
  v_is_master boolean;
  v_actions jsonb := '{}';
begin
  if v_type = 'organization' then
    v_is_head := pp_utils.is_in_group(in_actor_id, v_org_code || '_head');
    v_is_economist := pp_utils.is_in_group(in_actor_id, v_org_code || '_economist');
    v_is_master := pp_utils.is_in_group(in_actor_id, 'master');

    if v_is_master or v_is_head or v_is_economist then
      v_actions :=
        v_actions ||
        format(
          '{
            "create_contract": {
              "code": "create_contract",
              "name": "Создать контракт",
              "disabled": false,
              "params": "%s"
            }
          }',
          v_org_code)::jsonb;
    end if;
  end if;

  return v_actions;
end;
$$
language plpgsql;
