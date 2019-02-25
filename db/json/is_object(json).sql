-- drop function json.is_object(json);

create or replace function json.is_object(in_json json)
returns boolean
immutable
as
$$
begin
  return json_typeof(in_json) = 'object';
end;
$$
language plpgsql;
