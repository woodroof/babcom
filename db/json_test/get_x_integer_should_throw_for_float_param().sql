-- Function: json_test.get_x_integer_should_throw_for_float_param()

-- DROP FUNCTION json_test.get_x_integer_should_throw_for_float_param();

CREATE OR REPLACE FUNCTION json_test.get_x_integer_should_throw_for_float_param()
  RETURNS void AS
$BODY$
declare
  v_json text := '''{"key": 5.55}''';
  v_json_type text;
  v_opt_part text;
  v_type text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    perform test.assert_throw(
      'select json.get_integer(' || v_json || '::' || v_json_type || ', ''key'')',
      '%key% is not an integer');
    perform test.assert_throw(
      'select json.get_opt_integer(' || v_json || '::' || v_json_type || ', 5, ''key'')',
      '%key% is not an integer');
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
