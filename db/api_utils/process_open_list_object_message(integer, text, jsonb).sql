-- drop function api_utils.process_open_list_object_message(integer, text, jsonb);

create or replace function api_utils.process_open_list_object_message(in_client_id integer, in_request_id text, in_message jsonb)
returns void
volatile
as
$$
declare
  v_object_code text := json.get_string(in_message, 'object_id');
  v_list_object_code text := json.get_string(in_message, 'list_object_id');
  v_object_id integer;
  v_list_object_id integer;
  v_content text[];
  v_is_visible boolean;
  v_actor_id integer;
  v_list_element_function text;
begin
  assert in_client_id is not null;

  select actor_id
  into v_actor_id
  from data.clients
  where id = in_client_id
  for update;

  if v_actor_id is null then
    raise exception 'Client % has no active actor', in_client_id;
  end if;

  select id
  into v_object_id
  from data.objects
  where
    code = v_object_code and
    type = 'instance';

  if v_object_id is null then
    raise exception 'Attempt to open list object in non-existing object %', v_object_code;
  end if;

  select id
  into v_list_object_id
  from data.objects
  where
    code = v_list_object_code and
    type = 'instance';

  if v_object_id is null then
    raise exception 'Attempt to open non-existing list object %', v_list_object_code;
  end if;

  v_content := json.get_string_array(data.get_attribute_value(v_object_id, 'content', v_actor_id));

  if array_position(v_content, v_list_object_code) is null then
    raise exception 'Object % has no list object %', v_object_code, v_list_object_code;
  end if;

  v_is_visible := json.get_boolean(data.get_attribute_value(v_list_object_id, 'is_visible', v_actor_id));

  if v_is_visible is false then
    raise exception 'List object % is not visible', v_list_object_code;
  end if;

  -- Вызываем функцию открытия элемента списка, если есть
  v_list_element_function := json.get_string_opt(data.get_attribute_value(v_object_id, 'list_element_function'), null);

  if v_list_element_function is not null then
    execute format('select %s($1, $2, $3, $4)', v_list_element_function)
    using in_client_id, in_request_id, v_object_id, v_list_object_id;
  else
    perform api_utils.create_notification(
      in_client_id,
      in_request_id,
      'action',
      jsonb_build_object('action', 'open_object', 'action_data', jsonb_build_object('object_id', v_list_object_code)));
  end if;
end;
$$
language 'plpgsql';
