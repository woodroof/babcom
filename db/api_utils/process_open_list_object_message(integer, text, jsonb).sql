-- drop function api_utils.process_open_list_object_message(integer, text, jsonb);

create or replace function api_utils.process_open_list_object_message(in_client_id integer, in_request_id text, in_message jsonb)
returns void
volatile
as
$$
declare
  v_object_code text := json.get_string(in_message, 'object_id');
  v_list_object_code text := json.get_string(in_message, 'list_object_id');
  v_object_id integer := data.get_object_id(v_object_code);
  v_list_object_id integer := data.get_object_id(v_list_object_code);
  v_content text[];
  v_is_visible boolean;
  v_actor_id integer;
  v_list_element_function text;
begin
  assert in_client_id is not null;
  assert data.is_instance(v_object_id);
  assert data.is_instance(v_list_object_id);

  select actor_id
  into v_actor_id
  from data.clients
  where id = in_client_id
  for share;

  if v_actor_id is null then
    raise exception 'Client % has no active actor', in_client_id;
  end if;

  v_content := json.get_string_array(data.get_attribute_value(v_object_id, 'content', v_actor_id));

  if array_position(v_content, v_list_object_code) is null then
    raise exception 'Object % has no list object %', v_object_code, v_list_object_code;
  end if;

  v_is_visible := json.get_boolean(data.get_attribute_value(v_list_object_id, 'is_visible', v_actor_id));

  if not v_is_visible then
    raise exception 'List object % is not visible', v_list_object_code;
  end if;

  -- Вызываем функцию открытия элемента списка, если есть
  v_list_element_function := json.get_string_opt(data.get_attribute_value(v_object_id, 'list_element_function'), null);

  if v_list_element_function is not null then
    execute format('select %s($1, $2, $3, $4)', v_list_element_function)
    using in_client_id, in_request_id, v_object_id, v_list_object_id;
  else
    perform api_utils.create_open_object_action_notification(
      in_client_id,
      in_request_id,
      v_list_object_code);
  end if;
end;
$$
language plpgsql;
