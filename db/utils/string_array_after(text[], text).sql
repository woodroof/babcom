-- Function: utils.string_array_after(text[], text)

-- DROP FUNCTION utils.string_array_after(text[], text);

CREATE OR REPLACE FUNCTION utils.string_array_after(
    in_array text[],
    in_value text)
  RETURNS text[] AS
$BODY$
declare
  v_ret_val text[];
begin
  select array_agg(value)
  into v_ret_val
  from (
    select
      row_number() over() as num,
      value
    from unnest(in_array) s(value)
  ) f
  where f.num > coalesce(utils.string_array_idx(in_array, in_value), 0);

  return v_ret_val;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
