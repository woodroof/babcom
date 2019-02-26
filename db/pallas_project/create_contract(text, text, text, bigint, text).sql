-- drop function pallas_project.create_contract(text, text, text, bigint, text);

create or replace function pallas_project.create_contract(in_person_code text, in_org_code text, in_status text, in_reward bigint, in_description text)
returns integer
volatile
as
$$
declare
  v_description text := pp_utils.trim(in_description);
  v_contract_id integer;
  v_content jsonb;
begin
  assert in_status in ('unconfirmed', 'confirmed', 'active', 'suspended', 'cancelled', 'suspended_cancelled', 'not_active');
  assert in_reward > 0;
  assert v_description is not null;

  v_contract_id :=
    data.create_object(
      null,
      format(
        '[
          {"code": "is_visible", "value": true, "value_object_code": "%s"},
          {"code": "is_visible", "value": true, "value_object_code": "%s_head"},
          {"code": "is_visible", "value": true, "value_object_code": "%s_economist"},
          {"code": "is_visible", "value": true, "value_object_code": "%s_auditor"},
          {"code": "is_visible", "value": true, "value_object_code": "%s_temporary_auditor"},
          {"code": "contract_org", "value": "%s"},
          {"code": "contract_person", "value": "%s"},
          {"code": "contract_status", "value": "%s"},
          {"code": "contract_reward", "value": %s},
          {"code": "contract_description", "value": %s}
        ]',
        in_person_code,
        in_org_code,
        in_org_code,
        in_org_code,
        in_org_code,
        in_org_code,
        in_person_code,
        in_status,
        in_reward,
        to_jsonb(v_description)::text)::jsonb,
      'contract');

  -- Поместим в списки
  perform pp_utils.list_prepend_and_notify(data.get_object_id(in_org_code || '_contracts'), v_contract_id, null, null);
  perform pp_utils.list_prepend_and_notify(data.get_object_id(in_person_code || '_contracts'), v_contract_id, null, null);
  perform pp_utils.list_prepend_and_notify(data.get_object_id('contracts'), v_contract_id, null, null);

  return v_contract_id;
end;
$$
language plpgsql;
