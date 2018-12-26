-- drop function api_utils.process_get_actors_message(integer, text);

create or replace function api_utils.process_get_actors_message(in_client_id integer, in_request_id text)
returns void
volatile
as
$$
declare
  v_login_id integer;
  v_actor_id integer;
  v_actor_function text;
  v_title text;
  v_subtitle text;
  v_actors jsonb[];
begin
  assert in_request_id is not null;

  select login_id
  into v_login_id
  from data.clients
  where id = in_client_id
  for update;

  if v_login_id is null then
    v_login_id := data.get_integer_param('default_login_id');
    assert v_login_id is not null;

    update data.clients
    set login_id = v_login_id
    where id = in_client_id;
  end if;

  for v_actor_id in
    select actor_id
    from data.login_actors
    where login_id = v_login_id
    order by priority desc
  loop
    v_actor_function := json.get_string_opt(data.get_attribute_value(v_actor_id, 'actor_function'), null);

    if v_actor_function is not null then
      execute format('select %s($1)', v_actor_function)
      using v_actor_id;
    end if;

    v_title := json.get_string_opt(data.get_attribute_value(v_actor_id, 'title', v_actor_id));
    v_subtitle := json.get_string_opt(data.get_attribute_value(v_actor_id, 'subtitle', v_actor_id));

    v_actors :=
      array_append(
        v_actors,
        (
          jsonb_build_object('id', v_actor_id) ||
          case when v_title is not null then jsonb_build_object('title', v_title) else jsonb '{}' end ||
          case when v_subtitle is not null then jsonb_build_object('subtitle', v_subtitle) else jsonb '{}' end
        ));
  end loop;

  assert v_actors is not null;

  perform api_utils.create_notification(in_client_id, in_request_id, 'actors', jsonb_build_object('actors', jsonb_build_object(v_actors)));
end;
$$
language 'plpgsql';