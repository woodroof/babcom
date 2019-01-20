-- drop function json.get_boolean_array_opt(json, text, boolean[]);

create or replace function json.get_boolean_array_opt(in_json json, in_name text, in_default boolean[])
returns boolean[]
immutable
as
$$
declare
  v_array json := json.get_array_opt(in_json, in_name, null);
begin
  if v_array is null then
    return in_default;
  end if;

  return json.get_boolean_array(in_json, in_name);
end;
$$
language plpgsql;
