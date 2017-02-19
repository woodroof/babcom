-- Function: attribute_value_description_functions.codes(integer, integer, jsonb)

-- DROP FUNCTION attribute_value_description_functions.codes(integer, integer, jsonb);

CREATE OR REPLACE FUNCTION attribute_value_description_functions.codes(
    in_user_object_id integer,
    in_attribute_id integer,
    in_value jsonb)
  RETURNS text AS
$BODY$
declare
  v_attribute_name_id integer := data.get_attribute_id('name');
  v_object_codes text[] := json.get_string_array(in_value);
  v_ret_val text;
begin
  select
    string_agg(
      coalesce(
        json.get_opt_string(
          data.get_attribute_value(in_user_object_id, o.id, v_attribute_name_id)),
        'Инкогнито'),
      ', ')
  into v_ret_val
  from data.objects o
  where o.code = any(v_object_codes);

  return v_ret_val;
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
