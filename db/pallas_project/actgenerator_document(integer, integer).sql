-- drop function pallas_project.actgenerator_document(integer, integer);

create or replace function pallas_project.actgenerator_document(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
  v_is_master boolean;
  v_master_group_id integer := data.get_object_id('master');
  v_document_code text := data.get_object_code(in_object_id);
  v_document_author integer := json.get_integer(data.get_attribute_value(in_object_id, 'system_document_author'));
  v_document_category text := json.get_string(data.get_attribute_value_for_share(in_object_id, 'document_category'));
  v_document_status text := json.get_string_opt(data.get_attribute_value_for_share(in_object_id, 'document_status'),'');
  v_system_document_participants jsonb := data.get_attribute_value_for_share(in_object_id, 'system_document_participants');
  v_system_document_is_my boolean := json.get_boolean_opt(data.get_raw_attribute_value_for_share(in_object_id, 'system_document_is_my', in_actor_id), false);
  v_document_list_content text[];
  v_my_documents_id integer := data.get_object_id('my_documents');
  v_official_documents_id integer := data.get_object_id('official_documents');
  v_rules_documents_id integer := data.get_object_id('rules_documents');
begin
  assert in_actor_id is not null;

  v_is_master := pp_utils.is_in_group(in_actor_id, 'master');
  if v_document_status <> 'deleted' then
    if v_is_master or (in_actor_id = v_document_author and (v_document_category = 'private' or v_document_status = 'draft')) then
      v_actions_list := v_actions_list || 
          format(', "document_edit": {"code": "document_edit", "name": "Редактировать", "disabled": false, "params": {"document_code": "%s"}, 
  "user_params": [{"code": "title", "description": "Заголовок", "type": "string", "restrictions": {"min_length": 1}, "default_value": "%s"},
  {"code": "document_text", "description": "Текст документа", "type": "string", "restrictions": {"min_length": 1, "multiline": true}, "default_value": %s}]}',
                  v_document_code,
                  json.get_string_opt(data.get_raw_attribute_value_for_share(in_object_id, 'title'), null),
                  coalesce(data.get_attribute_value_for_share(in_object_id, 'document_text')::text, '""'));

      v_actions_list := v_actions_list || 
          format(', "document_delete": {"code": "document_delete", "name": "Удалить", "disabled": false, "warning": "Документ исчезнет безвозвратно. Точно удаляем?", '||
                  '"params": {"document_code": "%s"}}',
                  v_document_code);

      if v_document_category = 'private' then
        v_actions_list := v_actions_list || 
          format(', "document_make_official": {"code": "document_make_official", "name": "Перевести в официальные", "disabled": false, '||
                  '"params": {"document_code": "%s"}}',
                  v_document_code);
      end if;
    end if;

    if v_is_master and v_document_category = 'private' then
      v_actions_list := v_actions_list || 
          format(', "document_make_rule": {"code": "document_make_rule", "name": "Перенести в правила", "disabled": false, "warning": "Документ перенесётся в правила для всех, у кого он есть в документах. Переносим?", '||
                  '"params": {"document_code": "%s"}}',
                  v_document_code);
    end if;

    v_actions_list := v_actions_list || 
            format(', "document_share_list": {"code": "document_share_list", "name": "Поделиться", "disabled": false, '||
                    '"params": {"document_code": "%s"}}',
                    v_document_code);

    if not v_is_master and v_document_category in ('private', 'official', 'rule') and not v_system_document_is_my then
      v_actions_list := v_actions_list || 
              format(', "document_add_to_my": {"code": "document_add_to_my", "name": "Добавить себе", "disabled": false, '||
                    '"params": {"document_code": "%s"}}',
                    v_document_code);
    end if;

    if v_document_category = 'official' and v_document_status = 'draft' and (v_is_master or in_actor_id = v_document_author) then
      v_actions_list := v_actions_list || 
          format(', "document_add_signers": {"code": "act_open_object", "name": "Добавить участников", "disabled": false, '||
                  '"params": {"object_code": "%s"}}',
                  v_document_code || '_signers_list');

      v_actions_list := v_actions_list || 
          format(', "document_send_to_sign": {"code": "document_send_to_sign", "name": "Отправить на подпись", "disabled": %s, "warning": "Всем, кому нужно расписаться, будут отправлены уведомления со ссылкой на документ. Редактирование документа станет невозможным. Продолжаем?",'||
                 '"params": {"document_code": "%s"}}',
                 (case when v_system_document_participants <> jsonb '{}' then 'false' else 'true' end),
                 v_document_code);
    end if;

    if v_document_category = 'official' and v_document_status = 'signing' and (v_is_master or in_actor_id = v_document_author) then
      v_actions_list := v_actions_list || 
          format(', "document_back_to_editing": {"code": "document_back_to_editing", "name": "Вернуть на редактирование", "disabled": false, "warning": "Все подписи будут отозваны. Вы уверены, что хотите вернуть документ на редактирование?",'||
                  '"params": {"document_code": "%s"}}',
                  v_document_code);
    end if;

    if v_document_category = 'official' 
    and v_document_status = 'signing' 
    and not json.get_boolean_opt(v_system_document_participants, data.get_object_code(in_actor_id), null) then
      v_actions_list := v_actions_list || 
        format(', "document_sign": {"code": "document_sign", "name": "Подписать", "disabled": false, "warning": "Подпись нельзя отозвать назад, если только документ не будет изменён. Вы уверены, что хотите подписать этот документ?",'||
               '"params": {"document_code": "%s"}}',
               v_document_code);
    end if;
  end if;
  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;
