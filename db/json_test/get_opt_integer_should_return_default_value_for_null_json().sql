-- Function: json_test.get_opt_integer_should_return_default_value_for_null_json()

-- DROP FUNCTION json_test.get_opt_integer_should_return_default_value_for_null_json();

CREATE OR REPLACE FUNCTION json_test.get_opt_integer_should_return_default_value_for_null_json()
  RETURNS void AS
$BODY$
declare
  v_json_type text;
  v_default_value text := utils.random_integer(-5, 5)::text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    execute 'select test.assert_eq(' || v_default_value || ', json.get_opt_integer(null::' || v_json_type || ', ' || v_default_value || '))';
    execute 'select test.assert_eq(' || v_default_value || ', json.get_opt_integer(null::' || v_json_type || ', ' || v_default_value || ', ''key''))';
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
