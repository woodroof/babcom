-- drop function data.calc_content_diff(jsonb, jsonb);

create or replace function data.calc_content_diff(in_original_content jsonb, in_new_content jsonb)
returns jsonb
volatile
as
$$
-- add - массив объектов с полями position и object_code, position может отсутствовать
-- remove - массив кодов объектов
declare
  v_add jsonb := jsonb '[]';
  v_remove jsonb := jsonb '[]';
  v_code jsonb;
begin
  assert in_original_content is null or json.is_string_array(in_original_content);
  assert in_new_content is null or json.is_string_array(in_new_content);

  if
    in_original_content is null and in_new_content is null or
    in_original_content = in_new_content
  then
    return jsonb '{"add": [], "remove": []}';
  end if;

  if in_new_content is null or in_new_content = jsonb '[]' then
    v_remove := coalesce(in_original_content, jsonb '[]');
  elsif in_original_content is null or in_original_content = '[]' then
    for v_code in
    (
      select value
      from jsonb_array_elements(in_new_content)
    )
    loop
      v_add := v_add || jsonb_build_object('object_code', v_code);
    end loop;
  else
    declare
      v_original_idx integer := 0;
      v_original_size integer := jsonb_array_length(in_original_content);
      v_new_idx integer := 0;
      v_new_size integer := jsonb_array_length(in_new_content);
      v_current_original_value jsonb;
      v_current_new_value jsonb;
      v_original_test_idx integer;
      v_new_test_idx integer;
      v_remove_indexes integer[];
      v_modified_content jsonb := in_original_content;
    begin
      -- Сначала определим, что нужно удалить
      while v_original_idx != v_original_size and v_new_idx != v_new_size loop
        v_current_original_value := in_original_content->v_original_idx;
        v_current_new_value := in_new_content->v_new_idx;

        if v_current_original_value = v_current_new_value then
          v_original_idx := v_original_idx + 1;
          v_new_idx := v_new_idx + 1;
        else
          v_original_test_idx :=
            json.array_find(in_original_content, v_current_new_value, v_original_idx + 1);
          v_new_test_idx :=
            json.array_find(in_new_content, v_current_original_value, v_new_idx + 1);

          -- Определяем, что эффективнее - удалять объекты из оригинального массива или добавлять в результирующий
          if v_original_test_idx is not null and v_new_test_idx is not null then
            if v_original_test_idx - v_original_idx <= v_new_test_idx - v_new_idx then
              -- Удаляем
              while v_original_idx != v_original_test_idx loop
                v_remove_indexes := array_prepend(v_original_idx, v_remove_indexes);
                v_remove := v_remove || (in_original_content->v_original_idx);
                v_original_idx := v_original_idx + 1;
              end loop;

              v_original_idx := v_original_idx + 1;
              v_new_idx := v_new_idx + 1;
            else
              v_original_idx := v_original_idx + 1;
              v_new_idx := v_new_test_idx + 1;
            end if;
          elsif v_original_test_idx is null then
            v_new_idx := v_new_idx + 1;
          else
            v_remove_indexes := array_prepend(v_original_idx, v_remove_indexes);
            v_remove := v_remove || (in_original_content->v_original_idx);
            v_original_idx := v_original_idx + 1;
          end if;
        end if;
      end loop;

      while v_original_idx != v_original_size loop
        v_remove_indexes := array_prepend(v_original_idx, v_remove_indexes);
        v_remove := v_remove || (in_original_content->v_original_idx);
        v_original_idx := v_original_idx + 1;
      end loop;

      -- Потом удалим из оригинального массива всё, что решили удалять
      for v_original_idx in
        select value
        from unnest(v_remove_indexes) a(value)
      loop
        v_modified_content := v_modified_content - v_original_idx;
      end loop;

      -- Теперь сгенерируем добавления
      v_new_idx := 0;
      v_original_size := jsonb_array_length(v_modified_content);

      if v_new_size = v_original_size then
        v_new_idx := v_new_size;
      elsif v_original_size > 0 then
        v_original_idx := 0;

        loop
          v_current_original_value := v_modified_content->v_original_idx;
          v_current_new_value := in_new_content->v_new_idx;

          if v_current_original_value = v_current_new_value then
            v_original_idx := v_original_idx + 1;
            v_new_idx := v_new_idx + 1;

            assert v_new_idx != v_new_size;

            if v_original_idx = v_original_size then
              exit;
            end if;
          else
            v_add :=
              v_add ||
              jsonb_build_object('position', v_current_original_value, 'object_code', v_current_new_value);
            v_new_idx := v_new_idx + 1;

            if v_new_size - v_new_idx = v_original_size - v_original_idx then
              v_new_idx := v_new_size;
              exit;
            end if;
          end if;
        end loop;
      end if;

      while v_new_idx != v_new_size loop
        v_add :=
          v_add ||
          jsonb_build_object('object_code', in_new_content->v_new_idx);
        v_new_idx := v_new_idx + 1;
      end loop;
    end;
  end if;

  return jsonb_build_object('add', v_add, 'remove', v_remove);
end;
$$
language plpgsql;
