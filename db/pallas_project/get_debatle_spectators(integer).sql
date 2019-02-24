-- drop function pallas_project.get_debatle_spectators(integer);

create or replace function pallas_project.get_debatle_spectators(in_debatle_id integer)
returns integer[]
volatile
as
$$
declare
  v_objects integer[];
  v_debatle_code text := data.get_object_code(in_debatle_id);
  v_system_debatle_target_audience text[] := json.get_string_array_opt(data.get_attribute_value_for_share(in_debatle_id, 'system_debatle_target_audience'), array[]::text[]);
  v_debatle_person1_id integer := coalesce(data.get_object_id_opt(json.get_string_opt(data.get_attribute_value_for_share(in_debatle_id, 'debatle_person1'), null)),-1);
  v_debatle_person2_id integer := coalesce(data.get_object_id_opt(json.get_string_opt(data.get_attribute_value_for_share(in_debatle_id, 'debatle_person2'), null)),-1);
  v_debatle_judge_id integer := coalesce(data.get_object_id_opt(json.get_string_opt(data.get_attribute_value_for_share(in_debatle_id, 'debatle_judge'), null)),-1);
begin
  v_system_debatle_target_audience := array_append(v_system_debatle_target_audience, v_debatle_code);
  select array_agg(distinct oo.object_id) into v_objects
      from data.object_objects oo
      inner join data.objects o on o.id = oo.object_id
      inner join data.objects c on o.class_id = c.id and c.code = 'person'
      where oo.parent_object_id in (select og.id from unnest(v_system_debatle_target_audience) as u
                                      inner join data.objects og on og.code = u) 
        and oo.parent_object_id <> oo.object_id
        and oo.object_id not in (v_debatle_person1_id, v_debatle_person2_id, v_debatle_judge_id) ;
  return v_objects;
end;
$$
language plpgsql;
