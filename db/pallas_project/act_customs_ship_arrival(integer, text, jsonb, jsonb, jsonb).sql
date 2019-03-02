-- drop function pallas_project.act_customs_ship_arrival(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_customs_ship_arrival(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_title text;

  v_person_id integer;
  v_login_id integer;

  v_first_names text[] := json.get_string_array(data.get_param('first_names'));
  v_last_names text[] := json.get_string_array(data.get_param('last_names'));

  v_title_attribute_id integer := data.get_attribute_id('title');

  v_goods jsonb := data.get_param('customs_goods');

begin
  assert in_request_id is not null;

  v_title := v_first_names[random.random_integer(1, array_length(v_first_names, 1))] || ' '|| v_last_names[random.random_integer(1, array_length(v_last_names, 1))];
  insert into data.objects(class_id) values(v_person_class_id) returning id into v_person_id;
    -- Логин
  insert into data.logins default values returning id into v_login_id;
  insert into data.login_actors(login_id, actor_id) values(v_login_id, v_person_id);
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_person_id, v_title_attribute_id, to_jsonb(v_title));

  insert into data.object_objects(parent_object_id, object_id) values
  (v_all_person_group_id, v_person_id),
  (v_player_group_id, v_person_id);

  -- Заменим логин
  perform data.set_login(in_client_id, v_login_id);
  -- И отправим новый список акторов
  perform api_utils.process_get_actors_message(in_client_id, in_request_id);
end;
$$
language plpgsql;
