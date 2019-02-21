-- drop function pallas_project.create_synonym(text, text, jsonb);

create or replace function pallas_project.create_synonym(in_object_code text, in_original_object_code text, in_attributes jsonb)
returns void
volatile
as
$$
-- Не для использования на игре, т.к. обновляет атрибуты напрямую, без уведомлений и блокировок!
declare
  v_object_id integer;
begin
  v_object_id :=
    data.create_object(
      in_object_code,
      in_attributes,
      'organization');
  perform data.set_attribute_value(v_object_id, 'system_org_synonym', to_jsonb(in_original_object_code));
  perform data.set_attribute_value(v_object_id, 'org_synonym', to_jsonb(in_original_object_code), data.get_object_id('master'));
end;
$$
language plpgsql;
