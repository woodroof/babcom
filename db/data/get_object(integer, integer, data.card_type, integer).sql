-- drop function data.get_object(integer, integer, data.card_type, integer);

create or replace function data.get_object(in_object_id integer, in_actor_id integer, in_card_type data.card_type, in_actions_object_id integer)
returns jsonb
volatile
as
$$
declare
  v_object_data jsonb := data.get_object_data(in_object_id, in_actor_id, in_card_type, in_actions_object_id);
  v_attributes jsonb := json.get_object(v_object_data, 'attributes');
  v_actions jsonb := json.get_object_opt(v_object_data, 'actions', null);
  v_template jsonb :=
    json.get_object_opt(
      (
        case when in_card_type = 'full' then
          data.get_attribute_value(in_object_id, 'template', in_actor_id)
        else
          coalesce(
            data.get_attribute_value(in_object_id, 'mini_card_template', in_actor_id),
            data.get_attribute_value(in_object_id, 'template', in_actor_id))
        end
      ),
      null);
begin
  if v_template is null then
    v_template := data.get_param('template');
  end if;

  -- Отфильтровываем из шаблона лишнее
  v_template := data.filter_template(v_template, v_attributes, v_actions);

  return jsonb_build_object('id', data.get_object_code(in_object_id), 'attributes', v_attributes, 'actions', coalesce(v_actions, jsonb '{}'), 'template', v_template);
end;
$$
language plpgsql;
