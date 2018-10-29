-- drop function json.get_object_array_opt(json, text, json);

create or replace function json.get_object_array_opt(in_json json, in_name text, in_default json)
immutable
returns json as
$$

declare
  v_default_type text;
  v_array json;
begin
  assert in_name is not null;

  if in_default is not null then
    begin
      perform json.get_object_array(in_default);
    exception when invalid_parameter_value then
      raise exception 'Default value "%" is not an object array', in_default::text;
    end;
  end if;

  v_array := json.get_array_opt(in_json, in_name, null);
  if v_array is null then
    return in_default;
  end if;

  return json.get_object_array(in_json, in_name);
end;

$$
language 'plpgsql';
