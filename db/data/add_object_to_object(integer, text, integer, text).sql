-- drop function data.add_object_to_object(integer, text, integer, text);

create or replace function data.add_object_to_object(in_object_id integer, in_parent_object_code text, in_actor_id integer default null::integer, in_reason text default null::text)
returns void
volatile
as
$$
-- Как правило вместо этой функции следует вызывать data.change_object_groups
begin
  perform data.add_object_to_object(in_object_id, data.get_object_id(in_parent_object_code), in_actor_id, in_reason);
end;
$$
language plpgsql;
