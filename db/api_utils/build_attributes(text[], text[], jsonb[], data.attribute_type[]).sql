-- Function: api_utils.build_attributes(text[], text[], jsonb[], data.attribute_type[])

-- DROP FUNCTION api_utils.build_attributes(text[], text[], jsonb[], data.attribute_type[]);

CREATE OR REPLACE FUNCTION api_utils.build_attributes(
    in_attribute_codes text[],
    in_attribute_names text[],
    in_attribute_values jsonb[],
    in_attribute_types data.attribute_type[])
  RETURNS jsonb AS
$BODY$
declare
  v_size integer := array_length(in_attribute_codes, 1);
  v_ret_val jsonb := '{}';
begin
  if v_size is not null then
    assert array_length(in_attribute_names, 1) = v_size;
    assert array_length(in_attribute_values, 1) = v_size;
    assert array_length(in_attribute_types, 1) = v_size;

    for i in 1..v_size loop
      assert in_attribute_codes[i] is not null;
      assert in_attribute_types[i] != 'SYSTEM';

      v_ret_val := v_ret_val ||
        jsonb_build_object(
          in_attribute_codes[i],
          jsonb_build_object(
            'name', in_attribute_names[i],
            'value', in_attribute_values[i]) ||
          case when in_attribute_types[i] != 'NORMAL' then
            jsonb_build_object(
              'hidden', true)
          else
            jsonb '{}'
          end);
    end loop;
  end if;

  return v_ret_val;
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
