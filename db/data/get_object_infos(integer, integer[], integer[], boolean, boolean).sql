-- Function: data.get_object_infos(integer, integer[], integer[], boolean, boolean)

-- DROP FUNCTION data.get_object_infos(integer, integer[], integer[], boolean, boolean);

CREATE OR REPLACE FUNCTION data.get_object_infos(
    in_user_object_id integer,
    in_object_ids integer[],
    in_attribute_ids integer[],
    in_get_actions boolean,
    in_get_templates boolean)
  RETURNS data.object_info[] AS
$BODY$
declare
  v_system_priority_attr_id integer := data.get_attribute_id('system_priority');
  v_ret_val data.object_info[];
begin
  assert in_user_object_id is not null;
  assert in_object_ids is not null;
  assert in_attribute_ids is not null;
  assert in_get_actions is not null;
  assert in_get_templates is not null;

  -- TODO: add actions

  select array_agg(value)
  from
  (
    select row(o.code, oi.attribute_codes, oi.attribute_names, oi.attribute_values, data.get_attribute_values_descriptions(in_user_object_id, oi.attribute_ids, oi.attribute_values, oi.attribute_value_description_functions), oi.attribute_types)::data.object_info as value
    from data.objects o
    left join (
      select
        oi.object_id,
        array_agg(a.id) attribute_ids,
        array_agg(a.code) attribute_codes,
        array_agg(a.name) attribute_names,
        array_agg(oi.value) attribute_values,
        array_agg(a.type) attribute_types,
        array_agg(a.value_description_function) attribute_value_description_functions
      into v_ret_val
      from (
        select
          object_id,
          attribute_id,
          value,
          rank() over (partition by object_id, attribute_id order by json.get_opt_integer(priority, 0) desc) as rank
        from (
          select
            av.object_id,
            av.attribute_id,
            av.value,
            pr.value priority
          from data.attribute_values av
          left join data.object_objects oo on
            av.value_object_id = oo.parent_object_id and
            oo.object_id = in_user_object_id
          left join data.attribute_values pr on
            pr.object_id = av.value_object_id and
            pr.attribute_id = v_system_priority_attr_id and
            pr.value_object_id is null
          where
            av.object_id = any(in_object_ids) and
            av.attribute_id = any(in_attribute_ids) and
            (
              av.value_object_id is null or
              oo.id is not null
            )
        ) oi
      ) oi
      join data.attributes a on
        a.id = oi.attribute_id and
        oi.rank = 1
      group by oi.object_id
    ) oi on
      o.id = oi.object_id
    join (
      select row_number() over() sort_order, id
      from (
        select unnest(in_object_ids) as id
      ) a
    ) a on
      a.id = o.id
    where o.id = any(in_object_ids)
    order by a.sort_order
  ) o;

  return v_ret_val;
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
