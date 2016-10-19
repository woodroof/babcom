-- Function: json_test.get_opt_array_should_return_default_value_for_null_json()

-- DROP FUNCTION json_test.get_opt_array_should_return_default_value_for_null_json();

CREATE OR REPLACE FUNCTION json_test.get_opt_array_should_return_default_value_for_null_json()
  RETURNS void AS
$BODY$
declare
  v_json_type text;
  v_default_value text := '''[1, "2", {"key": 3}]''';
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    execute 'select test.assert_eq(' || v_default_value || '::' || v_json_type || ', json.get_opt_array(null::' || v_json_type || ', ' || v_default_value || '::' || v_json_type || '))';
    execute 'select test.assert_eq(' || v_default_value || '::' || v_json_type || ', json.get_opt_array(null::' || v_json_type || ', ' || v_default_value || '::' || v_json_type || ', ''key''))';
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
