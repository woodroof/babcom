-- drop function json.get_string_array_opt(json, text[]);

create or replace function json.get_string_array_opt(in_json json, in_default text[])
returns text[]
immutable
as
$$

declare
  v_array json := json.get_array_opt(in_json, null);
begin
  if v_array is null then
    return in_default;
  end if;

  return json.get_string_array(v_array);
end;

$$
language 'plpgsql';
