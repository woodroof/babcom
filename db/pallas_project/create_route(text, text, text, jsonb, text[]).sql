-- drop function pallas_project.create_route(text, text, text, jsonb, text[]);

create or replace function pallas_project.create_route(in_title text, in_subtitle text, in_description text, in_route_points jsonb, in_actors text[])
returns void
volatile
as
$$
-- Не для использования на игре, т.к. обновляет атрибуты напрямую, без уведомлений и блокировок!
declare
  v_my_documents_id integer := data.get_object_id('my_documents');
  v_route_code text := substring((pgcrypto.gen_random_uuid())::text for 6);
  v_route_document_id integer;
  v_route_document_code text;
  v_actor text;
  v_actor_id integer;
begin
  perform data.create_object(
    v_route_code,
    jsonb_build_object('route_points', in_route_points),
    'route');
  v_route_document_id :=
    data.create_object(
      null,
      jsonb_build_object('title', in_title, 'subtitle', in_subtitle, 'description', in_description, 'route_code', v_route_code),
      'route_document');
  v_route_document_code := data.get_object_code(v_route_document_id);

  for v_actor in
  (
    select value
    from unnest(in_actors) a(value)
  )
  loop
    perform pp_utils.list_prepend_and_notify(v_my_documents_id, v_route_document_code, data.get_object_id(v_actor));
  end loop;

  perform pp_utils.list_prepend_and_notify(v_my_documents_id, v_route_document_code, data.get_object_id('master'));
end;
$$
language plpgsql;
