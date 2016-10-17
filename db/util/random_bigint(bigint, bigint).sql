-- Function: util.random_bigint(bigint, bigint)

-- DROP FUNCTION util.random_bigint(bigint, bigint);

CREATE OR REPLACE FUNCTION util.random_bigint(
    in_min_value bigint,
    in_max_value bigint)
  RETURNS bigint AS
$BODY$
declare
  v_random_double double precision := random();
begin
  if in_min_value = in_max_value then
    return in_min_value;
  end if;
  if in_min_value > in_max_value then
    raise invalid_parameter_value using message = 'random_bigint: min value can''t be greater then max value';
  end if;

  return floor(in_min_value + v_random_double * (in_max_value - in_min_value + 1));
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
