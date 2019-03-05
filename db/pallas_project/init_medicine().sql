-- drop function pallas_project.init_medicine();

create or replace function pallas_project.init_medicine()
returns void
volatile
as
$$
declare

begin
  -- Атрибуты 
  insert into data.attributes(code, name, description, type, card_type, value_description_function, can_be_overridden) values
  ('med_health', null, 'Состояние здоровья персонажа', 'hidden', null, null, false),
-- *format med_health*{"wound": {"level": 3, "start": "26.02.2019 23:58:17", "diagnosted": 5, "job": 4837438}, "radiation": {"level": 4, "start": "26.02.2019 23:58:30", "diagnosted": 9, "job": 4837489}}
  ('med_stimulant', null, 'Данные о приёме стимулятора', 'hidden', null, null, false),
-- *format med_stimulant*{"last": {"job": 4837438}, "cycle1": 1, "cycle2": 3}
  ('med_clinic_money', null, 'Остаток на счёте клиники', 'hidden', null, null, false),
  ('med_person_code', null, 'Код пациента', 'hidden', null, null, false),
  ('med_health_care_status', null, 'Статус обслуживания пациента', 'hidden', null, null, false),
  ('med_drug_qr_link',null, 'Ссылка для QR-кода', 'normal', 'mini', null, false),
  ('med_drug_status', null, 'Статус наркотика', 'normal', null, 'pallas_project.vd_med_drug_status', false),
  ('med_drug_category', null, 'Тип наркотика', 'normal', null, 'pallas_project.vd_med_drug_category', false),
  ('med_drug_effect', 'Эффект', 'Эффект наркотика', 'normal', 'full', 'pallas_project.vd_med_drug_effect', false);

  insert into data.params(code, value, description) values
  ('med_comp_client_ids', jsonb '[1, 2]', 'client_id медицинского компьютера'),
  ('med_wound', '{"l0": {}, "l1": {"time": 5}, "l2": {"time": 15}, "l3": {"time": 1}, "l4": {"time": 3}, "l5": {"time": 5}, "l6": {"time": 5}, "l7": {"time": 5}, "l8": {}}'::jsonb, 'Длительность этапов заболевания'),
  ('med_wound_0', jsonb '"Вы чувствуете себя хорошо, ничего не болит."', 'Сообщение для игрока о состоянии заболевания'),
  ('med_wound_1', jsonb '"Вам больно в месте ранения. Не можете прикасаться к ране и шевелить конечностью."', 'Сообщение для игрока о состоянии заболевания'),
  ('med_wound_2', jsonb '"Вам очень больно, вы теряете много крови."', 'Сообщение для игрока о состоянии заболевания'),
  ('med_wound_3', jsonb '"Вы теряете сознание. При осмотре доктором показываете рану и описываете характер повреждений."', 'Сообщение для игрока о состоянии заболевания'),
  ('med_wound_4', jsonb '""', 'Сообщение для игрока о состоянии заболевания'),
  ('med_wound_5', jsonb '""', 'Сообщение для игрока о состоянии заболевания'),
  ('med_wound_6', jsonb '""', 'Сообщение для игрока о состоянии заболевания'),
  ('med_wound_7', jsonb '""', 'Сообщение для игрока о состоянии заболевания'),
  ('med_wound_8', jsonb '""', 'Сообщение для игрока о состоянии заболевания'),
  ('med_radiation', '{"l0": {}, "l1": {"time": 3}, "l2": {"time": 3}, "l3": {"time": 3}, "l4": {"time": 5}, "l5": {"time": 5}, "l6": {}}'::jsonb, 'Длительность этапов заболевания'),
  ('med_radiation_0', jsonb '"Вы чувствуете себя хорошо, все симптомы прошли."', 'Сообщение для игрока о состоянии заболевания'),
  ('med_radiation_1', jsonb '"Ваша кожа очень чешется, вам больно к ней прикасаться."', 'Сообщение для игрока о состоянии заболевания'),
  ('med_radiation_2', jsonb '"Кожа горит. Кожа очень болит, прикосновения вызывают сильнейшую боль. Вам очень хочется пить и подташнивает. Запахи еды отвратительны."', 'Сообщение для игрока о состоянии заболевания'),
  ('med_radiation_3', jsonb '"Кожа очень болит, прикосновения вызывают сильнейшую боль. Сильная головная боль. Вы видите галлюцинации. Вспомните самый страшный ваш сон - он стал явью."', 'Сообщение для игрока о состоянии заболевания'),
  ('med_radiation_4', jsonb '"Вам стремительно становится хуже. Вам нечем дышать от боли, вы теряете сознание. Доктору при осмотре не говорите ничего, так как при визуальном осмотре лучевую болезнь не видно."', 'Сообщение для игрока о состоянии заболевания'),
  ('med_radiation_5', jsonb '""', 'Сообщение для игрока о состоянии заболевания'),
  ('med_radiation_6', jsonb '""', 'Сообщение для игрока о состоянии заболевания'),
  ('med_asthma', '{"l0": {}, "l1": {"time": 1}, "l2": {"time": 60}, "l3": {"time": 1}, "l4": {"time": 1}, "l5": {"time": 60}, "l6": {"time": 1}, "l7": {"time": 1}, "l8": {"time": 1, "next_level": 5}}'::jsonb, 'Длительность этапов заболевания'),
  ('med_asthma_0', jsonb '"Вы чувствуете себя хорошо, все симптомы прошли."', 'Сообщение для игрока о состоянии заболевания'),
  ('med_asthma_1', jsonb '"У вас жуткий приступ кашля. Пройдет через минуту или после того как вы попьёте горячего."', 'Сообщение для игрока о состоянии заболевания'),
  ('med_asthma_2', jsonb '""', 'Сообщение для игрока о состоянии заболевания'),
  ('med_asthma_3', jsonb '"У вас жуткий приступ кашля. Пройдет через минуту или после того как вы попьёте горячего."', 'Сообщение для игрока о состоянии заболевания'),
  ('med_asthma_4', jsonb '"Вам становится трудно дышать. Вы ненадолго теряете сознание. Придёте в себя когда досчитаете до 60 или если вас приведут в чувство."', 'Сообщение для игрока о состоянии заболевания'),
  ('med_asthma_5', jsonb '""', 'Сообщение для игрока о состоянии заболевания'),
  ('med_asthma_6', jsonb '"У вас жуткий приступ кашля. Пройдет через минуту или после того как вы попьёте горячего."', 'Сообщение для игрока о состоянии заболевания'),
  ('med_asthma_7', jsonb '"Вам становится трудно дышать. Вы ненадолго теряете сознание. Придёте в себя когда досчитаете до 60 или если вас приведут в чувство."', 'Сообщение для игрока о состоянии заболевания'),
  ('med_asthma_8', jsonb '"Вы пришли в себя, но вам очень трудно дышать. Не можете стоять, быстро двигаться или говорить. Через минуту пройдет."', 'Сообщение для игрока о состоянии заболевания'),
  ('med_rio_miamore', '{"l0": {}, "l1": {"time": 10}, "l2": {"time": 10}, "l3": {"time": 5}, "l4": {"time": 2}, "l5": {"time": 1}, "l6": {"time": 1}, "l7": {"time": 10}, "l8": {"time": 10}, "l9": {}}'::jsonb, 'Длительность этапов заболевания'),
  ('med_rio_miamore_0', jsonb '"Вы чувствуете себя хорошо, все симптомы прошли."', 'Сообщение для игрока о состоянии заболевания'),
  ('med_rio_miamore_1', jsonb '"У вас жуткий приступ кашля. Пройдет через минуту или после того как вы попьёте горячего."', 'Сообщение для игрока о состоянии заболевания'),
  ('med_rio_miamore_2', jsonb '"У вас жуткий приступ кашля. Пройдет через минуту или после того как вы попьёте горячего."', 'Сообщение для игрока о состоянии заболевания'),
  ('med_rio_miamore_3', jsonb '"У вас озноб. Вам холодно. Сильная слабость."', 'Сообщение для игрока о состоянии заболевания'),
  ('med_rio_miamore_4', jsonb '"Вас знобит, у вас слабость. Ваша кожа очень чешется, вам больно к ней прикасаться. "', 'Сообщение для игрока о состоянии заболевания'),
  ('med_rio_miamore_5', jsonb '"Вам становится трудно дышать. Вы ненадолго теряете сознание. Придёте в себя когда досчитаете до 60 или если вас приведут в чувство."', 'Сообщение для игрока о состоянии заболевания'),
  ('med_rio_miamore_6', jsonb '"Вы пришли в себя, но вам очень трудно дышать. Не можете стоять, быстро двигаться или говорить. Через минуту пройдет."', 'Сообщение для игрока о состоянии заболевания'),
  ('med_rio_miamore_7', jsonb '"Вам очень больно. Боль пронизывает всё тело. Боль проходит, если не двигаться и лежать. Трудно дышать."', 'Сообщение для игрока о состоянии заболевания'),
  ('med_rio_miamore_8', jsonb '"Вы парализованы. Можете только дышать и говорить."', 'Сообщение для игрока о состоянии заболевания'),
  ('med_rio_miamore_9', jsonb '""', 'Сообщение для игрока о состоянии заболевания'),
  ('med_addiction', '{"l0": {}, "l1": {"time": 120}, "l2": {"time": 5}, "l3": {"time": 20}, "l4": {"time": 20}, "l5": {"time": 20}, "l6": {"time": 20}, "l7": {"time": 15}, "l8": {"time": 15}, "l9": {"time": 5, "next_level": 0}}'::jsonb, 'Длительность этапов заболевания'),
  ('med_addiction_0', jsonb '"Вы чувствуете себя хорошо, все симптомы прошли."', 'Сообщение для игрока о состоянии заболевания'),
  ('med_addiction_1', jsonb '""', 'Сообщение для игрока о состоянии заболевания'),
  ('med_addiction_2', jsonb '"Ваша кожа очень чешется. Выберите место на теле и чешите его периодически."', 'Сообщение для игрока о состоянии заболевания'),
  ('med_addiction_3', jsonb '"Вам очень хочется пить. Выпейте не меньше 2-х стаканов. Или имитируйте."', 'Сообщение для игрока о состоянии заболевания'),
  ('med_addiction_4', jsonb '"Руки трясутся, не можете работать и выполнять точные действия руками."', 'Сообщение для игрока о состоянии заболевания'),
  ('med_addiction_5', jsonb '"Сильно кружится голова, не можете стоять. Через минуту всё пройдёт. Всё ещё не можете работать."', 'Сообщение для игрока о состоянии заболевания'),
  ('med_addiction_6', jsonb '"Следующие 5 минут вам больно от яркого света и шума."', 'Сообщение для игрока о состоянии заболевания'),
  ('med_addiction_7', jsonb '"Вы видите галлюцинации. Вспомните самый страшный ваш сон - он стал явью. И все вокруг участники этого кошмара. Приступ продлится 3 минуты."', 'Сообщение для игрока о состоянии заболевания'),
  ('med_addiction_8', jsonb '"Агрессия. Вам хочется рвать и метать. Вы в ярости! Кричите, рвите! Не успокоитесь, пока не ударите человека или не сломаете что-нибудь."', 'Сообщение для игрока о состоянии заболевания'),
  ('med_addiction_9', jsonb '"Вам очень больно. Боль пронизывает всё тело. Боль проходит, если не двигаться и лежать. Трудно дышать. Приступ продлится 5 минут."', 'Сообщение для игрока о состоянии заболевания'),
  ('med_genetic', '{"l0": {}, "l1": {"time": 10}, "l2": {"time": 5}, "l3": {"time": 20}, "l4": {"time": 20}}'::jsonb, 'Длительность этапов заболевания'),
  ('med_genetic_0', jsonb '"Вы чувствуете себя хорошо, все симптомы прошли."', 'Сообщение для игрока о состоянии заболевания'),
  ('med_genetic_1', jsonb '"У вас жуткий приступ кашля. Пройдет через минуту или после того как вы попьёте горячего."', 'Сообщение для игрока о состоянии заболевания'),
  ('med_genetic_2', jsonb '"У вас озноб. Вам холодно. Сильная слабость."', 'Сообщение для игрока о состоянии заболевания'),
  ('med_genetic_3', jsonb '"Сильно кружится голова, не можете стоять. Через минуту всё пройдёт. Всё ещё не можете работать."', 'Сообщение для игрока о состоянии заболевания'),
  ('med_genetic_4', jsonb '"Следующие 5 минут вам больно от яркого света и шума."', 'Сообщение для игрока о состоянии заболевания');

  -- Объект - страница для заявления заболеваний и ранений
  perform data.create_class(
  'med_health',
  jsonb '[
    {"code": "title", "value": "Состояние здоровья"},
    {"code": "is_visible", "value": true, "value_object_code": "master"},
    {"code": "actions_function", "value": "pallas_project.actgenerator_med_health"},
    {"code": "independent_from_actor_list_elements", "value": true},
    {"code": "independent_from_object_list_elements", "value": true},
    {
      "code": "template",
      "value": {
        "title": "title",
        "subtitle": "subtitle",
        "groups": [{"code": "health_group", 
                    "actions": ["med_light_wound", "med_heavy_wound", "med_irradiated", "med_add_asthma", "med_add_rio_miamore", "med_add_addiction", "med_add_genetic"]}]
      }
    }
  ]');

  perform data.create_object(
  'medicine',
  jsonb '[
    {"code": "title", "value": "Медицинское обслуживание"},
    {"code": "is_visible", "value": true, "value_object_code": "doctor"},
    {"code": "actions_function", "value": "pallas_project.actgenerator_medicine"},
    {
      "code": "template",
      "value": {
        "title": "title",
        "subtitle": "subtitle",
        "groups": [{"code": "medicine_group", 
                    "actions": ["med_start_patient_reception"]}]
      }
    }
  ]');

  perform data.create_object(
  'wrong_medicine',
  jsonb '[
    {"code": "title", "value": "Медицинское обслуживание"},
    {"code": "is_visible", "value": true, "value_object_code": "doctor"},
    {"code": "description", "value": "Зайдите со стационарного медицинского компьютера"},
    {
      "code": "template",
      "value": {
        "title": "title",
        "subtitle": "subtitle",
        "groups": [{"code": "medicine_group", 
                    "attributes": ["description"]}]
      }
    }
  ]');

  perform data.create_class(
  'med_computer',
  jsonb '[
    {"code": "title", "value": "Медицинский компьютер"},
    {"code": "type", "value": "med_computer"},
    {"code": "is_visible", "value": true, "value_object_code": "master"},
    {"code": "is_visible", "value": true, "value_object_code": "doctor"},
    {"code": "actions_function", "value": "pallas_project.actgenerator_med_computer"},
    {"code": "temporary_object", "value": true},
    {
      "code": "template",
      "value": {
        "title": "title",
        "subtitle": "subtitle",
        "groups": [{"code": "diagnostics_group", 
                    "actions": ["med_diagnose_wound", 
                                "med_diagnose_radiation", 
                                "med_diagnose_asthma", 
                                "med_diagnose_rio_miamore", 
                                "med_diagnose_addiction",
                                "med_diagnose_genetic",
                                "med_cure"]}]
      }
    }
  ]');

-- Объект - страница для работы с наркотиками
  perform data.create_object(
  'med_drugs',
  jsonb '[
    {"code": "title", "value": "Наркотики"},
    {"code": "is_visible", "value": true, "value_object_code": "master"},
    {"code": "description", "value": "Нажми кнопку с нужным наркотиком, и он создастся верхним в списке. Из ссылки нужно сгенерить QR."},
    {"code": "content", "value": []},
    {"code": "actions_function", "value": "pallas_project.actgenerator_med_drugs"},
    {"code": "list_element_function", "value": "pallas_project.lef_do_nothing"},
    {"code": "independent_from_actor_list_elements", "value": true},
    {"code": "independent_from_object_list_elements", "value": true},
    {
      "code": "template",
      "value": {
        "title": "title",
        "subtitle": "subtitle",
        "groups": [{"code": "med_drugs_group", 
                    "attributes": ["description"], 
                    "actions": ["med_drugs_add_stimulant", "med_drugs_add_superbuff", "med_drugs_add_sleg"]}]
      }
    }
  ]');

  -- Объект-класс для наркотипа
  perform data.create_class(
  'med_drug',
  jsonb '[
    {"code": "title", "value": "Наркотик"},
    {"code": "type", "value": "med_drug"},
    {"code": "is_visible", "value": true},
    {"code": "actions_function", "value": "pallas_project.actgenerator_med_drug"},
    {
      "code": "mini_card_template",
      "value": {
        "title": "med_drug_category",
        "subtitle": "med_drug_status",
        "groups": [{"code": "med_drug_group", "attributes": ["med_drug_qr_link"]}]
      }
    },
    {
      "code": "template",
      "value": {
        "title": "med_drug_category",
        "subtitle": "subtitle",
        "groups": [
          {
            "code": "med_drug_group1",
            "attributes": ["med_drug_status", "med_drug_effect"],
            "actions": ["med_drug_use"]
          }
        ]
      }
    }
  ]');

  insert into data.actions(code, function) values
  ('med_set_disease_level', 'pallas_project.act_med_set_disease_level'),
  ('med_start_patient_reception','pallas_project.act_med_start_patient_reception'),
  ('med_open_medicine', 'pallas_project.act_med_open_medicine'),
  ('med_cure','pallas_project.act_med_cure'),
  ('med_drugs_add_drug', 'pallas_project.act_med_drugs_add_drug'),
  ('med_drug_use', 'pallas_project.act_med_drug_use');
end;
$$
language plpgsql;
