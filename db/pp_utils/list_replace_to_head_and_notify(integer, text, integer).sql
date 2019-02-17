-- drop function pp_utils.list_replace_to_head_and_notify(integer, text, integer);

create or replace function pp_utils.list_replace_to_head_and_notify(in_list_id integer, in_object_code text, in_actor_id integer)
returns void
volatile
as
$$
-- Функция перемещает элемент в начало массива
declare
  v_content_attribute_id integer := data.get_attribute_id('content');

  v_content text[];
  v_new_content text[];

begin
  -- Достаём, меняем, кладём назад
  v_content := json.get_string_array_opt(data.get_raw_attribute_value_for_update(in_list_id, 'content', in_actor_id), array[]::text[]);
  v_new_content := array_remove(v_content, in_object_code);
  v_new_content := array_prepend(in_object_code, v_new_content);
  if v_new_content <> v_content then
    perform data.change_object_and_notify(in_list_id,
                                          jsonb_build_array(data.attribute_change2jsonb(v_content_attribute_id, to_jsonb(v_new_content), in_actor_id)),
                                          in_actor_id);
  end if;
end;
$$
language plpgsql;
