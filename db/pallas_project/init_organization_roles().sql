-- drop function pallas_project.init_organization_roles();

create or replace function pallas_project.init_organization_roles()
returns void
volatile
as
$$
begin
  -- Добавляем персонажей в организации
  perform data.add_object_to_object(data.get_object_id('player1'), data.get_object_id('org_administration_head'));
  perform data.add_object_to_object(data.get_object_id('player2'), data.get_object_id('org_administration_economist'));
  perform data.add_object_to_object(data.get_object_id('player3'), data.get_object_id('org_administration_auditor'));
  perform data.add_object_to_object(data.get_object_id('player4'), data.get_object_id('org_administration_temporary_auditor'));

  perform data.set_attribute_value(data.get_object_id('player1_my_organizations'), 'content', jsonb '["org_administration"]');
  perform data.set_attribute_value(data.get_object_id('player2_my_organizations'), 'content', jsonb '["org_administration"]');
  perform data.set_attribute_value(data.get_object_id('player3_my_organizations'), 'content', jsonb '["org_administration"]');
  perform data.set_attribute_value(data.get_object_id('player4_my_organizations'), 'content', jsonb '["org_administration"]');
end;
$$
language plpgsql;
