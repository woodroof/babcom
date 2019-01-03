-- drop function data.filter_template(jsonb, jsonb, jsonb);

create or replace function data.filter_template(in_template jsonb, in_attributes jsonb, in_actions jsonb)
returns jsonb
immutable
as
$$
declare
  v_groups jsonb := json.get_array(json.get_object(in_template), 'groups');
  v_group jsonb;
  v_attribute_name text;
  v_action_name text;
  v_name text;
  v_filtered_group jsonb;
  v_filtered_groups jsonb[];
  v_filtered_attributes text[];
  v_filtered_actions text[];
begin
  assert json.get_object(in_attributes) is not null;

  for v_group in
    select value
    from jsonb_array_elements(v_groups)
  loop
    -- Фильтруем атрибуты
    v_filtered_attributes := null;

    if v_group ? 'attributes' then
      for v_attribute_name in
        select json.get_string(value)
        from jsonb_array_elements(json.get_array(v_group, 'attributes'))
      loop
        if in_attributes ? v_attribute_name then
          v_filtered_attributes := array_append(v_filtered_attributes, v_attribute_name);
        end if;
      end loop;
    end if;

    -- Фильтруем действия
    v_filtered_actions := null;
    if v_group ? 'actions' then
      for v_action_name in
        select json.get_string(value)
        from jsonb_array_elements(json.get_array(v_group, 'actions'))
      loop
        if in_actions ? v_action_name then
          v_filtered_actions := array_append(v_filtered_actions, v_action_name);
        end if;
      end loop;
    end if;

    -- Собираем новую группу
    if v_filtered_attributes is not null or v_filtered_actions is not null then
      v_name = json.get_string_opt(v_group, 'name', null);

      v_filtered_group := jsonb '{}';
      if v_name is not null then
        v_filtered_group := v_filtered_group || jsonb_create_object('name', v_name);
      end if;
      if v_filtered_attributes is not null then
        v_filtered_group := v_filtered_group || jsonb_create_object('attributes', to_jsonb(v_filtered_attributes));
      end if;
      if v_filtered_actions is not null then
        v_filtered_group := v_filtered_group || jsonb_create_object('actions', to_jsonb(v_filtered_actions));
      end if;

      v_filtered_groups := array_append(v_filtered_groups, v_filtered_group);
    end if;
  end loop;

  return jsonb_create_object('groups', to_jsonb(v_filtered_groups));
end;
$$
language 'plpgsql';
