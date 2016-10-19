-- Function: json_test.get_x_integer_should_throw_for_float_json()

-- DROP FUNCTION json_test.get_x_integer_should_throw_for_float_json();

CREATE OR REPLACE FUNCTION json_test.get_x_integer_should_throw_for_float_json()
  RETURNS void AS
$BODY$
declare
  v_json text := '''5.55''';
  v_json_type text;
  v_opt_part text;
  v_type text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    perform test.assert_throw(
      'select json.get_integer(' || v_json || '::' || v_json_type || ')',
      'Json is not an integer');
    perform test.assert_throw(
      'select json.get_opt_integer(' || v_json || '::' || v_json_type || ', 5)',
      'Json is not an integer');
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
