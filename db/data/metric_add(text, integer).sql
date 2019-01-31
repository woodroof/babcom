-- drop function data.metric_add(text, integer);

create or replace function data.metric_add(in_code text, in_value integer)
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
  set value = m.value + in_value;
end;
$$
language plpgsql;
