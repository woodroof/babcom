-- Function: util_test.random_x_should_return_exact_value()

-- DROP FUNCTION util_test.random_x_should_return_exact_value();

CREATE OR REPLACE FUNCTION util_test.random_x_should_return_exact_value()
  RETURNS void AS
$BODY$
declare
  v_type text;
  v_value text := '5';
begin
  foreach v_type in array array ['bigint', 'integer'] loop
    execute 'select test.assert_eq(5, util.random_' || v_type || '(' || v_value || ', ' || v_value || '))';
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
