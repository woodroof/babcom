-- drop function pallas_project.act_create_contract(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_create_contract(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_org_code text := json.get_string(in_params);
  v_content jsonb;
  v_list_id integer;
begin
  select jsonb_agg(code)
  into v_content
  from (
    select o.code
    from data.object_objects oo
    join data.objects o on
      o.id = oo.object_id and
      json.get_string(data.get_attribute_value(o.id, data.get_attribute_id('system_person_economy_type'))) = 'asters'
    where
      oo.parent_object_id = data.get_object_id('player') and
      oo.object_id != oo.parent_object_id
    order by json.get_string(data.get_raw_attribute_value(o.id, data.get_attribute_id('title')))) codes;

  v_list_id :=
    data.create_object(
      null,
      jsonb '[]' ||
      data.attribute_change2jsonb('is_visible', jsonb 'true', v_actor_id) ||
      data.attribute_change2jsonb('content', v_content) ||
      data.attribute_change2jsonb('contract_org', to_jsonb(v_org_code)),
      'contract_person_list');
  perform api_utils.create_open_object_action_notification(in_client_id, in_request_id, data.get_object_code(v_list_id));
end;
$$
language plpgsql;
