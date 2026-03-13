-- =====================================================
-- ТРИГГЕРЫ АУДИТ-ЛОГА ДЛЯ ВСЕХ ОСНОВНЫХ ТАБЛИЦ
-- =====================================================

-- Функция для логирования INSERT
CREATE OR REPLACE FUNCTION audit_log_insert()
RETURNS TRIGGER AS $$
DECLARE
    v_details JSONB;
    v_user_id INTEGER;
BEGIN
    -- Пытаемся получить ID текущего пользователя из контекста
    -- (нужно будет устанавливать через SET LOCAL в приложении)
    BEGIN
        v_user_id := current_setting('app.current_user_id')::INTEGER;
    EXCEPTION WHEN OTHERS THEN
        v_user_id := NULL;
    END;
    
    -- Формируем детали: все новые значения
    v_details = jsonb_build_object(
        'new_data', row_to_json(NEW),
        'action', 'INSERT'
    );
    
    INSERT INTO audit_logs (user_id, action, entity_type, entity_id, details, created_at)
    VALUES (
        v_user_id,
        'INSERT',
        TG_TABLE_NAME,
        NEW.application_id,
        v_details,
        NOW()
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Функция для логирования UPDATE
CREATE OR REPLACE FUNCTION audit_log_update()
RETURNS TRIGGER AS $$
DECLARE
    v_details JSONB;
    v_changes JSONB;
    v_user_id INTEGER;
BEGIN
    -- Получаем ID пользователя
    BEGIN
        v_user_id := current_setting('app.current_user_id')::INTEGER;
    EXCEPTION WHEN OTHERS THEN
        v_user_id := NULL;
    END;
    
    -- Формируем JSON с изменениями только тех полей, которые реально изменились
    WITH changed_fields AS (
        SELECT 
            key,
            jsonb_build_object(
                'old', to_jsonb(OLD),
                'new', to_jsonb(NEW)
            ) as field_changes
        FROM jsonb_each(to_jsonb(NEW))
        WHERE to_jsonb(OLD) IS DISTINCT FROM to_jsonb(NEW)
    )
    SELECT jsonb_object_agg(key, field_changes->'new')
    INTO v_changes
    FROM changed_fields;
    
    v_details = jsonb_build_object(
        'changes', v_changes,
        'old_data', row_to_json(OLD)
    );
    
    INSERT INTO audit_logs (user_id, action, entity_type, entity_id, details, created_at)
    VALUES (
        v_user_id,
        'UPDATE',
        TG_TABLE_NAME,
        NEW.application_id,
        v_details,
        NOW()
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Функция для логирования DELETE
CREATE OR REPLACE FUNCTION audit_log_delete()
RETURNS TRIGGER AS $$
DECLARE
    v_details JSONB;
    v_user_id INTEGER;
BEGIN
    BEGIN
        v_user_id := current_setting('app.current_user_id')::INTEGER;
    EXCEPTION WHEN OTHERS THEN
        v_user_id := NULL;
    END;
    
    v_details = jsonb_build_object(
        'deleted_data', row_to_json(OLD),
        'action', 'DELETE'
    );
    
    INSERT INTO audit_logs (user_id, action, entity_type, entity_id, details, created_at)
    VALUES (
        v_user_id,
        'DELETE',
        TG_TABLE_NAME,
        OLD.application_id,
        v_details,
        NOW()
    );
    
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- ТРИГГЕРЫ ДЛЯ ТАБЛИЦЫ APPLICATIONS
-- =====================================================

-- Триггер на INSERT в applications
DROP TRIGGER IF EXISTS trg_applications_audit_insert ON applications;
CREATE TRIGGER trg_applications_audit_insert
    AFTER INSERT ON applications
    FOR EACH ROW
    EXECUTE FUNCTION audit_log_insert();

-- Триггер на UPDATE в applications
DROP TRIGGER IF EXISTS trg_applications_audit_update ON applications;
CREATE TRIGGER trg_applications_audit_update
    AFTER UPDATE ON applications
    FOR EACH ROW
    EXECUTE FUNCTION audit_log_update();

-- Триггер на DELETE в applications
DROP TRIGGER IF EXISTS trg_applications_audit_delete ON applications;
CREATE TRIGGER trg_applications_audit_delete
    BEFORE DELETE ON applications
    FOR EACH ROW
    EXECUTE FUNCTION audit_log_delete();

-- =====================================================
-- ТРИГГЕРЫ ДЛЯ ТАБЛИЦЫ PROPERTIES
-- =====================================================

-- Функция для properties (нужно адаптировать под первичный ключ property_id)
CREATE OR REPLACE FUNCTION audit_log_insert_properties()
RETURNS TRIGGER AS $$
DECLARE
    v_details JSONB;
    v_user_id INTEGER;
BEGIN
    BEGIN
        v_user_id := current_setting('app.current_user_id')::INTEGER;
    EXCEPTION WHEN OTHERS THEN
        v_user_id := NULL;
    END;
    
    v_details = jsonb_build_object(
        'new_data', row_to_json(NEW),
        'action', 'INSERT'
    );
    
    INSERT INTO audit_logs (user_id, action, entity_type, entity_id, details, created_at)
    VALUES (
        v_user_id,
        'INSERT',
        TG_TABLE_NAME,
        NEW.property_id,
        v_details,
        NOW()
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION audit_log_update_properties()
RETURNS TRIGGER AS $$
DECLARE
    v_details JSONB;
    v_changes JSONB;
    v_user_id INTEGER;
BEGIN
    BEGIN
        v_user_id := current_setting('app.current_user_id')::INTEGER;
    EXCEPTION WHEN OTHERS THEN
        v_user_id := NULL;
    END;
    
    WITH changed_fields AS (
        SELECT 
            key,
            jsonb_build_object(
                'old', to_jsonb(OLD),
                'new', to_jsonb(NEW)
            ) as field_changes
        FROM jsonb_each(to_jsonb(NEW))
        WHERE to_jsonb(OLD) IS DISTINCT FROM to_jsonb(NEW)
    )
    SELECT jsonb_object_agg(key, field_changes->'new')
    INTO v_changes
    FROM changed_fields;
    
    v_details = jsonb_build_object(
        'changes', v_changes,
        'old_data', row_to_json(OLD)
    );
    
    INSERT INTO audit_logs (user_id, action, entity_type, entity_id, details, created_at)
    VALUES (
        v_user_id,
        'UPDATE',
        TG_TABLE_NAME,
        NEW.property_id,
        v_details,
        NOW()
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION audit_log_delete_properties()
RETURNS TRIGGER AS $$
DECLARE
    v_details JSONB;
    v_user_id INTEGER;
BEGIN
    BEGIN
        v_user_id := current_setting('app.current_user_id')::INTEGER;
    EXCEPTION WHEN OTHERS THEN
        v_user_id := NULL;
    END;
    
    v_details = jsonb_build_object(
        'deleted_data', row_to_json(OLD),
        'action', 'DELETE'
    );
    
    INSERT INTO audit_logs (user_id, action, entity_type, entity_id, details, created_at)
    VALUES (
        v_user_id,
        'DELETE',
        TG_TABLE_NAME,
        OLD.property_id,
        v_details,
        NOW()
    );
    
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Применяем триггеры для properties
DROP TRIGGER IF EXISTS trg_properties_audit_insert ON properties;
CREATE TRIGGER trg_properties_audit_insert
    AFTER INSERT ON properties
    FOR EACH ROW
    EXECUTE FUNCTION audit_log_insert_properties();

DROP TRIGGER IF EXISTS trg_properties_audit_update ON properties;
CREATE TRIGGER trg_properties_audit_update
    AFTER UPDATE ON properties
    FOR EACH ROW
    EXECUTE FUNCTION audit_log_update_properties();

DROP TRIGGER IF EXISTS trg_properties_audit_delete ON properties;
CREATE TRIGGER trg_properties_audit_delete
    BEFORE DELETE ON properties
    FOR EACH ROW
    EXECUTE FUNCTION audit_log_delete_properties();

-- =====================================================
-- ТРИГГЕРЫ ДЛЯ ТАБЛИЦЫ CONTRACTS
-- =====================================================

-- Функция для contracts (первичный ключ contract_id)
CREATE OR REPLACE FUNCTION audit_log_insert_contracts()
RETURNS TRIGGER AS $$
DECLARE
    v_details JSONB;
    v_user_id INTEGER;
BEGIN
    BEGIN
        v_user_id := current_setting('app.current_user_id')::INTEGER;
    EXCEPTION WHEN OTHERS THEN
        v_user_id := NULL;
    END;
    
    v_details = jsonb_build_object(
        'new_data', row_to_json(NEW),
        'action', 'INSERT'
    );
    
    INSERT INTO audit_logs (user_id, action, entity_type, entity_id, details, created_at)
    VALUES (
        v_user_id,
        'INSERT',
        TG_TABLE_NAME,
        NEW.contract_id,
        v_details,
        NOW()
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION audit_log_update_contracts()
RETURNS TRIGGER AS $$
DECLARE
    v_details JSONB;
    v_changes JSONB;
    v_user_id INTEGER;
BEGIN
    BEGIN
        v_user_id := current_setting('app.current_user_id')::INTEGER;
    EXCEPTION WHEN OTHERS THEN
        v_user_id := NULL;
    END;
    
    WITH changed_fields AS (
        SELECT 
            key,
            jsonb_build_object(
                'old', to_jsonb(OLD),
                'new', to_jsonb(NEW)
            ) as field_changes
        FROM jsonb_each(to_jsonb(NEW))
        WHERE to_jsonb(OLD) IS DISTINCT FROM to_jsonb(NEW)
    )
    SELECT jsonb_object_agg(key, field_changes->'new')
    INTO v_changes
    FROM changed_fields;
    
    v_details = jsonb_build_object(
        'changes', v_changes,
        'old_data', row_to_json(OLD)
    );
    
    INSERT INTO audit_logs (user_id, action, entity_type, entity_id, details, created_at)
    VALUES (
        v_user_id,
        'UPDATE',
        TG_TABLE_NAME,
        NEW.contract_id,
        v_details,
        NOW()
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION audit_log_delete_contracts()
RETURNS TRIGGER AS $$
DECLARE
    v_details JSONB;
    v_user_id INTEGER;
BEGIN
    BEGIN
        v_user_id := current_setting('app.current_user_id')::INTEGER;
    EXCEPTION WHEN OTHERS THEN
        v_user_id := NULL;
    END;
    
    v_details = jsonb_build_object(
        'deleted_data', row_to_json(OLD),
        'action', 'DELETE'
    );
    
    INSERT INTO audit_logs (user_id, action, entity_type, entity_id, details, created_at)
    VALUES (
        v_user_id,
        'DELETE',
        TG_TABLE_NAME,
        OLD.contract_id,
        v_details,
        NOW()
    );
    
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Применяем триггеры для contracts
DROP TRIGGER IF EXISTS trg_contracts_audit_insert ON contracts;
CREATE TRIGGER trg_contracts_audit_insert
    AFTER INSERT ON contracts
    FOR EACH ROW
    EXECUTE FUNCTION audit_log_insert_contracts();

DROP TRIGGER IF EXISTS trg_contracts_audit_update ON contracts;
CREATE TRIGGER trg_contracts_audit_update
    AFTER UPDATE ON contracts
    FOR EACH ROW
    EXECUTE FUNCTION audit_log_update_contracts();

DROP TRIGGER IF EXISTS trg_contracts_audit_delete ON contracts;
CREATE TRIGGER trg_contracts_audit_delete
    BEFORE DELETE ON contracts
    FOR EACH ROW
    EXECUTE FUNCTION audit_log_delete_contracts();

-- =====================================================
-- ТРИГГЕРЫ ДЛЯ ТАБЛИЦЫ USERS
-- =====================================================

-- Функция для users (первичный ключ user_id)
CREATE OR REPLACE FUNCTION audit_log_insert_users()
RETURNS TRIGGER AS $$
DECLARE
    v_details JSONB;
    v_user_id INTEGER;
BEGIN
    BEGIN
        v_user_id := current_setting('app.current_user_id')::INTEGER;
    EXCEPTION WHEN OTHERS THEN
        v_user_id := NULL;
    END;
    
    v_details = jsonb_build_object(
        'new_data', row_to_json(NEW),
        'action', 'INSERT'
    );
    
    INSERT INTO audit_logs (user_id, action, entity_type, entity_id, details, created_at)
    VALUES (
        v_user_id,
        'INSERT',
        TG_TABLE_NAME,
        NEW.user_id,
        v_details,
        NOW()
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION audit_log_update_users()
RETURNS TRIGGER AS $$
DECLARE
    v_details JSONB;
    v_changes JSONB;
    v_user_id INTEGER;
BEGIN
    BEGIN
        v_user_id := current_setting('app.current_user_id')::INTEGER;
    EXCEPTION WHEN OTHERS THEN
        v_user_id := NULL;
    END;
    
    WITH changed_fields AS (
        SELECT 
            key,
            jsonb_build_object(
                'old', to_jsonb(OLD),
                'new', to_jsonb(NEW)
            ) as field_changes
        FROM jsonb_each(to_jsonb(NEW))
        WHERE to_jsonb(OLD) IS DISTINCT FROM to_jsonb(NEW)
    )
    SELECT jsonb_object_agg(key, field_changes->'new')
    INTO v_changes
    FROM changed_fields;
    
    v_details = jsonb_build_object(
        'changes', v_changes,
        'old_data', row_to_json(OLD)
    );
    
    INSERT INTO audit_logs (user_id, action, entity_type, entity_id, details, created_at)
    VALUES (
        v_user_id,
        'UPDATE',
        TG_TABLE_NAME,
        NEW.user_id,
        v_details,
        NOW()
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION audit_log_delete_users()
RETURNS TRIGGER AS $$
DECLARE
    v_details JSONB;
    v_user_id INTEGER;
BEGIN
    BEGIN
        v_user_id := current_setting('app.current_user_id')::INTEGER;
    EXCEPTION WHEN OTHERS THEN
        v_user_id := NULL;
    END;
    
    v_details = jsonb_build_object(
        'deleted_data', row_to_json(OLD),
        'action', 'DELETE'
    );
    
    INSERT INTO audit_logs (user_id, action, entity_type, entity_id, details, created_at)
    VALUES (
        v_user_id,
        'DELETE',
        TG_TABLE_NAME,
        OLD.user_id,
        v_details,
        NOW()
    );
    
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Применяем триггеры для users
DROP TRIGGER IF EXISTS trg_users_audit_insert ON users;
CREATE TRIGGER trg_users_audit_insert
    AFTER INSERT ON users
    FOR EACH ROW
    EXECUTE FUNCTION audit_log_insert_users();

DROP TRIGGER IF EXISTS trg_users_audit_update ON users;
CREATE TRIGGER trg_users_audit_update
    AFTER UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION audit_log_update_users();

DROP TRIGGER IF EXISTS trg_users_audit_delete ON users;
CREATE TRIGGER trg_users_audit_delete
    BEFORE DELETE ON users
    FOR EACH ROW
    EXECUTE FUNCTION audit_log_delete_users();

-- =====================================================
-- ТРИГГЕРЫ ДЛЯ ТАБЛИЦЫ MESSAGES
-- =====================================================

-- Функция для messages (первичный ключ message_id)
CREATE OR REPLACE FUNCTION audit_log_insert_messages()
RETURNS TRIGGER AS $$
DECLARE
    v_details JSONB;
    v_user_id INTEGER;
BEGIN
    BEGIN
        v_user_id := current_setting('app.current_user_id')::INTEGER;
    EXCEPTION WHEN OTHERS THEN
        v_user_id := NULL;
    END;
    
    v_details = jsonb_build_object(
        'new_data', row_to_json(NEW),
        'action', 'INSERT'
    );
    
    INSERT INTO audit_logs (user_id, action, entity_type, entity_id, details, created_at)
    VALUES (
        v_user_id,
        'INSERT',
        TG_TABLE_NAME,
        NEW.message_id,
        v_details,
        NOW()
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION audit_log_update_messages()
RETURNS TRIGGER AS $$
DECLARE
    v_details JSONB;
    v_changes JSONB;
    v_user_id INTEGER;
BEGIN
    BEGIN
        v_user_id := current_setting('app.current_user_id')::INTEGER;
    EXCEPTION WHEN OTHERS THEN
        v_user_id := NULL;
    END;
    
    WITH changed_fields AS (
        SELECT 
            key,
            jsonb_build_object(
                'old', to_jsonb(OLD),
                'new', to_jsonb(NEW)
            ) as field_changes
        FROM jsonb_each(to_jsonb(NEW))
        WHERE to_jsonb(OLD) IS DISTINCT FROM to_jsonb(NEW)
    )
    SELECT jsonb_object_agg(key, field_changes->'new')
    INTO v_changes
    FROM changed_fields;
    
    v_details = jsonb_build_object(
        'changes', v_changes,
        'old_data', row_to_json(OLD)
    );
    
    INSERT INTO audit_logs (user_id, action, entity_type, entity_id, details, created_at)
    VALUES (
        v_user_id,
        'UPDATE',
        TG_TABLE_NAME,
        NEW.message_id,
        v_details,
        NOW()
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION audit_log_delete_messages()
RETURNS TRIGGER AS $$
DECLARE
    v_details JSONB;
    v_user_id INTEGER;
BEGIN
    BEGIN
        v_user_id := current_setting('app.current_user_id')::INTEGER;
    EXCEPTION WHEN OTHERS THEN
        v_user_id := NULL;
    END;
    
    v_details = jsonb_build_object(
        'deleted_data', row_to_json(OLD),
        'action', 'DELETE'
    );
    
    INSERT INTO audit_logs (user_id, action, entity_type, entity_id, details, created_at)
    VALUES (
        v_user_id,
        'DELETE',
        TG_TABLE_NAME,
        OLD.message_id,
        v_details,
        NOW()
    );
    
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Применяем триггеры для messages
DROP TRIGGER IF EXISTS trg_messages_audit_insert ON messages;
CREATE TRIGGER trg_messages_audit_insert
    AFTER INSERT ON messages
    FOR EACH ROW
    EXECUTE FUNCTION audit_log_insert_messages();

DROP TRIGGER IF EXISTS trg_messages_audit_update ON messages;
CREATE TRIGGER trg_messages_audit_update
    AFTER UPDATE ON messages
    FOR EACH ROW
    EXECUTE FUNCTION audit_log_update_messages();

DROP TRIGGER IF EXISTS trg_messages_audit_delete ON messages;
CREATE TRIGGER trg_messages_audit_delete
    BEFORE DELETE ON messages
    FOR EACH ROW
    EXECUTE FUNCTION audit_log_delete_messages();

-- =====================================================
-- ФУНКЦИЯ ДЛЯ УСТАНОВКИ ID ПОЛЬЗОВАТЕЛЯ В КОНТЕКСТ
-- =====================================================

-- Эту функцию нужно вызывать из приложения перед каждым запросом,
-- чтобы триггеры знали, кто совершает действие
CREATE OR REPLACE FUNCTION set_current_user_id(user_id INTEGER)
RETURNS VOID AS $$
BEGIN
    PERFORM set_config('app.current_user_id', user_id::TEXT, TRUE);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- ТЕСТОВЫЙ ЗАПРОС ДЛЯ ПРОВЕРКИ
-- =====================================================

-- Установка пользователя для теста (ID=1 - админ)
SELECT set_current_user_id(1);

-- Тест: создадим тестовую заявку (если нужно проверить)
-- INSERT INTO applications (property_id, tenant_id, message, desired_date, duration_days, status, created_at)
-- VALUES (1, 6, 'Тестовая заявка для аудита', '2026-04-01', 365, 'pending', NOW());

-- Проверка аудит-лога
SELECT * FROM audit_logs ORDER BY created_at DESC LIMIT 10;