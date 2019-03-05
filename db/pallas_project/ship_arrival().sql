-- drop function pallas_project.ship_arrival();

create or replace function pallas_project.ship_arrival()
returns void
volatile
as
$$
declare
  v_goods jsonb := data.get_param('customs_goods');
  v_goods_array text[];
  v_goods_array_length integer;

  v_customs_from text[] := json.get_string_array(data.get_param('customs_from'));
  v_customs_from_length integer := array_length(v_customs_from, 1);

  v_i integer;
  v_m integer;
  v_future jsonb;

  v_good_id integer;
  v_packages integer[];
  v_packages0 integer[];
  v_packages1 integer[];
  v_packages2 integer[];
  v_packages3 integer[];
  v_package_id integer;
  v_package_code text;
  v_receiver_code text;
  v_customs_id integer := data.get_object_id('customs_new');
  v_content text[] := json.get_string_array(data.get_raw_attribute_value_for_update(v_customs_id, 'content', null));
  v_person_id integer;
begin
  select array_agg(x) into v_goods_array from jsonb_object_keys(v_goods) as x;
  v_goods_array_length := array_length(v_goods_array, 1);

  v_m := random.random_integer(1, 10);
  for v_i in 1..random.random_integer(10, 15) loop
    v_package_code := pgcrypto.gen_random_uuid()::text;
    v_receiver_code := UPPER(substr(pgcrypto.gen_random_uuid()::text, 1, 6));
    v_good_id := random.random_integer(1, v_goods_array_length);
    v_package_id := data.create_object(
      v_package_code,
      jsonb_build_array(
        jsonb_build_object('code', 'title', 'value', substr(replace(upper(v_package_code), '-', ''), 1, 9)),
        jsonb_build_object('code', 'package_from', 'value', v_customs_from[random.random_integer(1, v_customs_from_length)]),
        jsonb_build_object('code', 'package_what', 'value', v_goods_array[v_good_id]),
        jsonb_build_object('code', 'package_receiver_status', 'value', 0),
        jsonb_build_object('code', 'system_package_receiver_code', 'value', v_receiver_code),
        jsonb_build_object('code', 'package_receiver_code', 'value', v_receiver_code, 'value_object_code', 'master'),
        jsonb_build_object('code', 'package_weight', 'value', random.random_integer(1, 50)),
        jsonb_build_object('code', 'package_arrival_time', 'value', pp_utils.format_date(clock_timestamp())),
        jsonb_build_object('code', 'package_status', 'value', 'new'),
        jsonb_build_object('code', 'system_package_reactions', 'value', json.get_array(v_goods, v_goods_array[v_good_id])),
        jsonb_build_object('code', 'package_reactions', 'value', json.get_array(v_goods, v_goods_array[v_good_id]), 'value_object_code', 'master')
      ),
      'package');
    v_packages0 := array_append(v_packages0, v_package_id);
    v_content := array_prepend(v_package_code, v_content);
    -- Засовываем будущие посылки с 0 статусом
    if v_m = v_i then
     v_future := pallas_project.get_future_packages(0);
     v_packages0 := json.get_integer_array(v_future, 'packages') || v_packages0;
     v_content := json.get_string_array(v_future, 'content') || v_content;
    end if;
  end loop;
  v_packages := v_packages || v_packages0;

  v_m := random.random_integer(1, 35);
  for v_i in 1..random.random_integer(35, 40) loop
    v_package_code := pgcrypto.gen_random_uuid()::text;
    v_receiver_code := UPPER(substr(pgcrypto.gen_random_uuid()::text, 1, 6));
    v_good_id := random.random_integer(1, v_goods_array_length);
    v_package_id := data.create_object(
      v_package_code,
      jsonb_build_array(
        jsonb_build_object('code', 'title', 'value', substr(replace(upper(v_package_code), '-', ''), 1, 9)),
        jsonb_build_object('code', 'package_from', 'value', v_customs_from[random.random_integer(1, v_customs_from_length)]),
        jsonb_build_object('code', 'package_what', 'value', v_goods_array[v_good_id]),
        jsonb_build_object('code', 'package_receiver_status', 'value', 1),
        jsonb_build_object('code', 'system_package_receiver_code', 'value', v_receiver_code),
        jsonb_build_object('code', 'package_receiver_code', 'value', v_receiver_code, 'value_object_code', 'master'),
        jsonb_build_object('code', 'package_weight', 'value', random.random_integer(1, 50)),
        jsonb_build_object('code', 'package_arrival_time', 'value', pp_utils.format_date(clock_timestamp())),
        jsonb_build_object('code', 'package_status', 'value', 'new'),
        jsonb_build_object('code', 'system_package_reactions', 'value', json.get_array(v_goods, v_goods_array[v_good_id])),
        jsonb_build_object('code', 'package_reactions', 'value', json.get_array(v_goods, v_goods_array[v_good_id]), 'value_object_code', 'master')
      ),
      'package');

    v_packages1 := array_append(v_packages1, v_package_id);
    v_content := array_prepend(v_package_code, v_content);
    -- Засовываем будущие посылки с 1 статусом
    if v_m = v_i then
      v_future := pallas_project.get_future_packages(1);
      v_packages1 := json.get_integer_array(v_future, 'packages') || v_packages1;
      v_content := json.get_string_array(v_future, 'content') || v_content;
    end if;
  end loop;
  v_packages :=v_packages || v_packages1;

  v_m := random.random_integer(1, 25);
  for v_i in 1..random.random_integer(25, 30) loop
    v_package_code := pgcrypto.gen_random_uuid()::text;
    v_receiver_code := UPPER(substr(pgcrypto.gen_random_uuid()::text, 1, 6));
    v_good_id := random.random_integer(1, v_goods_array_length);
    v_package_id := data.create_object(
      v_package_code,
      jsonb_build_array(
        jsonb_build_object('code', 'title', 'value', substr(replace(upper(v_package_code), '-', ''), 1, 9)),
        jsonb_build_object('code', 'package_from', 'value', v_customs_from[random.random_integer(1, v_customs_from_length)]),
        jsonb_build_object('code', 'package_what', 'value', v_goods_array[v_good_id]),
        jsonb_build_object('code', 'package_receiver_status', 'value', 2),
        jsonb_build_object('code', 'system_package_receiver_code', 'value', v_receiver_code),
        jsonb_build_object('code', 'package_receiver_code', 'value', v_receiver_code, 'value_object_code', 'master'),
        jsonb_build_object('code', 'package_weight', 'value', random.random_integer(1, 50)),
        jsonb_build_object('code', 'package_arrival_time', 'value', pp_utils.format_date(clock_timestamp())),
        jsonb_build_object('code', 'package_status', 'value', 'new'),
        jsonb_build_object('code', 'system_package_reactions', 'value', json.get_array(v_goods, v_goods_array[v_good_id])),
        jsonb_build_object('code', 'package_reactions', 'value', json.get_array(v_goods, v_goods_array[v_good_id]), 'value_object_code', 'master')
      ),
      'package');
    v_packages2 := array_append(v_packages2, v_package_id);
    v_content := array_prepend(v_package_code, v_content);

    -- Засовываем будущие посылки с 2 статусом
    if v_m = v_i then
      v_future := pallas_project.get_future_packages(2);
      v_packages2 := json.get_integer_array(v_future, 'packages') || v_packages2;
      v_content := json.get_string_array(v_future, 'content') || v_content;
    end if;
  end loop;
    v_packages := v_packages || v_packages2;

  v_m := random.random_integer(1, 15);
  for v_i in 1..random.random_integer(15, 20) loop
    v_package_code := pgcrypto.gen_random_uuid()::text;
    v_receiver_code := UPPER(substr(pgcrypto.gen_random_uuid()::text, 1, 6));
    v_good_id := random.random_integer(1, v_goods_array_length);
    v_package_id := data.create_object(
      v_package_code,
      jsonb_build_array(
        jsonb_build_object('code', 'title', 'value', substr(replace(upper(v_package_code), '-', ''), 1, 9)),
        jsonb_build_object('code', 'package_from', 'value', v_customs_from[random.random_integer(1, v_customs_from_length)]),
        jsonb_build_object('code', 'package_what', 'value', v_goods_array[v_good_id]),
        jsonb_build_object('code', 'package_receiver_status', 'value', 3),
        jsonb_build_object('code', 'system_package_receiver_code', 'value', v_receiver_code),
        jsonb_build_object('code', 'package_receiver_code', 'value', v_receiver_code, 'value_object_code', 'master'),
        jsonb_build_object('code', 'package_weight', 'value', random.random_integer(1, 50)),
        jsonb_build_object('code', 'package_arrival_time', 'value', pp_utils.format_date(clock_timestamp())),
        jsonb_build_object('code', 'package_status', 'value', 'new'),
        jsonb_build_object('code', 'system_package_reactions', 'value', json.get_array(v_goods, v_goods_array[v_good_id])),
        jsonb_build_object('code', 'package_reactions', 'value', json.get_array(v_goods, v_goods_array[v_good_id]), 'value_object_code', 'master')
      ),
      'package');

    v_packages3 := array_append(v_packages3, v_package_id);
    v_content := array_prepend(v_package_code, v_content);

    -- Засовываем будущие посылки с 3 статусом
    if v_m = v_i then
      v_future := pallas_project.get_future_packages(3);
      v_packages3 := json.get_integer_array(v_future, 'packages') || v_packages3;
      v_content := json.get_string_array(v_future, 'content') || v_content;
    end if;
  end loop;

  v_packages := v_packages || v_packages3;

  -- Устанавливаем джобы на то, чтобы перевести в статус проверено 
  perform data.create_job(clock_timestamp() + ('4 hours')::interval, 
      'pallas_project.job_change_packages_status_to_checked', 
      to_jsonb(v_packages0));
  perform data.create_job(clock_timestamp() + ('2 hours')::interval, 
      'pallas_project.job_change_packages_status_to_checked', 
      to_jsonb(v_packages1));
  perform data.create_job(clock_timestamp() + ('1 hours')::interval, 
      'pallas_project.job_change_packages_status_to_checked', 
      to_jsonb(v_packages2));
  perform data.create_job(clock_timestamp() + ('30 minutes')::interval, 
      'pallas_project.job_change_packages_status_to_checked', 
      to_jsonb(v_packages3));

  perform data.change_object_and_notify(v_customs_id, jsonb_build_array(data.attribute_change2jsonb('content', to_jsonb(v_content))));

  for v_person_id in (select * from unnest(pallas_project.get_group_members('customs_officer'))) loop
    perform pp_utils.add_notification(v_person_id, 'На таможню прибыла новая партия грузов', 'customs_new');
  end loop;
end;
$$
language plpgsql;
