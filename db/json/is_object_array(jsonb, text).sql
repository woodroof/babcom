-- drop function json.is_object_array(jsonb, text);

create or replace function json.is_object_array(in_json jsonb, in_name text default null::text)
returns boolean
immutable
as
$$
declare
  v_array jsonb;
  v_array_len integer;
begin
  if in_name is not null then
    v_array := json.get_object(in_json)->in_name;
  else
    v_array = in_json;
  end if;

  if v_array is null or jsonb_typeof(v_array) != 'array' then
    return false;
  end if;

  v_array_len := jsonb_array_length(v_array);

  for i in 0 .. v_array_len - 1 loop
    if jsonb_typeof(v_array->i) != 'object' then
      return false;
    end if;
  end loop;

  return true;
end;
$$
language plpgsql;
