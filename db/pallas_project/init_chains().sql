-- drop function pallas_project.init_chains();

create or replace function pallas_project.init_chains()
returns void
volatile
as
$$
begin
  -- todo
  -- оружие, СВП 5f7c2dc0-0cb4-4fc5-870c-c0776272a02e a11d2240-3dce-4d75-bc52-46e98b07ff27 5a764843-9edc-4cfb-8367-80c1d3c54ed9
  -- стимуляторы, картель 18ce44b8-5df9-4c84-8af4-b58b3f5e7b21 70e5db08-df47-4395-9f4a-15eef99b2b89 71efd585-080c-431d-a258-b4e222ff7623
  -- оружие, картель 70e5db08-df47-4395-9f4a-15eef99b2b89
  -- алмазы, СВП 5074485d-73cd-4e19-8d4b-4ffedcf1fb5f 3beea660-35a3-431e-b9ae-e2e88e6ac064
end;
$$
language plpgsql;
