-- drop function pallas_project.fcard_debatles(integer, integer);

create or replace function pallas_project.fcard_debatles(in_object_id integer, in_actor_id integer)
returns void
volatile
as
$$
declare
  v_is_master boolean := pallas_project.is_in_group(in_actor_id, 'master');

  v_content text[];

  v_changes jsonb[];
begin
  perform * from data.objects where id = in_object_id for update;

  if v_is_master then
    v_content := array['debatles_new','debatles_current','debutles_future','debatles_closed', 'debatles_all', 'debatles_my']; 
  else
    v_content := array['debatles_my','debatles_closed'];
  end if;

  v_changes := array_append(v_changes, data.attribute_change2jsonb('content', in_actor_id, to_jsonb(v_content)));


  perform data.change_object(in_object_id, to_jsonb(v_changes), in_actor_id);
end;
$$
language plpgsql;
