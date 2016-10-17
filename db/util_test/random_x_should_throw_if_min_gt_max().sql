-- Function: util_test.random_x_should_throw_if_min_gt_max()

-- DROP FUNCTION util_test.random_x_should_throw_if_min_gt_max();

CREATE OR REPLACE FUNCTION util_test.random_x_should_throw_if_min_gt_max()
  RETURNS void AS
$BODY$
declare
  v_type text;
  v_min_value text := '-5';
  v_max_value text := '5';
begin
  foreach v_type in array array ['bigint', 'integer'] loop
    perform test.assert_throw(
      'select util.random_' || v_type || '(' || v_max_value || ', ' || v_min_value || ')',
      '%min value can''t be greater then max value');
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
