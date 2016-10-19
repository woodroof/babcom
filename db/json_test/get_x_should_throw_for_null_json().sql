-- Function: json_test.get_x_should_throw_for_null_json()

-- DROP FUNCTION json_test.get_x_should_throw_for_null_json();

CREATE OR REPLACE FUNCTION json_test.get_x_should_throw_for_null_json()
  RETURNS void AS
$BODY$
declare
  v_json_type text;
  v_type text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_type in array array ['array', 'bigint', 'boolean', 'integer', 'object'] loop
      perform test.assert_throw(
        'select json.get_' || v_type || '(null::' || v_json_type || ')',
        'Json is not a%');
    end loop;
    foreach v_type in array array ['array', 'bigint', 'boolean', 'integer', 'object'] loop
      perform test.assert_throw(
        'select json.get_' || v_type || '(null::' || v_json_type || ', ''key3'')',
        '%key3%not found');
    end loop;
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
