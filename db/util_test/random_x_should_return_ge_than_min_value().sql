-- Function: util_test.random_x_should_return_ge_than_min_value()

-- DROP FUNCTION util_test.random_x_should_return_ge_than_min_value();

CREATE OR REPLACE FUNCTION util_test.random_x_should_return_ge_than_min_value()
  RETURNS void AS
$BODY$
declare
  v_type text;
  v_min_value text := '-5';
  v_max_value text := '-2';
begin
  foreach v_type in array array ['bigint', 'integer'] loop
    execute 'select test.assert_le(' || v_min_value || ', util.random_' || v_type || '(' || v_min_value || ', ' || v_max_value || '))';
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
