-- drop function pallas_project.fcard_debatles(integer, integer);

create or replace function pallas_project.fcard_debatles(in_object_id integer, in_actor_id integer)
returns void
volatile
as
$$
declare
  v_is_master boolean := pallas_project.is_in_group(in_actor_id, 'master');

  v_content_attribute_id integer := data.get_attribute_id('content');

  v_new_content jsonb;
begin
  perform * from data.objects where id = in_object_id for update;

  if v_is_master then
    v_new_content := to_jsonb(array['debatles_new','debatles_current', 'debutles_future','debatles_closed', 'debatles_all', 'debatles_my']); 
  else
    v_new_content := to_jsonb(array['debatles_my', 'debatles_current', 'debatles_closed']);
  end if;

  if coalesce(data.get_raw_attribute_value(in_object_id, v_content_attribute_id, in_actor_id), to_jsonb(array[]::text[])) <> v_new_content then
    perform data.set_attribute_value(in_object_id, v_content_attribute_id, v_new_content, in_actor_id, in_actor_id);
  end if;
end;
$$
language plpgsql;
