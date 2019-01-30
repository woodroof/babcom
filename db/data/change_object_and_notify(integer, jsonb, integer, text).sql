-- drop function data.change_object_and_notify(integer, jsonb, integer, text);

create or replace function data.change_object_and_notify(in_object_id integer, in_changes jsonb, in_actor_id integer default null::integer, in_reason text default null::text)
returns void
volatile
as
$$
begin
  perform data.process_diffs_and_notify(data.change_object(in_object_id, in_changes, in_actor_id, in_reason));
end;
$$
language plpgsql;
