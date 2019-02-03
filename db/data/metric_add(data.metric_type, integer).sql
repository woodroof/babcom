-- drop function data.metric_add(data.metric_type, integer);

create or replace function data.metric_add(in_type data.metric_type, in_value integer)
returns void
volatile
as
$$
declare
  v_new_value integer;
begin
  assert in_type is not null;
  assert in_value is not null;

  insert into data.metrics as m (type, value)
  values (in_type, in_value)
  on conflict (type) do update
  set value = m.value + in_value
  returning value into v_new_value;

  perform api_utils.create_metric_notification(in_type, v_new_value);
end;
$$
language plpgsql;
