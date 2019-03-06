-- drop function pallas_project.init_organization_roles();

create or replace function pallas_project.init_organization_roles()
returns void
volatile
as
$$
begin
  -- Добавляем персонажей в организации
  perform data.add_object_to_object(data.get_object_id('b7845724-0c9a-498e-8b2f-a01455c22399'), data.get_object_id('org_administration_head'));
  perform data.add_object_to_object(data.get_object_id('0d07f15b-2952-409b-b22e-4042cf70acc6'), data.get_object_id('org_administration_economist'));
  perform data.add_object_to_object(data.get_object_id('0d07f15b-2952-409b-b22e-4042cf70acc6'), data.get_object_id('org_cherry_orchard_head'));
  perform data.add_object_to_object(data.get_object_id('9b956c40-7978-4b0a-993e-8373fe581761'), data.get_object_id('org_cherry_orchard_auditor'));
  perform data.add_object_to_object(data.get_object_id('5f7c2dc0-0cb4-4fc5-870c-c0776272a02e'), data.get_object_id('org_opa_head'));
  perform data.add_object_to_object(data.get_object_id('784e4126-8dd7-41a3-a916-0fdc53a31ce2'), data.get_object_id('org_de_beers_head'));
  perform data.add_object_to_object(data.get_object_id('0a0dc809-7bf1-41ee-bfe7-700fd26c1c0a'), data.get_object_id('org_starbucks_auditor'));
  perform data.add_object_to_object(data.get_object_id('5074485d-73cd-4e19-8d4b-4ffedcf1fb5f'), data.get_object_id('org_opa_head'));
  perform data.add_object_to_object(data.get_object_id('3beea660-35a3-431e-b9ae-e2e88e6ac064'), data.get_object_id('org_opa_auditor'));
  perform data.add_object_to_object(data.get_object_id('48569d1d-5f01-410f-a67b-c5fe99d8dbc1'), data.get_object_id('org_star_helix_head'));
  perform data.add_object_to_object(data.get_object_id('c9e08512-e729-430a-b2fd-df8e7c94a5e7'), data.get_object_id('org_starbucks_auditor'));
  perform data.add_object_to_object(data.get_object_id('70e5db08-df47-4395-9f4a-15eef99b2b89'), data.get_object_id('org_starbucks_head'));
  perform data.add_object_to_object(data.get_object_id('70e5db08-df47-4395-9f4a-15eef99b2b89'), data.get_object_id('org_akira_sc_auditor'));
  perform data.add_object_to_object(data.get_object_id('939b6537-afc1-41f4-963a-21ccfd1c7d28'), data.get_object_id('org_opa_head'));
  perform data.add_object_to_object(data.get_object_id('939b6537-afc1-41f4-963a-21ccfd1c7d28'), data.get_object_id('org_akira_sc_head'));
  perform data.add_object_to_object(data.get_object_id('54e94c45-ce2a-459a-8613-9b75e23d9b68'), data.get_object_id('org_clinic_head'));
  perform data.add_object_to_object(data.get_object_id('e0c49e51-779f-4f21-bb94-bbbad33bc6e2'), data.get_object_id('org_clean_asteroid_head'));
  perform data.add_object_to_object(data.get_object_id('8f7b1cc6-28cd-4fb1-8c81-e0ab1c0df5c9'), data.get_object_id('org_teco_mars_head'));
  perform data.add_object_to_object(data.get_object_id('2956e4b7-7b02-4ffd-a725-ea3390b9a1cc'), data.get_object_id('org_tariel_head'));
  perform data.add_object_to_object(data.get_object_id('97539130-5977-41cb-a96d-d160522430f8'), data.get_object_id('org_cavern_head'));
  perform data.add_object_to_object(data.get_object_id('d23550d0-d599-4cf2-9a15-1594fd2df2b2'), data.get_object_id('org_tatu_head'));
  perform data.add_object_to_object(data.get_object_id('74bc1a0f-72d9-4271-b358-0ef464f3cbf9'), data.get_object_id('org_starbucks_auditor'));
  perform data.add_object_to_object(data.get_object_id('ac1b23d0-ba5f-4042-85d5-880a66254803'), data.get_object_id('org_free_sky_head'));

  perform data.add_object_to_object(data.get_object_id('95a3dc9e-8512-44ab-9173-29f0f4fd6e05'), data.get_object_id('org_administration_ecologist'));

  -- Заполняем "Мои организации"
  perform data.set_attribute_value('b7845724-0c9a-498e-8b2f-a01455c22399_my_organizations', 'content', jsonb '["org_administration"]');
  perform data.set_attribute_value('0d07f15b-2952-409b-b22e-4042cf70acc6_my_organizations', 'content', jsonb '["org_administration", "org_cherry_orchard"]');
  perform data.set_attribute_value('9b956c40-7978-4b0a-993e-8373fe581761_my_organizations', 'content', jsonb '["org_cherry_orchard"]');
  perform data.set_attribute_value('5f7c2dc0-0cb4-4fc5-870c-c0776272a02e_my_organizations', 'content', jsonb '["org_opa"]');
  perform data.set_attribute_value('784e4126-8dd7-41a3-a916-0fdc53a31ce2_my_organizations', 'content', jsonb '["org_de_beers"]');
  perform data.set_attribute_value('0a0dc809-7bf1-41ee-bfe7-700fd26c1c0a_my_organizations', 'content', jsonb '["org_starbucks"]');
  perform data.set_attribute_value('5074485d-73cd-4e19-8d4b-4ffedcf1fb5f_my_organizations', 'content', jsonb '["org_opa"]');
  perform data.set_attribute_value('3beea660-35a3-431e-b9ae-e2e88e6ac064_my_organizations', 'content', jsonb '["org_opa"]');
  perform data.set_attribute_value('48569d1d-5f01-410f-a67b-c5fe99d8dbc1_my_organizations', 'content', jsonb '["org_star_helix"]');
  perform data.set_attribute_value('c9e08512-e729-430a-b2fd-df8e7c94a5e7_my_organizations', 'content', jsonb '["org_starbucks"]');
  perform data.set_attribute_value('70e5db08-df47-4395-9f4a-15eef99b2b89_my_organizations', 'content', jsonb '["org_starbucks", "org_akira_sc"]');
  perform data.set_attribute_value('939b6537-afc1-41f4-963a-21ccfd1c7d28_my_organizations', 'content', jsonb '["org_opa", "org_akira_sc"]');
  perform data.set_attribute_value('54e94c45-ce2a-459a-8613-9b75e23d9b68_my_organizations', 'content', jsonb '["org_clinic"]');
  perform data.set_attribute_value('e0c49e51-779f-4f21-bb94-bbbad33bc6e2_my_organizations', 'content', jsonb '["org_clean_asteroid"]');
  perform data.set_attribute_value('8f7b1cc6-28cd-4fb1-8c81-e0ab1c0df5c9_my_organizations', 'content', jsonb '["org_teco_mars"]');
  perform data.set_attribute_value('2956e4b7-7b02-4ffd-a725-ea3390b9a1cc_my_organizations', 'content', jsonb '["org_tariel"]');
  perform data.set_attribute_value('97539130-5977-41cb-a96d-d160522430f8_my_organizations', 'content', jsonb '["org_cavern"]');
  perform data.set_attribute_value('d23550d0-d599-4cf2-9a15-1594fd2df2b2_my_organizations', 'content', jsonb '["org_tatu"]');
  perform data.set_attribute_value('74bc1a0f-72d9-4271-b358-0ef464f3cbf9_my_organizations', 'content', jsonb '["org_starbucks"]');
  perform data.set_attribute_value('ac1b23d0-ba5f-4042-85d5-880a66254803_my_organizations', 'content', jsonb '["org_free_sky"]');
  perform data.set_attribute_value('95a3dc9e-8512-44ab-9173-29f0f4fd6e05_my_organizations', 'content', jsonb '["org_administration"]');
end;
$$
language plpgsql;
