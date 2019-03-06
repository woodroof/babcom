-- drop function pallas_project.act_transfer_org_resource(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_transfer_org_resource(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);

  v_dest_code text := json.get_string(in_params, 'receiver_code');
  v_dest_id integer := data.get_object_id(v_dest_code);
  v_source_code text := json.get_string(in_params, 'org_code');
  v_source_id integer := data.get_object_id(v_source_code);
  v_resource text := json.get_string(in_params, 'resource');
  v_count bigint := json.get_bigint(in_user_params, 'count');
  v_comment text := pp_utils.trim(json.get_string(in_user_params, 'comment'));

  v_res_system_attr_id integer := data.get_attribute_id('system_resource_' || v_resource);
  v_res_attr_id integer := data.get_attribute_id('resource_' || v_resource);

  v_source_count integer := json.get_integer_opt(data.get_attribute_value_for_update(v_source_id, v_res_system_attr_id), 0) - v_count;
  v_dest_count integer := json.get_integer_opt(data.get_attribute_value_for_update(v_dest_id, v_res_system_attr_id), 0) + v_count;

  v_changes jsonb;
  v_notified boolean;

  v_title_attr_id integer := data.get_attribute_id('title');

  v_source_comment text;
  v_dest_comment text;

  v_org_person_id integer;
begin
  if v_source_count < 0 then
    perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Ошибка', 'У организации нет нужного количества ресурса.');
    return;
  end if;

  v_changes :=
    format(
      '[
        {"id": %s, "value": %s},
        {"id": %s, "value": %s, "value_object_code": "master"},
        {"id": %s, "value": %s, "value_object_code": "%s_head"},
        {"id": %s, "value": %s, "value_object_code": "%s_economist"}
      ]',
      v_res_system_attr_id,
      v_dest_count,
      v_res_attr_id,
      v_dest_count,
      v_res_attr_id,
      v_dest_count,
      v_dest_code,
      v_res_attr_id,
      v_dest_count,
      v_dest_code)::jsonb;

  if v_dest_code = 'org_administration' then
    v_changes :=
      v_changes ||
      format(
        '[
          {"id": %s, "value": %s, "value_object_code": "org_administration_ecologist"}
        ]',
        v_res_attr_id,
        v_dest_count)::jsonb;
  end if;

  v_notified :=
    data.change_current_object(
      in_client_id,
      in_request_id,
      v_dest_id,
      v_changes);
  if not v_notified then
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;

  v_changes :=
    format(
      '[
        {"id": %s, "value": %s},
        {"id": %s, "value": %s, "value_object_code": "master"},
        {"id": %s, "value": %s, "value_object_code": "%s_head"},
        {"id": %s, "value": %s, "value_object_code": "%s_economist"}
      ]',
      v_res_system_attr_id,
      v_source_count,
      v_res_attr_id,
      v_source_count,
      v_res_attr_id,
      v_source_count,
      v_source_code,
      v_res_attr_id,
      v_source_count,
      v_source_code)::jsonb;

  if v_source_code = 'org_administration' then
    v_changes :=
      v_changes ||
      format(
        '[
          {"id": %s, "value": %s, "value_object_code": "org_administration_ecologist"}
        ]',
        v_res_attr_id,
        v_source_count)::jsonb;
  end if;

  perform data.change_object_and_notify(
    v_source_id,
    v_changes);

  v_source_comment :=
    format(
      E'Организация %s передала ресурс %s в количестве %s организации %s.\nИнициатор: %s%s',
      pp_utils.link(v_source_id),
      pallas_project.resource_to_text_i(v_resource),
      v_count,
      pp_utils.link(v_dest_id),
      pp_utils.link(v_actor_id),
      (case when v_comment = '' then '' else E'\nКомментарий:\n' || v_comment end));

  for v_org_person_id in
  (
    select distinct object_id
    from data.object_objects
    where
      parent_object_id in (
        data.get_object_id(v_source_code || '_head'),
        data.get_object_id(v_source_code || '_economist')) and
      object_id != parent_object_id
  )
  loop
    perform pp_utils.add_notification(
      v_org_person_id,
      v_source_comment,
      v_source_id,
      true);
  end loop;

  v_dest_comment :=
    format(
      E'Организация %s получила ресурс %s в количестве %s от организации %s.%s',
      pp_utils.link(v_dest_id),
      pallas_project.resource_to_text_i(v_resource),
      v_count,
      pp_utils.link(v_source_id),
      (case when v_comment = '' then '' else E'\nКомментарий:\n' || v_comment end));

  for v_org_person_id in
  (
    select distinct object_id
    from data.object_objects
    where
      parent_object_id in (
        data.get_object_id(v_dest_code || '_head'),
        data.get_object_id(v_dest_code || '_economist')) and
      object_id != parent_object_id
  )
  loop
    perform pp_utils.add_notification(
      v_org_person_id,
      v_dest_comment,
      v_dest_id,
      true);
  end loop;
end;
$$
language plpgsql;
