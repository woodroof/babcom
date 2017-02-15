-- Function: api_utils.get_filtered_object_ids(integer, text[], jsonb)

-- DROP FUNCTION api_utils.get_filtered_object_ids(integer, text[], jsonb);

CREATE OR REPLACE FUNCTION api_utils.get_filtered_object_ids(
    in_user_object_id integer,
    in_object_codes text[],
    in_params jsonb)
  RETURNS api_utils.objects_process_result AS
$BODY$
declare
  v_filters jsonb;

  v_system_is_visibile_attribute_id integer := data.get_attribute_id('system_is_visible');

  v_object_codes_to_remove text[];
  v_attribute_ids integer[];
  v_conditions text[];

  v_filtered_object_codes text[];
  v_filtered_object_ids integer[];
begin
  assert in_user_object_id is not null;
  assert in_object_codes is not null;
  assert in_params is not null;

  if in_params ? 'filters' then
    v_filters := json.get_object_array(in_params, 'filters');

    declare
      v_filter jsonb;
      v_code text;
      v_filters_len integer;
      v_type text;
      v_attribute_id integer;
      v_condition text;
    begin
      v_filters_len := jsonb_array_length(v_filters);

      for i in 0 .. v_filters_len - 1 loop
        v_filter := v_filters->i;
        v_type := json.get_string(v_filter, 'type');

        if v_type = 'code not in' then
          v_object_codes_to_remove := v_object_codes_to_remove || json.get_string_array(v_filter, 'data');
        elsif v_type = 'after' then
          v_code := json.get_string(v_filter, 'data');
          in_object_codes := utils.string_array_after(in_object_codes, v_code);
        else
          v_attribute_id :=
            data.get_attribute_id(
              json.get_string(v_filter, 'attribute_code'));

          if data.is_system_attribute(v_attribute_id) then
            raise invalid_parameter_value;
          end if;

          v_attribute_ids := v_attribute_ids || v_attribute_id;

          v_condition := 'exists(select 1 from data.attribute_values where object_id = o.id and attribute_id = ' || v_attribute_id || ' and ';

          case when v_type = 'mask' then
            v_condition := v_condition || 'json.get_if_string(value) like ''' || replace(json.get_string(v_filter, 'data'), '''', '''''') || ''')';
          when v_type = 'contains one of' then
            v_condition := v_condition || 'exists(select 1 from jsonb_array_elements(json.get_if_array(value)) where ''' || to_json(json.get_array(v_filter, 'data')) || '''::jsonb @> value))';
          else
            if jsonb_typeof(v_filter->'data') = 'string' then
              v_condition := v_condition || 'json.get_if_string(value) ' || api_utils.get_operation(v_type) || ' ''' || replace(json.get_string(v_filter, 'data'), '''', '''''') || ''')';
            else
              v_condition := v_condition || 'json.get_if_integer(value) ' || api_utils.get_operation(v_type) || ' ''' || json.get_integer(v_filter, 'data') || ''')';
            end if;
          end case;

          v_conditions := v_conditions || v_condition;
        end if;
      end loop;
    exception when invalid_parameter_value then
      perform utils.raise_invalid_input_param_value('Invalid filters');
    end;
  end if;

  if v_object_codes_to_remove is not null then
    declare
      v_object_code text;
      v_object_code_to_remove text;
    begin
      foreach v_object_code in array in_object_codes loop
        if v_object_code != any(v_object_codes_to_remove) then
          v_filtered_object_codes := v_filtered_object_codes || v_object_code;
        end if;
      end loop;
    end;
  else
    v_filtered_object_codes := in_object_codes;
  end if;

  select array_agg(id)
  into v_filtered_object_ids
  from (
    select id
    from data.objects
    where code = any(v_filtered_object_codes)
    order by utils.string_array_idx(v_filtered_object_codes, code)
  ) s;

  if v_filtered_object_ids is null then
    return null;
  end if;

  v_attribute_ids := v_attribute_ids || v_system_is_visibile_attribute_id;

  perform data.fill_attribute_values(in_user_object_id, v_filtered_object_ids, v_attribute_ids);

  declare
    v_query text;
    v_condition text;
  begin
    v_query :=
      'select array_agg(o.id) from data.objects o where o.id = any($1) ' ||
      'and exists(select 1 from data.attribute_values where object_id = o.id and attribute_id = $2 and json.get_if_boolean(value))';

    if v_conditions is not null then
      foreach v_condition in array v_conditions loop
        v_query := v_query || ' and ' || v_condition;
      end loop;
    end if;

    execute v_query
    using v_filtered_object_ids, v_system_is_visibile_attribute_id
    into v_filtered_object_ids;
  end;

  return row(v_filtered_object_ids, v_attribute_ids);
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
