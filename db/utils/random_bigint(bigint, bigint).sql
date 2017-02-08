-- Function: utils.random_bigint(bigint, bigint)

-- DROP FUNCTION utils.random_bigint(bigint, bigint);

CREATE OR REPLACE FUNCTION utils.random_bigint(
    in_min_value bigint,
    in_max_value bigint)
  RETURNS bigint AS
$BODY$
declare
  v_random_double double precision := random();
begin
  assert in_min_value is not null;
  assert in_max_value is not null;
  assert in_min_value <= in_max_value is not null;

  if in_min_value = in_max_value then
    return in_min_value;
  end if;

  return floor(in_min_value + v_random_double * (in_max_value - in_min_value + 1));
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
