-- drop function json.get_number_array_opt(jsonb, double precision[]);

create or replace function json.get_number_array_opt(in_json jsonb, in_default double precision[])
returns double precision[]
immutable
as
$$
declare
  v_array jsonb := json.get_array_opt(in_json, null);
begin
  if v_array is null then
    return in_default;
  end if;

  return json.get_number_array(v_array);
end;
$$
language plpgsql;
