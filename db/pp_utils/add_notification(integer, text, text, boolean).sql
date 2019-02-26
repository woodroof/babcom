-- drop function pp_utils.add_notification(integer, text, text, boolean);

create or replace function pp_utils.add_notification(in_object_id integer, in_text text, in_redirect_object_code text, in_is_important boolean default false)
returns void
volatile
as
$$
begin
  perform pp_utils.add_notification(in_object_id, in_text, data.get_object_id(in_redirect_object_code), in_is_important);
end;
$$
language plpgsql;
