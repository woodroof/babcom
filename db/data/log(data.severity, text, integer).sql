-- drop function data.log(data.severity, text, integer);

create or replace function data.log(in_severity data.severity, in_message text, in_actor_id integer default null::integer)
returns void
volatile
as
$$
begin
  assert in_actor_id is null or data.is_instance(in_actor_id);

  insert into data.log(severity, message, actor_id)
  values(in_severity, in_message, in_actor_id);
end;
$$
language plpgsql;
