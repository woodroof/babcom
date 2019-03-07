-- drop function pallas_project.create_document(text, text, text[], text);

create or replace function pallas_project.create_document(in_title text, in_body text, in_persons text[], in_category text default 'private'::text)
returns void
volatile
as
$$
declare
  v_documents_id integer;
  v_master_group_id integer := data.get_object_id('master');

  v_attributes jsonb := jsonb_build_array(jsonb_build_object('code', 'document_category', 'value', in_category));

  v_person_code text;

  v_document_id integer;
  v_document_code text;
begin
  v_attributes :=
    v_attributes ||
    jsonb_build_object('code', 'title', 'value', in_title) ||
    jsonb_build_object('code', 'document_text', 'value', in_body);

  v_documents_id := case when in_category = 'rule' then data.get_object_id('rules_documents')
                         when in_category = 'official' then data.get_object_id('official_documents')
                         else data.get_object_id('my_documents') end;

  for v_person_code in
  (
    select value
    from unnest(in_persons) a(value)
  )
  loop
    v_attributes :=
      v_attributes ||
      jsonb_build_object('code', 'system_document_is_my', 'value', true, 'value_object_code', v_person_code);
  end loop;

  v_document_id :=
    data.create_object(
    null,
    v_attributes,
    'document');

  v_document_code := data.get_object_code(v_document_id);

  for v_person_code in
  (
    select value
    from unnest(in_persons) a(value)
  )
  loop
    perform pp_utils.list_prepend_and_notify(v_documents_id, v_document_code, data.get_object_id(v_person_code));
    perform pp_utils.list_replace_to_head_and_notify(v_documents_id, v_document_code, v_master_group_id);
  end loop;
end;
$$
language plpgsql;
