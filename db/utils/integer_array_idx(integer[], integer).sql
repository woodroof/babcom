-- Function: utils.integer_array_idx(integer[], integer)

-- DROP FUNCTION utils.integer_array_idx(integer[], integer);

CREATE OR REPLACE FUNCTION utils.integer_array_idx(
    in_array integer[],
    in_value integer)
  RETURNS integer AS
$BODY$
declare
  v_idx integer;
begin
  select num
  into v_idx
  from (
    select row_number() over() as num, s.value
    from unnest(in_array) s(value)
  ) s
  where s.value = in_value
  limit 1;

  return v_idx;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
