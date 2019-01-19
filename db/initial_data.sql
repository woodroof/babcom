drop role if exists http;
create role http login password 'http';
grant usage on schema api to http;
grant execute on all functions in schema api to http;

select data.init();

select pallas_project.init();

analyze;