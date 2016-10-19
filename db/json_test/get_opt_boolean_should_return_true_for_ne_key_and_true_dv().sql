-- Function: json_test.get_opt_boolean_should_return_true_for_ne_key_and_true_dv()

-- DROP FUNCTION json_test.get_opt_boolean_should_return_true_for_ne_key_and_true_dv();

CREATE OR REPLACE FUNCTION json_test.get_opt_boolean_should_return_true_for_ne_key_and_true_dv()
  RETURNS void AS
$BODY$
declare
  v_json text := '''{"key1": "value1", "key2": 2}''';
  v_json_type text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    execute 'select test.assert_true(json.get_opt_boolean(' || v_json || '::' || v_json_type || ', true, ''key''))';
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
