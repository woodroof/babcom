-- drop function pallas_project.act_customs_find_by_number(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_customs_find_by_number(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_package_number text := json.get_string(in_user_params, 'package_number');
  v_content text[];
  v_temp_object_id integer;
  v_package_class_id integer := data.get_class_id('package');
  v_system_customs_checking boolean := json.get_boolean_opt(data.get_attribute_value_for_share('customs_new', 'system_customs_checking'), false);
begin
  assert in_request_id is not null;

  select array_agg(o.code) into v_content
  from data.objects o
  where upper(replace(o.code, '-', '')) like upper(v_package_number) || '%'
    and o.class_id = v_package_class_id;
  if v_content is null then
    v_content := array[]::text[];
  end if;
  -- создаём темповый список
  v_temp_object_id := data.create_object(
  null,
  jsonb_build_array(
    jsonb_build_object('code', 'description', 'value', 'Результат поиска по номеру ' || v_package_number),
    jsonb_build_object('code', 'system_customs_checking', 'value', v_system_customs_checking),
    jsonb_build_object('code', 'content', 'value', v_content)
  ),
  'customs_package_list');

  perform api_utils.create_open_object_action_notification(in_client_id, in_request_id, data.get_object_code(v_temp_object_id));
end;
$$
language plpgsql;
