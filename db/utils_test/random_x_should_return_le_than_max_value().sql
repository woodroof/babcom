-- Function: utils_test.random_x_should_return_le_than_max_value()

-- DROP FUNCTION utils_test.random_x_should_return_le_than_max_value();

CREATE OR REPLACE FUNCTION utils_test.random_x_should_return_le_than_max_value()
  RETURNS void AS
$BODY$
declare
  v_type text;
  v_min_value text := '2';
  v_max_value text := '5';
begin
  foreach v_type in array array ['bigint', 'integer'] loop
    execute 'select test.assert_ge(' || v_max_value || ', utils.random_' || v_type || '(' || v_min_value || ', ' || v_max_value || '))';
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
