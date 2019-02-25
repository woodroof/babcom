-- drop function data.profile(text);

create or replace function data.profile(in_message text)
returns void
volatile
as
$$
begin
  assert in_message is not null;

  perform data.log('info', format('Profile: %s %s', clock_timestamp(), in_message));
end;
$$
language plpgsql;
