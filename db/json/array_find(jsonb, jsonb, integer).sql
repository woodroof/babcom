-- drop function json.array_find(jsonb, jsonb, integer);

create or replace function json.array_find(in_array jsonb, in_value jsonb, in_position integer default 0)
returns integer
volatile
as
$$
declare
  v_size integer := jsonb_array_length(in_array);
  v_position integer := in_position;
begin
  assert v_size is not null;
  assert in_value is not null;
  assert v_position is not null;

  while v_position < v_size loop
    if in_array->v_position = in_value then
      return v_position;
    end if;

    v_position := v_position + 1;
  end loop;

  return null;
end;
$$
language plpgsql;
