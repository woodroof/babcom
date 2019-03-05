-- drop function pallas_project.act_customs_find_by_status_or_from(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_customs_find_by_status_or_from(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_package_from text := json.get_string_opt(in_user_params, 'package_from', null);
  v_package_to_status integer := json.get_integer_opt(in_user_params, 'package_to_status', null);
  v_content text[];
  v_temp_object_id integer;
  v_package_class_id integer := data.get_class_id('package');
  v_package_from_attribute_id integer = data.get_attribute_id('package_from');
  v_package_receiver_status_attribute_id integer = data.get_attribute_id('package_receiver_status');
  v_system_customs_checking boolean := json.get_boolean_opt(data.get_attribute_value_for_share('customs_new', 'system_customs_checking'), false);
begin
  assert in_request_id is not null;

  if v_package_from = '' then
    v_package_from := null;
  end if;
  if v_package_to_status = '-1' then
    v_package_to_status := null;
  end if;
  if v_package_from is null and v_package_to_status is null then
    perform api_utils.create_show_message_action_notification(
      in_client_id,
      in_request_id,
      'Нужно больше данных для поиска',
      'Хотя бы один из параметров должен быть конкретизирован.'); 
    return;
  end if;

  select array_agg(o.code) into v_content
  from data.objects o
  left join data.attribute_values av1 on av1.object_id = o.id and av1.attribute_id = v_package_from_attribute_id
  left join data.attribute_values av2 on av2.object_id = o.id and av2.attribute_id = v_package_receiver_status_attribute_id
  where (v_package_from is null or json.get_string(av1.value) = v_package_from)
    and (v_package_to_status is null or json.get_integer(av2.value) = v_package_to_status)
    and o.class_id = v_package_class_id;

  if v_content is null then
    v_content := array[]::text[];
  end if;
  -- создаём темповый список
  v_temp_object_id := data.create_object(
  null,
  jsonb_build_array(
    jsonb_build_object('code', 'description', 'value', 'Результат поиска по месту отправки ' || coalesce(v_package_from, 'Все') || ' и статусу получателя ' ||
      case v_package_to_status when 3 then 'Золотой' when 2 then 'Серебряный' when 1 then 'Бронзовый' when 0 then 'Нет' else 'Все' end),
    jsonb_build_object('code', 'system_customs_checking', 'value', v_system_customs_checking),
    jsonb_build_object('code', 'content', 'value', v_content)
  ),
  'customs_package_list');

  perform api_utils.create_open_object_action_notification(in_client_id, in_request_id, data.get_object_code(v_temp_object_id));
end;
$$
language plpgsql;
