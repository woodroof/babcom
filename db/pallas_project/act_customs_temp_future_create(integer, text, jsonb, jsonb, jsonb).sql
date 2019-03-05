-- drop function pallas_project.act_customs_temp_future_create(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_customs_temp_future_create(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_ships_count integer := json.get_integer(in_user_params, 'ships_count');
  v_package_from text := json.get_string(in_user_params, 'package_from');
  v_package_box text :=  json.get_string(in_user_params, 'package_box');
  v_package_to text := json.get_string(in_params, 'package_to');
  v_package_reactions text[] := json.get_string_array(in_params, 'package_reactions');

  v_random_reactions text[];

  v_package_receiver_status integer := json.get_integer_opt(data.get_attribute_value(v_package_to, 'system_person_administrative_services_status'), 0);

  v_goods jsonb := data.get_param('customs_goods');
  v_goods_array text[];
  v_goods_array_length integer;

  v_good_id integer;
  v_package_id integer;
  v_package_code text;
  v_receiver_code text;
  v_customs_id integer := data.get_object_id('customs_future');
  v_content text[] := json.get_string_array(data.get_raw_attribute_value_for_update(v_customs_id, 'content', null));
begin
  select array_agg(x) into v_goods_array from jsonb_object_keys(v_goods) as x;
  v_goods_array_length := array_length(v_goods_array, 1);
  v_package_code := pgcrypto.gen_random_uuid()::text;
  v_receiver_code := UPPER(substr(pgcrypto.gen_random_uuid()::text, 1, 6));
  select coalesce(array_agg(y.x), array[]::text[]) into v_package_reactions from (select x from unnest(v_package_reactions) as x order by 1) y;

  v_good_id := random.random_integer(1, v_goods_array_length);
  v_random_reactions := json.get_string_array(v_goods, v_goods_array[v_good_id]);
  select coalesce(array_agg(y.x), array[]::text[]) into v_random_reactions from (select x from unnest(v_random_reactions) as x order by 1) y;
  while v_package_reactions = v_random_reactions loop
    v_good_id := random.random_integer(1, v_goods_array_length);
    v_random_reactions := json.get_string_array(v_goods, v_goods_array[v_good_id]);
    select coalesce(array_agg(y.x), array[]::text[]) into v_random_reactions from (select x from unnest(v_random_reactions) as x order by 1) y;
  end loop;

  v_package_id := data.create_object(
    v_package_code,
    jsonb_build_array(
      jsonb_build_object('code', 'title', 'value', substr(replace(upper(v_package_code), '-', ''), 1, 9)),
      jsonb_build_object('code', 'package_from', 'value', v_package_from),
      jsonb_build_object('code', 'package_what', 'value', v_goods_array[v_good_id]),
      jsonb_build_object('code', 'package_receiver_status', 'value', v_package_receiver_status),
      jsonb_build_object('code', 'system_package_receiver_code', 'value', v_receiver_code),
      jsonb_build_object('code', 'package_receiver_code', 'value', v_receiver_code, 'value_object_code', 'master'),
      jsonb_build_object('code', 'package_weight', 'value', random.random_integer(1, 50)),
      jsonb_build_object('code', 'package_status', 'value', 'new'),
      jsonb_build_object('code', 'system_package_reactions', 'value', v_package_reactions),
      jsonb_build_object('code', 'package_reactions', 'value', v_package_reactions, 'value_object_code', 'master'),
      jsonb_build_object('code', 'system_package_to', 'value', v_package_to),
      jsonb_build_object('code', 'package_to', 'value', v_package_to, 'value_object_code', 'master'),
      jsonb_build_object('code', 'package_ships_before_come', 'value', v_ships_count, 'value_object_code', 'master'),
      jsonb_build_object('code', 'system_package_box_code', 'value', v_package_box),
      jsonb_build_object('code', 'package_box_code', 'value', v_package_box, 'value_object_code', 'master')
    ),
    'package');
  v_content := array_prepend(v_package_code, v_content);

  perform data.change_object_and_notify(v_customs_id, jsonb_build_array(data.attribute_change2jsonb('content', to_jsonb(v_content))));
  perform api_utils.create_go_back_action_notification(in_client_id, in_request_id);
end;
$$
language plpgsql;
