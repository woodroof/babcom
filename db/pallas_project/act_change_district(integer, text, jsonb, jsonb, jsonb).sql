-- drop function pallas_project.act_change_district(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_change_district(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_object_code text := json.get_string(in_params);
  v_object_id integer := data.get_object_id(v_object_code);
  v_new_district_letter text := upper(json.get_string(in_user_params, 'district_letter'));
  v_district_code text := json.get_string(data.get_raw_attribute_value_for_update(v_object_id, 'person_district'));
  v_comment text := json.get_string(in_user_params, 'comment');
  v_new_district_code text;
  v_notified boolean;
  v_is_person boolean;
  v_master_group_id integer;
begin
  if v_new_district_letter not in ('A', 'B', 'C', 'D', 'E', 'F', 'G') then
    perform api_utils.create_show_message_action_notification(
      in_client_id,
      in_request_id,
      'Ошибка',
      'Буква сектора должна быть от A до G');
    return;
  end if;

  v_new_district_code := 'sector_' || v_new_district_letter;

  if v_new_district_code = v_district_code then
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
    return;
  end if;

  v_notified :=
    data.change_current_object(
      in_client_id,
      in_request_id,
      v_object_id,
      format(
        '{
          "person_district": "%s"
        }',
        v_new_district_code)::jsonb,
      'Изменение сектора мастером');
  assert v_notified;

  v_is_person := pp_utils.is_in_group(v_object_id, 'player');
  v_master_group_id := data.get_object_id('master');

  -- Обновим старый район
  declare
    v_district_id integer;
    v_content jsonb;
    v_changes jsonb := jsonb '[]';
  begin
    v_district_id := data.get_object_id(v_district_code);

    if v_is_person then
      v_content := to_jsonb(array_remove(json.get_string_array(data.get_raw_attribute_value_for_update(v_district_id, 'content')), v_object_code));
      v_changes := v_changes || data.attribute_change2jsonb('content', v_content);
    end if;

    v_content := to_jsonb(array_remove(json.get_string_array(data.get_raw_attribute_value_for_update(v_district_id, 'content', v_master_group_id)), v_object_code));
    v_changes := v_changes || data.attribute_change2jsonb('content', v_content, v_master_group_id);

    perform data.change_object_and_notify(
      v_district_id,
      v_changes);
  end;

  -- Обновим новый район
  declare
    v_district_id integer;
    v_content jsonb;
    v_changes jsonb := jsonb '[]';
  begin
    v_district_id := data.get_object_id(v_new_district_code);

    if v_is_person then
      select jsonb_agg(o.code order by data.get_attribute_value(o.id, data.get_attribute_id('title')))
      into v_content
      from jsonb_array_elements(data.get_raw_attribute_value(v_district_id, 'content') || to_jsonb(v_object_code)) arr
      join data.objects o on
        o.code = json.get_string(arr.value);

      v_changes := v_changes || data.attribute_change2jsonb('content', v_content);
    end if;

    -- Для мастера видны все персонажи
    select jsonb_agg(o.code order by data.get_attribute_value(o.id, data.get_attribute_id('title')))
    into v_content
    from jsonb_array_elements(data.get_raw_attribute_value(v_district_id, 'content', v_master_group_id) || to_jsonb(v_object_code)) arr
    join data.objects o on
      o.code = json.get_string(arr.value);

    v_changes := v_changes || data.attribute_change2jsonb('content', v_content, v_master_group_id);

    perform data.change_object_and_notify(
      v_district_id,
      v_changes);
  end;

  perform pp_utils.add_notification(
    v_object_id,
    format(E'Вы были переселены в %s\n', pp_utils.link(v_new_district_code)) || pp_utils.trim(v_comment),
    v_object_id,
    true);
end;
$$
language plpgsql;
