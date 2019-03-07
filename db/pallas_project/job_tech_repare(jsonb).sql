-- drop function pallas_project.job_tech_repare(jsonb);

create or replace function pallas_project.job_tech_repare(in_params jsonb)
returns void
volatile
as
$$
declare
  v_tech_code text := json.get_string(in_params, 'tech_code');
  v_tech_id text := replace(v_tech_code, 'equipment_', '');
  v_skill integer := json.get_integer(in_params, 'skill');
  v_tech_broken text := json.get_string(data.get_attribute_value_for_update(v_tech_code, 'tech_broken'));
  v_random integer := random.random_integer(1, 10);
  v_mine_equipment_id integer := data.get_object_id('mine_equipment');
  v_mine_equipment_json jsonb := data.get_attribute_value_for_update(v_mine_equipment_id, 'mine_equipment');
begin
  if v_tech_broken = 'reparing' then
    if (v_skill = 0 and v_random > 5) or (v_skill = 1 and v_random > 3) or (v_skill >= 2 and v_random > 1) or (v_skill = -100) then
      perform data.change_object_and_notify(data.get_object_id(v_tech_code), 
                                          jsonb_build_array(data.attribute_change2jsonb('tech_broken', jsonb '"working"')));
      v_mine_equipment_json := jsonb_set(v_mine_equipment_json, array[v_tech_id, 'broken'], jsonb 'false');
      perform data.change_object_and_notify(v_mine_equipment_id, 
                                           jsonb_build_array(data.attribute_change2jsonb('mine_equipment', v_mine_equipment_json)),
                                           null);

    else
      perform data.change_object_and_notify(data.get_object_id(v_tech_code), 
                                          jsonb_build_array(data.attribute_change2jsonb('tech_broken', jsonb '"broken"')));
    end if;
  end if;
end;
$$
language plpgsql;
