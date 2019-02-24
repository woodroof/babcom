-- drop function pallas_project.init_debatles();

create or replace function pallas_project.init_debatles()
returns void
volatile
as
$$
begin
  -- Атрибуты для дебатла
  insert into data.attributes(code, name, description, type, card_type, value_description_function, can_be_overridden) values
  ('debatle_status', 'Статус', null, 'normal', null, 'pallas_project.vd_debatle_status', false),
  ('debatle_person1', 'Зачинщик', null, 'normal', 'full', 'pallas_project.vd_link', false),
  ('debatle_person2', 'Оппонент', null, 'normal', 'full', 'pallas_project.vd_link', false),
  ('debatle_judge', 'Судья', null, 'normal', 'full', 'pallas_project.vd_link', false),
  ('system_debatle_target_audience', null, 'Аудитория дебатла', 'system', null, null, false),
  ('debatle_target_audience', 'Аудитория', null, 'normal', 'full', null, true),
  ('system_debatle_person1_votes', null, 'Количество голосов за первого участника', 'system', null, null, false),
  ('debatle_person1_votes', null, 'Количество голосов за первого участника', 'normal', 'full', null, true),
  ('system_debatle_person2_votes', null, 'Количество голосов за второго участника', 'system', null, null, false),
  ('debatle_person2_votes', null, 'Количество голосов за второго участника', 'normal', 'full', null, true),
  ('debatle_person1_bonuses', 'Штрафы и бонусы зачинщика', null, 'normal', 'full', 'pallas_project.vd_debatle_bonuses', false),
  ('debatle_person2_bonuses', 'Штрафы и бонусы оппонента', null, 'normal', 'full', 'pallas_project.vd_debatle_bonuses', false),
  ('system_debatle_person1_my_vote', null, 'Количество голосов каждого голосующего за первого участника', 'system', null, null, true),
  ('system_debatle_person2_my_vote', null, 'Количество голосов каждого голосующего за второго участника', 'system', null, null, true),
  ('debatle_my_vote', null, 'Уведомление игрока о том, за кого он проголосовал', 'normal', 'full', null, true),
  ('system_debatle_is_confirmed_presence', null, 'Признак подтверждённого присутствия на дебатле', 'system', null , null, true),
  ('system_debatle_confirm_presence_id', null, 'Id объекта для подтверждения присутствия на дебатле', 'system', null , null, false),
  ('debatle_confirm_presence_link', 'Ссылка для QR-кода', 'Ссылка для QR-кода', 'normal', 'full' , null, true),
  -- для временных объектов 
  ('debatle_temp_person_list_edited_person', null, 'Редактируемая персона в дебатле', 'normal', 'full', 'pallas_project.vd_debatle_temp_person_list_edited_person', false),
  ('system_debatle_id', null, 'Идентификатор дебатла для списка редактирования персон', 'system', null, null, false),
  ('debatle_temp_bonus_list_person', null, 'Персона, которой начисляем бонусы и штрафы', 'normal', 'full', 'pallas_project.vd_debatle_temp_bonus_list_person', false),
  ('debatle_temp_bonus_list_bonuses', 'Уже имеющиеся бонусы и штрафы', 'Уже имеющиеся бонусы и штрафы', 'normal', 'full', 'pallas_project.vd_debatle_bonuses', false),
  ('debatle_bonus_votes', 'Количество голосов' , 'Количество голосов бонуса или штрафа', 'normal', null, null, false);

-- Объект - страница для работы с дебатлами
  perform data.create_object(
  'debatles',
  jsonb '[
    {"code": "title", "value": "Дебатлы"},
    {"code": "is_visible", "value": true},
    {"code": "content", "value": ["debatles_new", "debatles_future", "debatles_current", "debatles_closed", "debatles_all"], "value_object_code": "master"},
    {"code": "content", "value": ["debatles_my", "debatles_future", "debatles_current", "debatles_closed"]},
    {"code": "actions_function", "value": "pallas_project.actgenerator_debatles"},
    {"code": "independent_from_actor_list_elements", "value": true},
    {"code": "independent_from_object_list_elements", "value": true},
    {
      "code": "mini_card_template",
      "value": {
        "title": "title",
        "groups": []
      }
    },
    {
      "code": "template",
      "value": {
        "title": "title",
        "subtitle": "subtitle",
        "groups": [{"code": "debatles_group", "attributes": ["description"], "actions": ["debatle_create"]}]
      }
    }
  ]');

  -- Объект-класс для списка дебатлов
  perform data.create_class(
  'debatle_list',
  jsonb '[
    {"code": "content", "value": []},
    {
      "code": "mini_card_template",
      "value": {
        "title": "title",
        "groups": []
      }
    },
    {
      "code": "template",
      "value": {
        "title": "title",
        "subtitle": "subtitle",
        "groups": []
      }
    },
    {"code": "independent_from_object_list_elements", "value": true}
  ]');

  -- Списки дебатлов
  perform data.create_object(
  'debatles_all',
  jsonb '[
    {"code": "title", "value": "Все дебатлы"},
    {"code": "is_visible", "value": true, "value_object_code": "master"}
  ]',
  'debatle_list');

  perform data.create_object(
  'debatles_new',
  jsonb '[
    {"code": "title", "value": "Неподтверждённые дебатлы"},
    {"code": "is_visible", "value": true, "value_object_code": "master"}
  ]',
  'debatle_list');

  perform data.create_object(
  'debatles_my',
  jsonb '[
    {"code": "title", "value": "Мои дебатлы"},
    {"code": "is_visible", "value": true}
  ]',
  'debatle_list');

  perform data.create_object(
  'debatles_future',
  jsonb '[
    {"code": "title", "value": "Будущие дебатлы"},
    {"code": "is_visible", "value": true}
  ]',
  'debatle_list');

  perform data.create_object(
  'debatles_current',
  jsonb '[
    {"code": "title", "value": "Текущие дебатлы"},
    {"code": "is_visible", "value": true}
  ]',
  'debatle_list');

  perform data.create_object(
  'debatles_closed',
  jsonb '[
    {"code": "title", "value": "Завершенные дебатлы"},
    {"code": "is_visible", "value": true}
  ]',
  'debatle_list');

  -- Объект-класс для дебатла
  perform data.create_class(
  'debatle',
  jsonb '[
    {"code": "type", "value": "debatle"},
    {"code": "priority", "value": 97},
    {"code": "is_visible", "value": true, "value_object_code": "master"},
    {"code": "actions_function", "value": "pallas_project.actgenerator_debatle"},
    {
      "code": "mini_card_template",
      "value": {
        "title": "title",
        "subtitle": "debatle_status",
        "groups": []
      }
    },
    {
      "code": "template",
      "value": {
      "title": "title",
      "subtitle": "subtitle",
      "groups": [
        {
          "code": "debatle_group1",
          "attributes": ["debatle_theme", "debatle_status", "debatle_person1", "debatle_person2", "debatle_judge", "debatle_target_audience"],
          "actions": [
            "debatle_change_instigator",
            "debatle_change_opponent",
            "debatle_change_judge",
            "debatle_change_theme",
            "debatle_change_subtitle",
            "debatle_change_target_audience"
          ]
        },
        {
          "code": "debatle_group2",
          "actions": [
            "debatle_change_status_new",
            "debatle_change_status_future",
            "debatle_change_status_vote",
            "debatle_change_status_vote_over",
            "debatle_change_status_closed",
            "debatle_change_status_deleted"
          ]
        },
        {
          "code": "debatle_group3",
          "attributes": ["debatle_confirm_presence_link","debatle_person1_votes", "debatle_person2_votes", "debatle_vote_price", "debatle_my_vote"],
          "actions": ["debatle_refresh_link","debatle_vote_person1", "debatle_vote_person2"]
        },
        {
          "code": "debatle_group4",
          "attributes": ["debatle_person1_bonuses", "debatle_person2_bonuses"],
          "actions": ["debatle_change_bonuses1", "debatle_change_bonuses2"]
        },
        {
          "code": "debatle_group5",
          "actions": ["debatle_chat"]
        }
      ]
    }
    }
  ]');

  -- Объект-класс для аудитории дебатла
  perform data.create_class(
  'debatle_target_audience',
  jsonb '[
    {"code": "type", "value": "debatle_target_audience"},
    {"code": "title", "value": "Изменение аудитории дебатла"},
    {"code": "is_visible", "value": true, "value_object_code": "master"},
    {"code": "actions_function", "value": "pallas_project.actgenerator_debatle_target_audience"},
    {"code": "list_actions_function", "value": "pallas_project.actgenerator_debatle_target_audience_content"},
    {"code": "list_element_function", "value": "pallas_project.lef_do_nothing"},
    {"code": "independent_from_actor_list_elements", "value": true},
    {"code": "content", "value": ["all_person", "aster", "opa", "cartel"]},
    {
      "code": "template",
      "value": {
        "title": "title",
        "groups": [
          {
            "code": "debatle_target_audience_group1",
            "attributes": ["debatle_target_audience"],
            "actions": ["go_back"]
          }
        ]
      }
    }
  ]');

  -- Объект-класс для подтверждения присутствия
  perform data.create_class(
  'debatle_confirm_presence',
  jsonb '[
    {"code": "type", "value": "debatle_confirm_presence"},
    {"code": "title", "value": "Подтверждение"},
    {"code": "description", "value": "Спасибо что подтвердили своё присутствие на дебатле"},
    {"code": "is_visible", "value": true},
    {"code": "actions_function", "value": "pallas_project.actgenerator_debatle_confirm_presence"},
    {
      "code": "template",
      "value": {
        "title": "title",
        "groups": [
          {
            "code": "debatle_confirm_presence_group1",
            "attributes": ["description"],
            "actions": ["debatle_confirm_presence"]
          }
        ]
      }
    }
  ]');

  -- Объект-класс для временных списков персон для редактирования дебатла
  perform data.create_class(
  'debatle_temp_person_list',
  jsonb '[
    {"code": "content", "value": []},
    {"code": "actions_function", "value": "pallas_project.actgenerator_debatle_temp_person_list"},
    {"code": "list_element_function", "value": "pallas_project.lef_debatle_temp_person_list"},
    {"code": "temporary_object", "value": true},
    {"code": "independent_from_actor_list_elements", "value": true},
    {"code": "independent_from_object_list_elements", "value": true},
    {
      "code": "template",
      "value": {
        "title": "title",
        "subtitle": "subtitle",
        "groups": [
          {
            "code": "group1",
            "actions": ["debatle_change_person_back"]
          },
          {
            "code": "group2",
            "actions": ["debatle_temp_person_list_edited_person"]
          }
        ]
      }
    }
  ]');

  -- Объект-класс для временных списков персон для редактирования бонусов и штрафов
  perform data.create_class(
  'debatle_temp_bonus_list',
  jsonb '[
    {"code": "content", "value": []},
    {"code": "actions_function", "value": "pallas_project.actgenerator_debatle_temp_bonus_list"},
    {"code": "list_element_function", "value": "pallas_project.lef_debatle_temp_bonus_list"},
    {"code": "independent_from_actor_list_elements", "value": true},
    {"code": "independent_from_object_list_elements", "value": true},
    {"code": "temporary_object", "value": true},
    {
      "code": "template",
      "value": {
      "title": "title",
      "subtitle": "subtitle",
      "groups": [
        {
          "code": "group1",
          "actions": ["debatle_change_bonus_back"]
        },
        {
          "code": "group2",
          "attributes": ["debatle_temp_bonus_list_bonuses", "debatle_temp_bonus_list_person"],
          "actions": ["debatle_change_other_bonus", "debatle_change_other_fine"]
        }
      ]
    }
    }
  ]');

  -- Объекты для списка изменений бонусов и штрафов
  -- Класс
  perform data.create_class(
  'debatle_bonus',
  jsonb '[
    {"code": "is_visible", "value": true},
    {
      "code": "template",
      "value": {
      "title": "title",
      "groups": [{
          "code": "group1",
          "attributes": ["debatle_bonus_votes"]
        }]
      }
    }
  ]');

  perform data.create_object(
  'debatle_bonus_long',
  jsonb '[
    {"code": "title", "value": "затянутое выступление"},
    {"code": "debatle_bonus_votes", "value": -1}
  ]',
  'debatle_bonus');

  perform data.create_object(
  'debatle_bonus_confused',
  jsonb '[
    {"code": "title", "value": "сумбурное выступление"},
    {"code": "debatle_bonus_votes", "value": -1}
  ]',
  'debatle_bonus');

  perform data.create_object(
  'debatle_bonus_shout',
  jsonb '[
    {"code": "title", "value": "крик"},
    {"code": "debatle_bonus_votes", "value": -1}
  ]',
  'debatle_bonus');

  perform data.create_object(
  'debatle_bonus_asters_words',
  jsonb '[
    {"code": "title", "value": "использование астерского"},
    {"code": "debatle_bonus_votes", "value": 1}
  ]',
  'debatle_bonus');

  perform data.create_object(
  'debatle_bonus_poems',
  jsonb '[
    {"code": "title", "value": "использование стихов"},
    {"code": "debatle_bonus_votes", "value": 1}
  ]',
  'debatle_bonus');

  perform data.create_object(
  'debatle_bonus_rap',
  jsonb '[
    {"code": "title", "value": "использование рэпа"},
    {"code": "debatle_bonus_votes", "value": 1}
  ]',
  'debatle_bonus');

  perform data.create_object(
  'debatle_bonus_support',
  jsonb '[
    {"code": "title", "value": "поддержку аудитории"},
    {"code": "debatle_bonus_votes", "value": 1}
  ]',
  'debatle_bonus');

  insert into data.actions(code, function) values
  ('debatle_create', 'pallas_project.act_debatle_create'),
  ('debatle_change_person', 'pallas_project.act_debatle_change_person'),
  ('debatle_change_theme', 'pallas_project.act_debatle_change_theme'),
  ('debatle_change_status', 'pallas_project.act_debatle_change_status'),
  ('debatle_vote', 'pallas_project.act_debatle_vote'),
  ('debatle_change_bonuses', 'pallas_project.act_debatle_change_bonuses'),
  ('debatle_change_other_bonus', 'pallas_project.act_debatle_change_other_bonus'),
  ('debatle_change_subtitle', 'pallas_project.act_debatle_change_subtitle'),
  ('debatle_change_audience_group', 'pallas_project.act_debatle_change_audience_group'),
  ('debatle_confirm_presence', 'pallas_project.act_debatle_confirm_presence'),
  ('debatle_refresh_link', 'pallas_project.act_debatle_refresh_link');

end;
$$
language plpgsql;
