-- drop function pallas_project.actgenerator_med_drug(integer, integer);

create or replace function pallas_project.actgenerator_med_drug(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
  v_drug_code text := data.get_object_code(in_object_id);
  v_med_drug_status text := json.get_string(data.get_attribute_value_for_share(in_object_id, 'med_drug_status'));
begin
  assert in_actor_id is not null;

  if not pp_utils.is_in_group(in_actor_id, 'master') then
    v_actions_list := v_actions_list || 
        format(', "med_drug_use": {"code": "med_drug_use", "name": "Использовать", "disabled": %s, '||
                '"params": {"med_drug_code": "%s"}}',
                case when v_med_drug_status = 'not_used' then 'false' else 'true' end,
                v_drug_code);
  end if;

  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;
