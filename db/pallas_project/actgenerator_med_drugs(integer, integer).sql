-- drop function pallas_project.actgenerator_med_drugs(integer, integer);

create or replace function pallas_project.actgenerator_med_drugs(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
  v_drug_code text;
begin
  assert in_actor_id is not null;

  for v_drug_code in (select * from unnest(array['stimulant', 'superbuff', 'sleg', 'rio_vaccine'])) loop
  v_actions_list := v_actions_list || 
        format(', "med_drugs_add_%s": {"code": "med_drugs_add_drug", "name": "%s", "disabled": false, '||
                '"params": {"category": "%s"}}',
                v_drug_code,
                pallas_project.vd_med_drug_category(null, to_jsonb(v_drug_code), null, null), 
                v_drug_code);
  end loop;

  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;
