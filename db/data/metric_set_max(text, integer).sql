-- drop function data.metric_set_max(text, integer);

create or replace function data.metric_set_max(in_code text, in_value integer)
returns void
volatile
as
$$
begin
  assert in_code is not null;
  assert in_value is not null;

  insert into data.metrics as m (code, value)
  values (in_code, in_value)
  on conflict (code) do update
  set value = greatest(m.value, in_value);
end;
$$
language plpgsql;
