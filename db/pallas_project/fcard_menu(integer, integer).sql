-- drop function pallas_project.fcard_menu(integer, integer);

create or replace function pallas_project.fcard_menu(in_object_id integer, in_actor_id integer)
returns void
volatile
as
$$
declare
  v_is_master boolean := pp_utils.is_in_group(in_actor_id, 'master');

  v_content text[];

  v_changes jsonb[];
begin
  perform * from data.objects where id = in_object_id for update;

  v_content := array['debatles'];

  v_changes := array_append(v_changes, data.attribute_change2jsonb('content', in_actor_id, to_jsonb(v_content)));


  perform data.change_object(in_object_id, to_jsonb(v_changes), in_actor_id);
end;
$$
language plpgsql;
