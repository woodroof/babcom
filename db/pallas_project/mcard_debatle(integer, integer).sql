-- drop function pallas_project.mcard_debatle(integer, integer);

create or replace function pallas_project.mcard_debatle(in_object_id integer, in_actor_id integer)
returns void
volatile
as
$$
declare
  v_debatle_theme text;
  v_changes jsonb[];
begin
  perform * from data.objects where id = in_object_id for update;

  v_debatle_theme := json.get_string_opt(data.get_attribute_value(in_object_id, 'system_debatle_theme'), null);  
  v_changes := array_append(v_changes, data.attribute_change2jsonb('title', null, to_jsonb(format('%s', v_debatle_theme))));

  perform data.change_object(in_object_id, to_jsonb(v_changes), in_actor_id);
end;
$$
language 'plpgsql';
