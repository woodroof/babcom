-- drop function pp_utils.list_prepend_and_notify(integer, integer, integer, integer);

create or replace function pp_utils.list_prepend_and_notify(in_list_id integer, in_new_object_id integer, in_value_object_id integer, in_actor_id integer default null::integer)
returns void
volatile
as
$$
begin
  perform pp_utils.list_prepend_and_notify(in_list_id, data.get_object_code(in_new_object_id), in_value_object_id, in_actor_id);
end;
$$
language plpgsql;
