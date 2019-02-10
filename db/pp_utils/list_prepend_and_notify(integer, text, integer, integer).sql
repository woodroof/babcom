-- drop function pp_utils.list_prepend_and_notify(integer, text, integer, integer);

create or replace function pp_utils.list_prepend_and_notify(in_list_id integer, in_new_object_code text, in_value_object_id integer, in_actor_id integer default null::integer)
returns void
volatile
as
$$
declare
  v_content_attribute_id integer := data.get_attribute_id('content');

  v_content text[];
  v_new_content text[];
  v_actor_id integer := coalesce(in_actor_id, in_value_object_id);
begin
  -- Блокируем список
  perform * from data.objects where id = in_list_id for update;

  -- Достаём, меняем, кладём назад
  v_content := json.get_string_array_opt(data.get_attribute_value(in_list_id, 'content', v_actor_id), array[]::text[]);
  v_new_content := array_prepend(in_new_object_code, v_content);
  if v_new_content <> v_content then
    perform data.change_object_and_notify(in_list_id, 
                                          jsonb_build_array(data.attribute_change2jsonb(v_content_attribute_id, to_jsonb(v_new_content), in_value_object_id)),
                                          v_actor_id);
  end if;
end;
$$
language plpgsql;
