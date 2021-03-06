-- drop function pp_utils.list_prepend_and_notify(integer, text, integer, integer);

create or replace function pp_utils.list_prepend_and_notify(in_list_id integer, in_new_object_code text, in_value_object_id integer, in_actor_id integer default null::integer)
returns void
volatile
as
$$
declare
  v_content_attribute_id integer := data.get_attribute_id('content');

  v_content jsonb;
  v_actor_id integer := coalesce(in_actor_id, in_value_object_id);
begin
  assert in_new_object_code is not null;

  -- Достаём, меняем, кладём назад
  v_content := coalesce(data.get_raw_attribute_value_for_update(in_list_id, 'content', in_value_object_id), jsonb '[]');
  v_content := to_jsonb(in_new_object_code) || v_content;
  perform data.change_object_and_notify(
    in_list_id, 
    jsonb '[]' || data.attribute_change2jsonb(v_content_attribute_id, v_content, in_value_object_id),
    v_actor_id);
end;
$$
language plpgsql;
