-- drop function api_utils.process_get_actors_message(integer, text);

create or replace function api_utils.process_get_actors_message(in_client_id integer, in_request_id text)
returns void
volatile
as
$$
declare
  v_login_id integer;
  v_actor_function text;
  v_actor record;
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

  for v_actor_function in
    select json.get_string_opt(data.get_attribute_value(v_actor_id, 'actor_function'), null) as actor_function
    from data.login_actors
    where
      login_id = v_login_id and
      actor_function is not null
  loop
    execute format('select %s($1)', v_actor_function)
    using v_actor_id;
  end loop;

  for v_actor in
    select
      actor_id as id,
      json.get_string_opt(data.get_attribute_value(actor_id, 'title', actor_id), null) as title,
      json.get_string_opt(data.get_attribute_value(v_actor_id, 'subtitle', v_actor_id), null) as subtitle
    from data.login_actors
    where login_id = v_login_id
    order by title
  loop
    v_actors :=
      array_append(
        v_actors,
        (
          jsonb_build_object('id', v_actor.id) ||
          case when v_actor.title is not null then jsonb_build_object('title', v_actor.title) else jsonb '{}' end ||
          case when v_actor.subtitle is not null then jsonb_build_object('subtitle', v_actor.subtitle) else jsonb '{}' end
        ));
  end loop;

  assert v_actors is not null;

  perform api_utils.create_notification(in_client_id, in_request_id, 'actors', jsonb_build_object('actors', jsonb_build_array(v_actors)));
end;
$$
language 'plpgsql';
