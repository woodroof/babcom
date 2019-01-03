-- drop function data.get_object(integer, integer, data.card_type, integer);

create or replace function data.get_object(in_object_id integer, in_actor_id integer, in_card_type data.card_type, in_actions_object_id integer)
returns jsonb
volatile
as
$$
declare
  v_priority_attribute_id integer := data.get_attribute_id('priority');
  v_attributes jsonb := jsonb '{}';
  v_attribute record;
  v_attribute_json jsonb;
  v_value_description text;
  v_actions_function_attribute_id integer :=
    data.get_attribute_id(case when in_object_id = in_actions_object_id then 'actions_function' else 'list_actions_function' end);
  v_actions_function text;
  v_actions jsonb;
  v_template jsonb := data.get_param('template');
  v_object jsonb;
  v_list jsonb;
begin
  assert in_object_id is not null;
  assert in_actor_id is not null;
  assert in_card_type is not null;

  -- Получаем видимые и hidden-атрибуты для указанной карточки
  for v_attribute in
    select
      a.id,
      a.code,
      a.name,
      case when a.type = 'hidden' then true else false end as hidden,
      attr.value,
      a.value_description_function
    from (
      select
        av.attribute_id,
        av.value,
        case when lag(av.attribute_id) over (partition by av.object_id, av.attribute_id order by json.get_integer_opt(pr.value, 0) desc) is null then true else false end as needed
      from data.attribute_values av
      left join data.object_objects oo on
        av.value_object_id = oo.parent_object_id and
        oo.object_id = in_actor_id
      left join data.attribute_values pr on
        pr.object_id = av.value_object_id and
        pr.attribute_id = v_priority_attribute_id and
        pr.value_object_id is null
      where
        av.object_id = in_object_id and
        (
          av.value_object_id is null or
          oo.id is not null
        )
    ) attr
    join data.attributes a
      on a.id = attr.attribute_id
      and (a.card_type is null or a.card_type = in_card_type)
      and a.type != 'system'
      and attr.needed = true
    order by a.code
  loop
    v_attribute_json := jsonb '{}';
    if v_attribute.value_description_function is not null then
      execute format('select %s($1, $2, $3)', v_attribute.value_description_function)
      using v_attribute.id, v_attribute.value, in_actor_id
      into v_value_description;

      if v_value_description is not null then
        v_attribute_json := v_attribute_json || jsonb_build_object('value_description', v_value_description);
      end if;
    end if;

    if v_attribute.name is not null then
      v_attribute_json := v_attribute_json || jsonb_build_object('name', v_attribute.name, 'value', v_attribute.value, 'hidden', v_attribute.hidden);
    else
      v_attribute_json := v_attribute_json || jsonb_build_object('value', v_attribute.value, 'hidden', v_attribute.hidden);
    end if;

    v_attributes := v_attributes || jsonb_build_object(v_attribute.code, v_attribute_json);
  end loop;

  -- Получаем действия объекта
  select json.get_string_opt(value, null)
  into v_actions_function
  from data.attribute_values
  where
    object_id = in_actions_object_id and
    attribute_id = v_actions_function_attribute_id and
    value_object_id is null;

  if v_actions_function is not null then
    if in_object_id = in_actions_object_id then
      execute format('select %s($1, $2)', v_actions_function)
      using in_object_id, in_actor_id
      into v_actions;
    else
      execute format('select %s($1, $2, $3)', v_actions_function)
      using in_actions_object_id, in_object_id, in_actor_id
      into v_actions;
    end if;
  end if;

  -- Отфильтровываем из шаблона лишнее
  v_template := data.filter_template(v_template, v_attributes, v_actions);

  v_object :=
    jsonb_build_object('id', in_object_id, 'attributes', coalesce(v_attributes, jsonb '{}'), 'actions', coalesce(v_actions, jsonb '{}'), 'template', v_template);

  if v_attributes ? 'content' then
    assert in_card_type = 'full';

    v_list := data.get_next_list(in_client_id, in_object_id);
    return jsonb_build_object('object', v_object, 'list', v_list);
  end if;

  return jsonb_build_object('object', v_object);
end;
$$
language 'plpgsql';
