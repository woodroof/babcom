-- drop function pallas_project.init_contracts();

create or replace function pallas_project.init_contracts()
returns void
volatile
as
$$
begin
  perform pallas_project.create_contract('player2', 'org_de_beers', 'suspended', '100', 'Работай и зарабатывай');
  perform pallas_project.create_contract('player4', 'org_administration', 'active', '120', 'Работай и зарабатывай');
end;
$$
language plpgsql;
