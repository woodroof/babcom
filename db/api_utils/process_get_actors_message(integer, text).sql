-- drop function api_utils.process_get_actors_message(integer, text);

create or replace function api_utils.process_get_actors_message(in_client_id integer, in_request_id text)
returns void
volatile
as
$$
declare
  v_default_template jsonb;
  v_login_id integer;
  v_actor_function record;
  v_actor record;
  v_template jsonb;
  v_title text;
  v_title_attribute_id text;
  v_subtitle text;
  v_subtitle_attribute_id text;
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
    select actor_id, json.get_string_opt(data.get_attribute_value(actor_id, 'actor_function'), null) as actor_function
    from data.login_actors
    where login_id = v_login_id
    for share
  loop
    if v_actor_function is not null then
      execute format('select %s($1)', v_actor_function.actor_function)
      using v_actor_function.actor_id;
    end if;
  end loop;

  for v_actor in
    select
      o.id id,
      o.code as code,
      json.get_object_opt(data.get_attribute_value(la.actor_id, 'template', la.actor_id), null) as template
    from data.login_actors la
    join data.objects o
      on o.id = la.actor_id
    where la.login_id = v_login_id
    order by title
  loop
    v_template := v_actor.template;

    if v_template is null then
      if v_default_template is null then
        v_default_template := data.get_object_param('template');
      end if;
      v_template := v_default_template;
    end if;

    assert v_template is not null;

    if v_template ? 'title' then
      v_title_attribute_id := data.get_attribute_id(json.get_string(v_template, 'title'));

      if data.can_attribute_be_overridden(v_title_attribute_id) then
        v_title := json.get_string_opt(data.get_attribute_value(v_actor.id, v_title_attribute_id), null);
      else
        v_title := json.get_string_opt(data.get_attribute_value(v_actor.id, v_title_attribute_id, v_actor.id), null);
      end if;
    end if;

    if v_template ? 'subtitle' then
      v_subtitle_attribute_id := data.get_attribute_id(json.get_string(v_template, 'subtitle'));

      if data.can_attribute_be_overridden(v_subtitle_attribute_id) then
        v_subtitle := json.get_string_opt(data.get_attribute_value(v_actor.id, v_subtitle_attribute_id), null);
      else
        v_subtitle := json.get_string_opt(data.get_attribute_value(v_actor.id, v_subtitle_attribute_id, v_actor.id), null);
      end if;
    end if;

    v_actors :=
      array_append(
        v_actors,
        (
          jsonb_build_object('id', v_actor.code) ||
          case when v_title is not null then jsonb_build_object('title', v_title) else jsonb '{}' end ||
          case when v_subtitle is not null then jsonb_build_object('subtitle', v_subtitle) else jsonb '{}' end
        ));
  end loop;

  assert v_actors is not null;

  perform api_utils.create_notification(in_client_id, in_request_id, 'actors', jsonb_build_object('actors', to_jsonb(v_actors)));
end;
$$
language plpgsql;
