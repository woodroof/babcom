-- Function: api_utils.get_operation(text)

-- DROP FUNCTION api_utils.get_operation(text);

CREATE OR REPLACE FUNCTION api_utils.get_operation(in_operation_name text)
  RETURNS text AS
$BODY$
begin
  case when in_operation_name = 'lt' then
    return '<';
  when in_operation_name = 'le' then
    return '<=';
  when in_operation_name = 'gt' then
    return '>';
  when in_operation_name = 'ge' then
    return '>=';
  when in_operation_name = 'eq' then
    return '=';
  when in_operation_name = 'ne' then
    return '!=';
  end case;

  perform utils.raise_invalid_input_param_value('Invalid operation "%s"', in_operation_name);
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;
