-- drop function pallas_project.actgenerator_debatle(integer, integer);

create or replace function pallas_project.actgenerator_debatle(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
  v_person1_id integer;
  v_is_master boolean;
begin
  assert in_actor_id is not null;

  v_is_master := pallas_project.is_in_group(in_actor_id, 'master');
  v_person1_id := data.get_attribute_value(in_object_id, 'system_debatle_person1');

  if v_is_master then
    v_actions_list := v_actions_list || 
      format(', "debatle_change_instigator": {"code": "debatle_change_person", "name": "Изменить зачинщика", "disabled": false, '||
              '"params": {"debatle_id": %s, "person_number": 1}}',
              in_object_id);
  end if;
  if in_actor_id = v_person1_id or v_is_master then
    v_actions_list := v_actions_list || 
      format(', "debatle_change_opponent": {"code": "debatle_change_person", "name": "Изменить оппонента", "disabled": false, '||
              '"params": {"debatle_id": %s, "person_number": 2}}',
              in_object_id);
  end if;
  if v_is_master then
    v_actions_list := v_actions_list || 
      format(', "debatle_change_judge": {"code": "debatle_change_person", "name": "Изменить судью", "disabled": false, '||
              '"params": {"debatle_id": %s, "person_number": 3}}',
              in_object_id);
  end if;
  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language 'plpgsql';
