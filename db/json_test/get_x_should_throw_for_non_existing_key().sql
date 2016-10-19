-- Function: json_test.get_x_should_throw_for_non_existing_key()

-- DROP FUNCTION json_test.get_x_should_throw_for_non_existing_key();

CREATE OR REPLACE FUNCTION json_test.get_x_should_throw_for_non_existing_key()
  RETURNS void AS
$BODY$
declare
  v_json text := '''{"key1": "value1", "key2": 2}''';
  v_json_type text;
  v_type text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_type in array array ['array', 'bigint', 'boolean', 'integer', 'object'] loop
      perform test.assert_throw(
        'select json.get_' || v_type || '(' || v_json || '::' || v_json_type || ', ''key3'')',
        '%key3%not found');
    end loop;
  end loop;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
