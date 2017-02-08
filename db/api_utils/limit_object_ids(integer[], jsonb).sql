-- Function: api_utils.limit_object_ids(integer[], jsonb)

-- DROP FUNCTION api_utils.limit_object_ids(integer[], jsonb);

CREATE OR REPLACE FUNCTION api_utils.limit_object_ids(
    in_object_ids integer[],
    in_params jsonb)
  RETURNS integer[] AS
$BODY$
declare
  v_limit integer;
  v_object_ids integer[];
begin
  assert in_object_ids is not null;
  assert in_params is not null;

  v_limit := json.get_opt_integer(in_params, null, 'limit');
  if v_limit is not null then
    v_object_ids := intarray.subarray(in_object_ids, 1, v_limit);
  else
    v_object_ids := in_object_ids;
  end if;

  return v_object_ids;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
