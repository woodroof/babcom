-- drop function json.is_object(jsonb);

create or replace function json.is_object(in_json jsonb)
returns boolean
immutable
as
$$
begin
  return jsonb_typeof(in_json) = 'object';
end;
$$
language plpgsql;
