-- drop function pallas_project.act_produce_resource(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_produce_resource(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_adm_id integer := data.get_object_id('org_administration');
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_resource text := json.get_string(in_params, 'resource');
  v_count integer := json.get_integer(in_user_params, 'count');
  v_source_resource text := pp_utils.get_source_resource(v_resource);
  v_efficiency integer := json.get_integer(data.get_attribute_value_for_share(v_adm_id, 'system_' || v_source_resource || '_efficiency'));

  v_source_system_attr_id integer := data.get_attribute_id('system_resource_' || v_source_resource);
  v_source_attr_id integer := data.get_attribute_id('resource_' || v_source_resource);
  v_dest_system_attr_id integer := data.get_attribute_id('system_resource_' || v_resource);
  v_dest_attr_id integer := data.get_attribute_id('resource_' || v_resource);

  v_source integer := json.get_integer(data.get_attribute_value_for_update(v_adm_id, v_source_system_attr_id));
  v_dest integer := json.get_integer(data.get_attribute_value_for_update(v_adm_id, v_dest_system_attr_id));

  v_source_diff integer := ceil(v_count / 0.9 / (v_efficiency::numeric / 100));

  v_notified boolean;
begin
  if v_source_diff > v_source then
    perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Ошибка', 'Нет нужного количества исходных ресурсов');
    return;
  end if;

  v_source := v_source - v_source_diff;
  v_dest := v_dest + v_count;

  v_notified :=
    data.change_current_object(
      in_client_id,
      in_request_id,
      v_adm_id,
      format(
        '[
          {"id": %s, "value": %s},
          {"id": %s, "value": %s, "value_object_code": "master"},
          {"id": %s, "value": %s, "value_object_code": "org_administration_head"},
          {"id": %s, "value": %s, "value_object_code": "org_administration_economist"},
          {"id": %s, "value": %s, "value_object_code": "org_administration_ecologist"},
          {"id": %s, "value": %s},
          {"id": %s, "value": %s, "value_object_code": "master"},
          {"id": %s, "value": %s, "value_object_code": "org_administration_head"},
          {"id": %s, "value": %s, "value_object_code": "org_administration_economist"},
          {"id": %s, "value": %s, "value_object_code": "org_administration_ecologist"}
        ]',
        v_source_system_attr_id,
        v_source,
        v_source_attr_id,
        v_source,
        v_source_attr_id,
        v_source,
        v_source_attr_id,
        v_source,
        v_source_attr_id,
        v_source,
        v_dest_system_attr_id,
        v_dest,
        v_dest_attr_id,
        v_dest,
        v_dest_attr_id,
        v_dest,
        v_dest_attr_id,
        v_dest,
        v_dest_attr_id,
        v_dest)::jsonb);
  assert v_notified;
end;
$$
language plpgsql;
