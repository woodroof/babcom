-- drop function data.metric_set_max(data.metric_type, integer);

create or replace function data.metric_set_max(in_type data.metric_type, in_value integer)
returns void
volatile
as
$$
declare
  v_id integer;
begin
  assert in_type is not null;
  assert in_value is not null;

  insert into data.metrics as m (type, value)
  values (in_type, in_value)
  on conflict (type) do update
  set value = in_value
  where m.value < in_value
  returning id into v_id;

  if v_id is not null then
    perform api_utils.create_metric_notification(in_type, in_value);
  end if;
end;
$$
language plpgsql;
