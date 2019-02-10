-- drop function pallas_project.init_groups();

create or replace function pallas_project.init_groups()
returns void
volatile
as
$$
begin
  -- Группы персон
  perform data.create_object('all_person', jsonb '{"priority": 10}');
  perform data.create_object('player', jsonb '{"priority": 15}');
  perform data.create_object('aster', jsonb '{"priority": 20}');
  perform data.create_object('un', jsonb '{"priority": 30}');
  perform data.create_object('mcr', jsonb '{"priority": 40}');
  perform data.create_object('opa', jsonb '{"priority": 50}');
  perform data.create_object('master', jsonb '{"priority": 190}');
end;
$$
language plpgsql;
