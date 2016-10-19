-- Function: json_test.get_opt_object_should_throw_for_non_object_default_value()

-- DROP FUNCTION json_test.get_opt_object_should_throw_for_non_object_default_value();

CREATE OR REPLACE FUNCTION json_test.get_opt_object_should_throw_for_non_object_default_value()
  RETURNS void AS
$BODY$
declare
  v_json text := '''{"key1": "value1", "key2": 2}''';
  v_json_type text;
  v_json_value text;
  v_default_value text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json_value in array array [v_json, 'null'] loop
      foreach v_default_value in array array ['5', '"qwe"', '[]'] loop
        perform test.assert_throw(
          'select json.get_opt_object(' || v_json_value || '::' || v_json_type || ', ''' || v_default_value || '''::' || v_json_type || ')',
          '%' || v_default_value || '% is not an object');
        perform test.assert_throw(
          'select json.get_opt_object(' || v_json_value || '::' || v_json_type || ', ''' || v_default_value || '''::' || v_json_type || ', ''key'')',
          '%' || v_default_value || '% is not an object');
      end loop;
    end loop;
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
