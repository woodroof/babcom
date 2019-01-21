-- drop function pallas_project.mcard_debatle(integer, integer);

create or replace function pallas_project.mcard_debatle(in_object_id integer, in_actor_id integer)
returns void
volatile
as
$$
declare
  v_new_title jsonb;
  v_title_attribute_id integer := data.get_attribute_id('title');
  v_debatle_theme text;

  begin
  perform * from data.objects where id = in_object_id for update;

  v_debatle_theme := json.get_string_opt(data.get_attribute_value(in_object_id, 'system_debatle_theme'), null);
  v_new_title := to_jsonb(format('%s', v_debatle_theme));
  if coalesce(data.get_raw_attribute_value(in_object_id, v_title_attribute_id, in_actor_id), jsonb '"~~~"') <>  coalesce(v_new_title, jsonb '"~~~"') then
    perform data.set_attribute_value(in_object_id, v_title_attribute_id, v_new_title, in_actor_id, in_actor_id);
  end if;

end;
$$
language plpgsql;
