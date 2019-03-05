-- drop function pallas_project.act_customs_create_future_package(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_customs_create_future_package(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_content text[];
  v_title_attribute_id integer := data.get_attribute_id('title');
  v_temp_object_id integer;
begin
  assert in_request_id is not null;

  select array_agg(o.code order by av.value) into v_content
  from data.object_objects oo
    left join data.objects o on o.id = oo.object_id
    left join data.attribute_values av on av.object_id = o.id and av.attribute_id = v_title_attribute_id and av.value_object_id is null
  where oo.parent_object_id = data.get_object_id('player')
    and oo.object_id <> oo.parent_object_id;
  if v_content is null then
    v_content := array[]::text[];
  end if;

  v_content := array_prepend('check_metal', v_content);
  v_content := array_prepend('check_radiation', v_content);
  v_content := array_prepend('check_life', v_content);
  -- создаём темповый список
  v_temp_object_id := data.create_object(
  null,
  jsonb_build_array(
    jsonb_build_object('code', 'content', 'value', v_content)
  ),
  'customs_temp_future');

  perform api_utils.create_open_object_action_notification(in_client_id, in_request_id, data.get_object_code(v_temp_object_id));
end;
$$
language plpgsql;
