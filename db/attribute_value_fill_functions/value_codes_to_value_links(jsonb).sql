-- Function: attribute_value_fill_functions.value_codes_to_value_links(jsonb)

-- DROP FUNCTION attribute_value_fill_functions.value_codes_to_value_links(jsonb);

CREATE OR REPLACE FUNCTION attribute_value_fill_functions.value_codes_to_value_links(in_params jsonb)
  RETURNS void AS
$BODY$
declare
  v_user_object_id integer := json.get_integer(in_params, 'user_object_id');
  v_object_id integer := json.get_integer(in_params, 'object_id');
  v_attribute_id integer := json.get_integer(in_params, 'attribute_id');
  v_source_attribute_id integer := data.get_attribute_id(json.get_string(in_params, 'attribute_code'));
  v_placeholder text := json.get_opt_string(in_params, null, 'placeholder');
  v_name_attribute_id integer := data.get_attribute_id('name');

  v_codes jsonb;
  v_ids integer[];
  v_value jsonb;
begin
  select value
  into v_codes
  from data.attribute_values
  where
    object_id = v_object_id and
    attribute_id = v_source_attribute_id and
    value_object_id = v_user_object_id
  for share;

  if v_codes is not null then
    select array_agg(id)
    into v_ids
    from data.objects
    where
      code in (
        select json.get_string(value)
        from jsonb_array_elements(v_codes)
      );
  end if;

  if v_codes is not null then
    perform data.fill_attribute_values(v_user_object_id, v_ids, array[v_name_attribute_id]);

    select to_jsonb(string_agg('<a href="babcom:' || o.code || '">' || data.get_attribute_value(v_user_object_id, o.id, v_name_attribute_id) || '</a>', '<br>'))
    into v_value
    from jsonb_array_elements(v_codes) c
    join data.objects o on
      o.code = json.get_string(c.value);
  else
    if v_placeholder is not null then
      v_value := to_jsonb(v_placeholder);
    end if;
  end if;

  if v_value is null then
    perform data.delete_attribute_value_if_exists(v_object_id, v_attribute_id, v_user_object_id, v_user_object_id);
  else
    perform data.set_attribute_value_if_changed(v_object_id, v_attribute_id, v_user_object_id, v_value, v_user_object_id);
  end if;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
