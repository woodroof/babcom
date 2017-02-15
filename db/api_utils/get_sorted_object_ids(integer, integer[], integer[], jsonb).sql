-- Function: api_utils.get_sorted_object_ids(integer, integer[], integer[], jsonb)

-- DROP FUNCTION api_utils.get_sorted_object_ids(integer, integer[], integer[], jsonb);

CREATE OR REPLACE FUNCTION api_utils.get_sorted_object_ids(
    in_user_object_id integer,
    in_object_ids integer[],
    in_filled_attributes_ids integer[],
    in_params jsonb)
  RETURNS api_utils.objects_process_result AS
$BODY$
declare
  v_sort_params jsonb;
  v_object_ids integer[];
  v_attribute_ids integer[];
begin
  assert in_user_object_id is not null;
  assert in_object_ids is not null;
  assert in_filled_attributes_ids is not null;
  assert in_params is not null;

  if not (in_params ? 'sort') then
    return row(in_object_ids, in_filled_attributes_ids);
  end if;

  v_sort_params := json.get_object_array(in_params, 'sort');

  declare
    v_sort_params_len integer;
    v_sort_param jsonb;
    v_type text;
    v_ordered_by_code boolean := false;
    v_attribute_code text;
    v_attribute_id integer;
    v_attributes text[];
    v_order_conditions text[];
    v_query text;
    v_attribute text;
    v_order_condition text;
  begin
    v_sort_params_len := jsonb_array_length(v_sort_params);

    for i in 0 .. v_sort_params_len - 1 loop
      v_sort_param := v_sort_params->i;
      v_type := json.get_string(v_sort_param, 'type');

      if v_type not in ('asc', 'desc') then
        raise invalid_parameter_value;
      end if;

      v_attribute_code := json.get_opt_string(v_sort_param, null, 'attribute_code');

      if v_attribute_code is null then
        v_attributes := v_attributes || ('utils.integer_array_idx($1, o.id) a' || i);
        v_order_conditions := v_order_conditions || ('a' || i || ' ' || v_type);
        v_ordered_by_code := true;
        exit;
      else
        v_attribute_id := data.get_attribute_id(v_attribute_code);

        if data.is_system_attribute(v_attribute_id) then
          raise invalid_parameter_value;
        end if;

        if v_attribute_id != any(in_filled_attributes_ids) then
          v_attribute_ids := v_attribute_ids || v_attribute_id;
        end if;

        v_attributes := v_attributes || ('data.get_attribute_value(' || in_user_object_id  || ', o.id, ' || v_attribute_id || ') a' || i);
        v_order_conditions := v_order_conditions || ('a' || i || ' ' || v_type);
      end if;
    end loop;

    if not v_ordered_by_code then
      v_attributes := v_attributes || ('utils.integer_array_idx($1, o.id) a' || v_sort_params_len);
        v_order_conditions := v_order_conditions || ('a' || v_sort_params_len || ' asc');
    end if;

    if v_attribute_ids is not null then
      perform data.fill_attribute_values(in_user_object_id, in_object_ids, v_attribute_ids);
    end if;

    v_query := 'select array_agg(o.id) from (select o.id';
    foreach v_attribute in array v_attributes loop
      v_query := v_query || ', ' || v_attribute;
    end loop;

    v_query := v_query || ' from data.objects o where o.id = any($1) order by ';
    foreach v_order_condition in array v_order_conditions loop
      v_query := v_query || v_order_condition || ', ';
    end loop;
    v_query := v_query || 'o.code asc) o';

    execute v_query
    using in_object_ids
    into v_object_ids;
  exception when invalid_parameter_value then
    perform utils.raise_invalid_input_param_value('Invalid sort params');
  end;

  return row(v_object_ids, in_filled_attributes_ids || v_attribute_ids);
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
