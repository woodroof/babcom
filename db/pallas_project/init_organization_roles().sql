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
  perform data.add_object_to_object(data.get_object_id('939b6537-afc1-41f4-963a-21ccfd1c7d28'), data.get_object_id('org_opa_head'));
  perform data.add_object_to_object(data.get_object_id('54e94c45-ce2a-459a-8613-9b75e23d9b68'), data.get_object_id('org_clinic_head'));
  perform data.add_object_to_object(data.get_object_id('e0c49e51-779f-4f21-bb94-bbbad33bc6e2'), data.get_object_id('org_clean_asteroid_head'));
  perform data.add_object_to_object(data.get_object_id('8f7b1cc6-28cd-4fb1-8c81-e0ab1c0df5c9'), data.get_object_id('org_teco_mars_head'));
  perform data.add_object_to_object(data.get_object_id('2956e4b7-7b02-4ffd-a725-ea3390b9a1cc'), data.get_object_id('org_tariel_head'));
  perform data.add_object_to_object(data.get_object_id('97539130-5977-41cb-a96d-d160522430f8'), data.get_object_id('org_cavern_head'));
  perform data.add_object_to_object(data.get_object_id('d23550d0-d599-4cf2-9a15-1594fd2df2b2'), data.get_object_id('org_tatu_head'));
  perform data.add_object_to_object(data.get_object_id('74bc1a0f-72d9-4271-b358-0ef464f3cbf9'), data.get_object_id('org_starbucks_auditor'));

  -- todo добавить в "Мои организации"
end;
$$
language plpgsql;
