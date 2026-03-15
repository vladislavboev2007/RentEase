--
-- PostgreSQL database dump
--

\restrict JXZ7QSFCu8N3sLbzH1nu2kq6ygnHedQIWHISQZ1JM8DhWy3VAFiKz4j5wJodi1U

-- Dumped from database version 18.1
-- Dumped by pg_dump version 18.1

-- Started on 2026-03-15 22:15:28

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 252 (class 1255 OID 90264)
-- Name: audit_log_delete(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.audit_log_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_details JSONB;
    v_user_id INTEGER;
    v_entity_id INTEGER;
BEGIN
    -- Получаем ID пользователя
    BEGIN
        v_user_id := current_setting('app.current_user_id')::INTEGER;
    EXCEPTION WHEN OTHERS THEN
        v_user_id := NULL;
    END;
    
    -- Определяем ID в зависимости от таблицы
    IF TG_TABLE_NAME = 'applications' THEN
        v_entity_id := OLD.application_id;
    ELSIF TG_TABLE_NAME = 'properties' THEN
        v_entity_id := OLD.property_id;
    ELSIF TG_TABLE_NAME = 'contracts' THEN
        v_entity_id := OLD.contract_id;
    ELSIF TG_TABLE_NAME = 'users' THEN
        v_entity_id := OLD.user_id;
    ELSIF TG_TABLE_NAME = 'messages' THEN
        v_entity_id := OLD.message_id;
    ELSE
        v_entity_id := NULL;
    END IF;
    
    v_details = jsonb_build_object(
        'deleted_data', row_to_json(OLD),
        'action', 'DELETE',
        'table', TG_TABLE_NAME
    );
    
    INSERT INTO audit_logs (user_id, action, entity_type, entity_id, details, created_at)
    VALUES (
        v_user_id,
        'DELETE',
        TG_TABLE_NAME,
        v_entity_id,
        v_details,
        NOW()
    );
    
    RETURN OLD;
END;
$$;


ALTER FUNCTION public.audit_log_delete() OWNER TO postgres;

--
-- TOC entry 250 (class 1255 OID 90262)
-- Name: audit_log_insert(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.audit_log_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_details JSONB;
    v_user_id INTEGER;
    v_entity_id INTEGER;
BEGIN
    -- Получаем ID пользователя из контекста
    BEGIN
        v_user_id := current_setting('app.current_user_id')::INTEGER;
    EXCEPTION WHEN OTHERS THEN
        v_user_id := NULL;
    END;
    
    -- Определяем ID в зависимости от таблицы
    IF TG_TABLE_NAME = 'applications' THEN
        v_entity_id := NEW.application_id;
    ELSIF TG_TABLE_NAME = 'properties' THEN
        v_entity_id := NEW.property_id;
    ELSIF TG_TABLE_NAME = 'contracts' THEN
        v_entity_id := NEW.contract_id;
    ELSIF TG_TABLE_NAME = 'users' THEN
        v_entity_id := NEW.user_id;
    ELSIF TG_TABLE_NAME = 'messages' THEN
        v_entity_id := NEW.message_id;
    ELSE
        v_entity_id := NULL;
    END IF;
    
    -- Формируем детали
    v_details = jsonb_build_object(
        'new_data', row_to_json(NEW),
        'action', 'INSERT',
        'table', TG_TABLE_NAME
    );
    
    INSERT INTO audit_logs (user_id, action, entity_type, entity_id, details, created_at)
    VALUES (
        v_user_id,
        'INSERT',
        TG_TABLE_NAME,
        v_entity_id,
        v_details,
        NOW()
    );
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.audit_log_insert() OWNER TO postgres;

--
-- TOC entry 251 (class 1255 OID 90263)
-- Name: audit_log_update(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.audit_log_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_details JSONB;
    v_changes JSONB;
    v_user_id INTEGER;
    v_entity_id INTEGER;
BEGIN
    -- Получаем ID пользователя
    BEGIN
        v_user_id := current_setting('app.current_user_id')::INTEGER;
    EXCEPTION WHEN OTHERS THEN
        v_user_id := NULL;
    END;
    
    -- Определяем ID в зависимости от таблицы
    IF TG_TABLE_NAME = 'applications' THEN
        v_entity_id := NEW.application_id;
    ELSIF TG_TABLE_NAME = 'properties' THEN
        v_entity_id := NEW.property_id;
    ELSIF TG_TABLE_NAME = 'contracts' THEN
        v_entity_id := NEW.contract_id;
    ELSIF TG_TABLE_NAME = 'users' THEN
        v_entity_id := NEW.user_id;
    ELSIF TG_TABLE_NAME = 'messages' THEN
        v_entity_id := NEW.message_id;
    ELSE
        v_entity_id := NULL;
    END IF;
    
    -- Формируем JSON с изменениями (только измененные поля)
    WITH changed_fields AS (
        SELECT 
            key,
            jsonb_build_object(
                'old', to_jsonb(OLD) -> key,
                'new', to_jsonb(NEW) -> key
            ) as field_change
        FROM jsonb_each(to_jsonb(NEW))
        WHERE (to_jsonb(OLD) ->> key) IS DISTINCT FROM (to_jsonb(NEW) ->> key)
            AND key NOT IN ('password_hash', 'created_at') -- Исключаем чувствительные поля
    )
    SELECT jsonb_object_agg(key, field_change)
    INTO v_changes
    FROM changed_fields;
    
    -- Если есть изменения, логируем
    IF v_changes IS NOT NULL AND v_changes != '{}'::jsonb THEN
        v_details = jsonb_build_object(
            'changes', v_changes,
            'old_data', row_to_json(OLD),
            'table', TG_TABLE_NAME
        );
        
        INSERT INTO audit_logs (user_id, action, entity_type, entity_id, details, created_at)
        VALUES (
            v_user_id,
            'UPDATE',
            TG_TABLE_NAME,
            v_entity_id,
            v_details,
            NOW()
        );
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.audit_log_update() OWNER TO postgres;

--
-- TOC entry 247 (class 1255 OID 82019)
-- Name: create_contract_on_approval(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.create_contract_on_approval() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_property properties%ROWTYPE;
    v_total_amount NUMERIC;
    v_tenant_name TEXT;
    v_property_title TEXT;
    v_owner_id INTEGER;
    v_new_contract_id INTEGER;
BEGIN
    -- Если статус изменился на 'approved'
    IF NEW.status = 'approved' AND OLD.status != 'approved' THEN
        -- Получаем данные объекта
        SELECT * INTO v_property FROM properties WHERE property_id = NEW.property_id;
        v_owner_id := v_property.owner_id;

        -- Получаем название объекта
        SELECT title INTO v_property_title FROM properties WHERE property_id = NEW.property_id;

        -- Получаем имя арендатора
        SELECT COALESCE(full_name, 'Арендатор') INTO v_tenant_name
        FROM users WHERE user_id = NEW.tenant_id;

        -- Рассчитываем общую сумму
        IF v_property.interval_pay = 'month' THEN
            v_total_amount := v_property.price * CEIL(NEW.duration_days / 30.0);
        ELSIF v_property.interval_pay = 'week' THEN
            v_total_amount := v_property.price * CEIL(NEW.duration_days / 7.0);
        ELSE
            v_total_amount := v_property.price;
        END IF;

        -- Вставляем договор
        INSERT INTO contracts (
            application_id,
            start_date,
            end_date,
            total_amount,
            signing_status,
            tenant_signed,
            owner_signed,
            created_at
        ) VALUES (
            NEW.application_id,
            NEW.desired_date,
            NEW.desired_date + (NEW.duration_days || ' days')::INTERVAL,
            v_total_amount,
            'draft',
            FALSE,
            FALSE,
            NOW()
        ) RETURNING contract_id INTO v_new_contract_id;

        -- Уведомление арендатору о создании договора (без смайлика в тексте)
        INSERT INTO messages (from_user_id, to_user_id, content, is_read, created_at)
        VALUES (NULL, NEW.tenant_id,
                '📄 Договор создан на объект "' || v_property_title || '". Ожидается подписание.',
                FALSE, NOW());

        -- Уведомление собственнику о создании договора
        INSERT INTO messages (from_user_id, to_user_id, content, is_read, created_at)
        VALUES (NULL, v_owner_id,
                '📄 Договор создан на объект "' || v_property_title || '" с арендатором ' || v_tenant_name || '. Ожидается подписание.',
                FALSE, NOW());

        -- Обновляем время ответа
        NEW.responded_at := NOW();
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.create_contract_on_approval() OWNER TO postgres;

--
-- TOC entry 253 (class 1255 OID 49248)
-- Name: get_agent_application_status_stats(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_agent_application_status_stats(p_agent_id integer, p_days integer DEFAULT 90) RETURNS TABLE(status character varying, count bigint, percentage numeric)
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    v_total BIGINT;
    v_start_date TIMESTAMP;
BEGIN
    -- Начало периода - p_days дней назад
    v_start_date := (CURRENT_DATE - (p_days || ' days')::INTERVAL)::TIMESTAMP;

    SELECT COUNT(*) INTO v_total
    FROM applications a
    JOIN properties p ON a.property_id = p.property_id
    WHERE p.owner_id = p_agent_id
      AND a.created_at >= v_start_date;

    RETURN QUERY
    SELECT 
        a.status,
        COUNT(*) as count,
        CASE 
            WHEN v_total > 0 THEN ROUND(COUNT(*) * 100.0 / v_total, 2)
            ELSE 0
        END as percentage
    FROM applications a
    JOIN properties p ON a.property_id = p.property_id
    WHERE p.owner_id = p_agent_id
      AND a.created_at >= v_start_date
    GROUP BY a.status
    ORDER BY 
        CASE a.status
            WHEN 'pending' THEN 1
            WHEN 'approved' THEN 2
            WHEN 'rejected' THEN 3
            WHEN 'cancelled' THEN 4
            WHEN 'completed' THEN 5
            ELSE 6
        END;
END;
$$;


ALTER FUNCTION public.get_agent_application_status_stats(p_agent_id integer, p_days integer) OWNER TO postgres;

--
-- TOC entry 256 (class 1255 OID 49246)
-- Name: get_agent_monthly_stats(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_agent_monthly_stats(p_agent_id integer, p_months integer DEFAULT 6) RETURNS TABLE(month text, deals_count bigint, total_profit numeric, applications_count bigint, approved_count bigint, rejected_count bigint)
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    RETURN QUERY
    WITH months_series AS (
        -- Генерируем последовательность месяцев, включая текущий и начиная с (p_months-1) месяцев назад
        SELECT 
            DATE_TRUNC('month', CURRENT_DATE - (n || ' months')::INTERVAL) as month_start,
            TO_CHAR(DATE_TRUNC('month', CURRENT_DATE - (n || ' months')::INTERVAL), 'YYYY-MM') as month_str
        FROM generate_series(0, p_months - 1) n
    ),
    monthly_applications AS (
        SELECT 
            DATE_TRUNC('month', a.created_at) as month,
            COUNT(DISTINCT a.application_id) as apps_count,
            COUNT(DISTINCT CASE WHEN a.status = 'approved' THEN a.application_id END) as approved,
            COUNT(DISTINCT CASE WHEN a.status = 'rejected' THEN a.application_id END) as rejected
        FROM applications a
        JOIN properties p ON a.property_id = p.property_id
        WHERE p.owner_id = p_agent_id
          AND a.created_at >= (DATE_TRUNC('month', CURRENT_DATE - ((p_months - 1) || ' months')::INTERVAL))
        GROUP BY DATE_TRUNC('month', a.created_at)
    ),
    monthly_contracts AS (
        SELECT 
            DATE_TRUNC('month', c.created_at) as month,
            COUNT(DISTINCT c.contract_id) as deals,
            COALESCE(SUM(c.total_amount), 0) as profit
        FROM contracts c
        JOIN applications a ON c.application_id = a.application_id
        JOIN properties p ON a.property_id = p.property_id
        WHERE p.owner_id = p_agent_id
          AND c.signing_status = 'signed'
          AND c.created_at >= (DATE_TRUNC('month', CURRENT_DATE - ((p_months - 1) || ' months')::INTERVAL))
        GROUP BY DATE_TRUNC('month', c.created_at)
    )
    SELECT 
        ms.month_str,
        COALESCE(mc.deals, 0) as deals_count,
        COALESCE(mc.profit, 0) as total_profit,
        COALESCE(ma.apps_count, 0) as applications_count,
        COALESCE(ma.approved, 0) as approved_count,
        COALESCE(ma.rejected, 0) as rejected_count
    FROM months_series ms
    LEFT JOIN monthly_applications ma ON ms.month_start = ma.month
    LEFT JOIN monthly_contracts mc ON ms.month_start = mc.month
    ORDER BY ms.month_start ASC;
END;
$$;


ALTER FUNCTION public.get_agent_monthly_stats(p_agent_id integer, p_months integer) OWNER TO postgres;

--
-- TOC entry 248 (class 1255 OID 49247)
-- Name: get_agent_performance_stats(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_agent_performance_stats(p_agent_id integer, p_months integer DEFAULT 6) RETURNS TABLE(total_profit numeric, avg_profit_per_property numeric, total_deals bigint, occupancy_rate numeric, processed_applications bigint, avg_response_hours numeric, conversion_rate numeric)
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    v_total_profit NUMERIC := 0;
    v_total_deals BIGINT := 0;
    v_properties_count BIGINT := 0;
    v_rented_properties BIGINT := 0;
    v_processed_apps BIGINT := 0;
    v_total_applications BIGINT := 0;
    v_avg_response NUMERIC := 0;
    v_conversion NUMERIC := 0;
    v_start_date TIMESTAMP;
BEGIN
    -- Начало периода - ПЕРВОЕ ЧИСЛО месяца (p_months-1) месяцев назад
    -- Например: для 13 месяцев в марте 2026, начало = 2025-03-01
    v_start_date := DATE_TRUNC('month', CURRENT_DATE - ((p_months - 1) || ' months')::INTERVAL);

    -- Сделки и прибыль
    SELECT 
        COALESCE(SUM(c.total_amount), 0),
        COUNT(DISTINCT c.contract_id)
    INTO v_total_profit, v_total_deals
    FROM contracts c
    JOIN applications a ON c.application_id = a.application_id
    JOIN properties p ON a.property_id = p.property_id
    WHERE p.owner_id = p_agent_id
      AND c.signing_status = 'signed'
      AND c.created_at >= v_start_date;

    -- Все объекты агента
    SELECT COUNT(*) INTO v_properties_count
    FROM properties
    WHERE owner_id = p_agent_id;

    -- Сданные объекты
    SELECT COUNT(*) INTO v_rented_properties
    FROM properties
    WHERE owner_id = p_agent_id 
      AND status = 'rented';

    -- Обработанные заявки
    SELECT COUNT(*) INTO v_processed_apps
    FROM applications a
    JOIN properties p ON a.property_id = p.property_id
    WHERE p.owner_id = p_agent_id
      AND a.responded_at IS NOT NULL
      AND a.created_at >= v_start_date;

    -- Все заявки за период
    SELECT COUNT(*) INTO v_total_applications
    FROM applications a
    JOIN properties p ON a.property_id = p.property_id
    WHERE p.owner_id = p_agent_id
      AND a.created_at >= v_start_date;

    -- Среднее время ответа
    SELECT COALESCE(ROUND(AVG(EXTRACT(EPOCH FROM (a.responded_at - a.created_at)) / 3600)::NUMERIC, 2), 0)
    INTO v_avg_response
    FROM applications a
    JOIN properties p ON a.property_id = p.property_id
    WHERE p.owner_id = p_agent_id
      AND a.responded_at IS NOT NULL
      AND a.created_at >= v_start_date;

    -- Конверсия
    IF v_total_applications > 0 THEN
        v_conversion := ROUND((v_total_deals::NUMERIC / v_total_applications * 100)::NUMERIC, 2);
    END IF;

    RETURN QUERY
    SELECT 
        ROUND(v_total_profit, 2),
        CASE 
            WHEN v_properties_count > 0 THEN ROUND(v_total_profit / v_properties_count, 2)
            ELSE 0
        END,
        v_total_deals,
        CASE 
            WHEN v_properties_count > 0 THEN ROUND((v_rented_properties * 100.0 / v_properties_count), 2)
            ELSE 0
        END,
        v_processed_apps,
        v_avg_response,
        v_conversion;
END;
$$;


ALTER FUNCTION public.get_agent_performance_stats(p_agent_id integer, p_months integer) OWNER TO postgres;

--
-- TOC entry 255 (class 1255 OID 90207)
-- Name: notify_application_status_change(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.notify_application_status_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_property_title TEXT;
    v_owner_id INTEGER;
    v_owner_name TEXT;
    v_status_text TEXT;
BEGIN
    -- Если статус не изменился, ничего не делаем
    IF OLD.status = NEW.status THEN
        RETURN NEW;
    END IF;

    -- Получаем название объекта
    SELECT title INTO v_property_title
    FROM properties
    WHERE property_id = NEW.property_id;

    -- Определяем текст уведомления в зависимости от нового статуса
    CASE NEW.status
        WHEN 'approved' THEN
            v_status_text := '✅ Заявка одобрена';
        WHEN 'rejected' THEN
            v_status_text := '❌ Заявка отклонена';
        WHEN 'cancelled' THEN
            v_status_text := '🚫 Заявка отменена';
        ELSE
            v_status_text := '📋 Заявка ' || NEW.status;
    END CASE;

    -- Уведомление арендатору об изменении статуса (только одно!)
    INSERT INTO messages (from_user_id, to_user_id, content, is_read, created_at)
    VALUES (NULL, NEW.tenant_id,
            v_status_text || ' на объект "' || v_property_title || '"',
            FALSE, NOW());

    -- Если есть ответ, добавляем отдельное уведомление с текстом ответа
    IF NEW.answer IS NOT NULL AND NEW.answer != '' AND NEW.answer != OLD.answer THEN
        -- Получаем имя собственника
        SELECT COALESCE(u.full_name, 'Собственник') INTO v_owner_name
        FROM properties p
        LEFT JOIN users u ON p.owner_id = u.user_id
        WHERE p.property_id = NEW.property_id;

        INSERT INTO messages (from_user_id, to_user_id, content, is_read, created_at)
        VALUES (NULL, NEW.tenant_id,
                '💬 Ответ от ' || v_owner_name || ': ' || NEW.answer,
                FALSE, NOW());
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.notify_application_status_change() OWNER TO postgres;

--
-- TOC entry 246 (class 1255 OID 90211)
-- Name: notify_contract_cancellation(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.notify_contract_cancellation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_tenant_id INTEGER;
    v_owner_id INTEGER;
    v_property_title TEXT;
    v_tenant_name TEXT;
    v_owner_name TEXT;
    v_contract_number TEXT;
BEGIN
    IF NEW.signing_status = 'cancelled' AND OLD.signing_status != 'cancelled' THEN
        -- Получаем информацию о договоре
        SELECT a.tenant_id, p.owner_id, p.title,
               COALESCE(tu.full_name, 'Арендатор') as tenant_name,
               COALESCE(ou.full_name, 'Собственник') as owner_name
        INTO v_tenant_id, v_owner_id, v_property_title, v_tenant_name, v_owner_name
        FROM applications a
        JOIN properties p ON a.property_id = p.property_id
        LEFT JOIN users tu ON tu.user_id = a.tenant_id
        LEFT JOIN users ou ON ou.user_id = p.owner_id
        WHERE a.application_id = NEW.application_id;

        -- Формируем номер договора
        v_contract_number := 'Д-' || NEW.contract_id;

        -- Уведомление арендатору
        INSERT INTO messages (from_user_id, to_user_id, content, is_read, created_at)
        VALUES (NULL, v_tenant_id,
                '🚫 **Договор отменён** ' || v_contract_number || ' на объект "' || v_property_title || '"',
                FALSE, NOW());

        -- Уведомление собственнику
        INSERT INTO messages (from_user_id, to_user_id, content, is_read, created_at)
        VALUES (NULL, v_owner_id,
                '🚫 **Договор отменён** ' || v_contract_number || ' на объект "' || v_property_title || '"',
                FALSE, NOW());

        -- Возвращаем статус объекта на 'active' если нужно
        -- UPDATE properties SET status = 'active' 
        -- WHERE property_id = (SELECT property_id FROM applications WHERE application_id = NEW.application_id);
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.notify_contract_cancellation() OWNER TO postgres;

--
-- TOC entry 254 (class 1255 OID 90209)
-- Name: notify_contract_signature(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.notify_contract_signature() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_tenant_id INTEGER;
    v_owner_id INTEGER;
    v_property_title TEXT;
    v_tenant_name TEXT;
    v_owner_name TEXT;
    v_contract_number TEXT;
BEGIN
    -- Получаем связанные данные через application
    SELECT a.tenant_id, p.owner_id, p.title,
           COALESCE(tu.full_name, 'Арендатор') as tenant_name,
           COALESCE(ou.full_name, 'Собственник') as owner_name
    INTO v_tenant_id, v_owner_id, v_property_title, v_tenant_name, v_owner_name
    FROM applications a
    JOIN properties p ON a.property_id = p.property_id
    LEFT JOIN users tu ON tu.user_id = a.tenant_id
    LEFT JOIN users ou ON ou.user_id = p.owner_id
    WHERE a.application_id = NEW.application_id;

    -- Проверяем, что данные получены
    IF v_tenant_id IS NULL OR v_owner_id IS NULL THEN
        RETURN NEW;
    END IF;

    -- Формируем номер договора
    v_contract_number := 'Д-' || NEW.contract_id;

    -- Если арендатор только что подписал
    IF NEW.tenant_signed IS DISTINCT FROM OLD.tenant_signed AND NEW.tenant_signed = TRUE THEN
        INSERT INTO messages (from_user_id, to_user_id, content, is_read, created_at)
        VALUES (NULL, v_owner_id,
                '✍️ **Арендатор подписал договор** ' || v_contract_number || ': ' || v_tenant_name || ' подписал договор на объект "' || v_property_title || '"',
                FALSE, NOW());
    END IF;

    -- Если собственник только что подписал
    IF NEW.owner_signed IS DISTINCT FROM OLD.owner_signed AND NEW.owner_signed = TRUE THEN
        INSERT INTO messages (from_user_id, to_user_id, content, is_read, created_at)
        VALUES (NULL, v_tenant_id,
                '✍️ **Собственник подписал договор** ' || v_contract_number || ': ' || v_owner_name || ' подписал договор на объект "' || v_property_title || '"',
                FALSE, NOW());
    END IF;

    -- Если статус договора стал 'signed' (обе стороны подписали)
    IF NEW.signing_status = 'signed' AND (OLD.signing_status IS DISTINCT FROM 'signed') THEN
        -- Уведомление арендатору
        INSERT INTO messages (from_user_id, to_user_id, content, is_read, created_at)
        VALUES (NULL, v_tenant_id,
                '✅ **Договор полностью подписан** ' || v_contract_number || ' на объект "' || v_property_title || '"',
                FALSE, NOW());

        -- Уведомление собственнику
        INSERT INTO messages (from_user_id, to_user_id, content, is_read, created_at)
        VALUES (NULL, v_owner_id,
                '✅ **Договор полностью подписан** ' || v_contract_number || ' на объект "' || v_property_title || '"',
                FALSE, NOW());

        -- Обновляем статус объекта на 'rented'
        UPDATE properties SET status = 'rented' 
        WHERE property_id = (SELECT property_id FROM applications WHERE application_id = NEW.application_id);
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.notify_contract_signature() OWNER TO postgres;

--
-- TOC entry 237 (class 1255 OID 98398)
-- Name: notify_new_application(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.notify_new_application() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_property_title TEXT;
    v_owner_id INTEGER;
    v_tenant_name TEXT;
BEGIN
    -- Получаем название объекта и ID собственника
    SELECT p.title, p.owner_id INTO v_property_title, v_owner_id
    FROM properties p
    WHERE p.property_id = NEW.property_id;

    -- Получаем имя арендатора
    SELECT COALESCE(full_name, 'Арендатор') INTO v_tenant_name
    FROM users
    WHERE user_id = NEW.tenant_id;

    -- Уведомление собственнику о новой заявке
    INSERT INTO messages (from_user_id, to_user_id, content, is_read, created_at)
    VALUES (NULL, v_owner_id,
            '📋 **Новая заявка** от ' || v_tenant_name || ' на объект "' || v_property_title || '"',
            FALSE, NOW());

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.notify_new_application() OWNER TO postgres;

--
-- TOC entry 249 (class 1255 OID 90243)
-- Name: set_current_user_id(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.set_current_user_id(user_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM set_config('app.current_user_id', user_id::TEXT, TRUE);
END;
$$;


ALTER FUNCTION public.set_current_user_id(user_id integer) OWNER TO postgres;

--
-- TOC entry 245 (class 1255 OID 82017)
-- Name: update_contract_signing_status(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_contract_signing_status() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Если договор отменён, не меняем статус
    IF NEW.signing_status = 'cancelled' THEN
        RETURN NEW;
    END IF;

    -- Проверяем, подписали ли обе стороны
    IF NEW.tenant_signed = true AND NEW.owner_signed = true THEN
        NEW.signing_status = 'signed';
    ELSIF NEW.tenant_signed = true OR NEW.owner_signed = true THEN
        -- Если хотя бы одна сторона подписала, но не все
        NEW.signing_status = 'pending';
    ELSE
        -- Если никто не подписал
        NEW.signing_status = 'draft';
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_contract_signing_status() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 226 (class 1259 OID 32838)
-- Name: applications; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.applications (
    application_id integer NOT NULL,
    property_id integer NOT NULL,
    tenant_id integer NOT NULL,
    message text,
    desired_date date,
    duration_days integer,
    answer text,
    status character varying(20) DEFAULT 'pending'::character varying,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    responded_at timestamp without time zone,
    CONSTRAINT applications_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'approved'::character varying, 'rejected'::character varying, 'completed'::character varying, 'cancelled'::character varying])::text[])))
);


ALTER TABLE public.applications OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 32837)
-- Name: applications_application_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.applications_application_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.applications_application_id_seq OWNER TO postgres;

--
-- TOC entry 5046 (class 0 OID 0)
-- Dependencies: 225
-- Name: applications_application_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.applications_application_id_seq OWNED BY public.applications.application_id;


--
-- TOC entry 232 (class 1259 OID 32930)
-- Name: audit_logs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.audit_logs (
    log_id integer NOT NULL,
    user_id integer,
    action character varying(100) NOT NULL,
    entity_type character varying(30) NOT NULL,
    entity_id integer,
    details jsonb,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.audit_logs OWNER TO postgres;

--
-- TOC entry 231 (class 1259 OID 32929)
-- Name: audit_logs_log_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.audit_logs_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.audit_logs_log_id_seq OWNER TO postgres;

--
-- TOC entry 5047 (class 0 OID 0)
-- Dependencies: 231
-- Name: audit_logs_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.audit_logs_log_id_seq OWNED BY public.audit_logs.log_id;


--
-- TOC entry 228 (class 1259 OID 32868)
-- Name: contracts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.contracts (
    contract_id integer NOT NULL,
    application_id integer,
    start_date date NOT NULL,
    end_date date,
    total_amount numeric(12,2) NOT NULL,
    signing_status character varying(10) DEFAULT 'draft'::character varying,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    tenant_signed boolean DEFAULT false,
    owner_signed boolean DEFAULT false,
    CONSTRAINT contracts_signing_status_check CHECK (((signing_status)::text = ANY ((ARRAY['draft'::character varying, 'pending'::character varying, 'signed'::character varying, 'cancelled'::character varying])::text[])))
);


ALTER TABLE public.contracts OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 32867)
-- Name: contracts_contract_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.contracts_contract_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.contracts_contract_id_seq OWNER TO postgres;

--
-- TOC entry 5048 (class 0 OID 0)
-- Dependencies: 227
-- Name: contracts_contract_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.contracts_contract_id_seq OWNED BY public.contracts.contract_id;


--
-- TOC entry 230 (class 1259 OID 32907)
-- Name: messages; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.messages (
    message_id integer NOT NULL,
    from_user_id integer,
    to_user_id integer,
    content text NOT NULL,
    is_read boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.messages OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 32906)
-- Name: messages_message_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.messages_message_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.messages_message_id_seq OWNER TO postgres;

--
-- TOC entry 5049 (class 0 OID 0)
-- Dependencies: 229
-- Name: messages_message_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.messages_message_id_seq OWNED BY public.messages.message_id;


--
-- TOC entry 222 (class 1259 OID 32789)
-- Name: properties; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.properties (
    property_id integer NOT NULL,
    owner_id integer,
    title character varying(200) NOT NULL,
    description text,
    address character varying(300) NOT NULL,
    city character varying(100) NOT NULL,
    property_type character varying(20),
    area numeric(8,2) NOT NULL,
    rooms integer,
    price numeric(10,2) NOT NULL,
    interval_pay character varying(20),
    status character varying(20) DEFAULT 'draft'::character varying,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT properties_interval_pay_check CHECK (((interval_pay)::text = ANY ((ARRAY['once'::character varying, 'week'::character varying, 'month'::character varying])::text[]))),
    CONSTRAINT properties_property_type_check CHECK (((property_type)::text = ANY ((ARRAY['apartment'::character varying, 'house'::character varying, 'commercial'::character varying])::text[]))),
    CONSTRAINT properties_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'active'::character varying, 'rented'::character varying, 'archived'::character varying])::text[])))
);


ALTER TABLE public.properties OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 32788)
-- Name: properties_property_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.properties_property_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.properties_property_id_seq OWNER TO postgres;

--
-- TOC entry 5050 (class 0 OID 0)
-- Dependencies: 221
-- Name: properties_property_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.properties_property_id_seq OWNED BY public.properties.property_id;


--
-- TOC entry 224 (class 1259 OID 32819)
-- Name: property_photos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.property_photos (
    photo_id integer NOT NULL,
    property_id integer NOT NULL,
    url character varying(500) NOT NULL,
    is_main boolean DEFAULT false,
    sequence_number integer NOT NULL
);


ALTER TABLE public.property_photos OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 32818)
-- Name: property_photos_photo_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.property_photos_photo_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.property_photos_photo_id_seq OWNER TO postgres;

--
-- TOC entry 5051 (class 0 OID 0)
-- Dependencies: 223
-- Name: property_photos_photo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.property_photos_photo_id_seq OWNED BY public.property_photos.photo_id;


--
-- TOC entry 220 (class 1259 OID 32770)
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    user_id integer NOT NULL,
    email character varying(100) NOT NULL,
    password_hash character varying(255) NOT NULL,
    avatar_url text,
    full_name character varying(150),
    user_type character varying(10) NOT NULL,
    contact_info jsonb DEFAULT '{}'::jsonb,
    is_active boolean DEFAULT true,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT users_user_type_check CHECK (((user_type)::text = ANY ((ARRAY['tenant'::character varying, 'owner'::character varying, 'agent'::character varying, 'admin'::character varying])::text[])))
);


ALTER TABLE public.users OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 32769)
-- Name: users_user_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.users_user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.users_user_id_seq OWNER TO postgres;

--
-- TOC entry 5052 (class 0 OID 0)
-- Dependencies: 219
-- Name: users_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_user_id_seq OWNED BY public.users.user_id;


--
-- TOC entry 4807 (class 2604 OID 32841)
-- Name: applications application_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.applications ALTER COLUMN application_id SET DEFAULT nextval('public.applications_application_id_seq'::regclass);


--
-- TOC entry 4818 (class 2604 OID 32933)
-- Name: audit_logs log_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_logs ALTER COLUMN log_id SET DEFAULT nextval('public.audit_logs_log_id_seq'::regclass);


--
-- TOC entry 4810 (class 2604 OID 32871)
-- Name: contracts contract_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contracts ALTER COLUMN contract_id SET DEFAULT nextval('public.contracts_contract_id_seq'::regclass);


--
-- TOC entry 4815 (class 2604 OID 32910)
-- Name: messages message_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages ALTER COLUMN message_id SET DEFAULT nextval('public.messages_message_id_seq'::regclass);


--
-- TOC entry 4802 (class 2604 OID 32792)
-- Name: properties property_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.properties ALTER COLUMN property_id SET DEFAULT nextval('public.properties_property_id_seq'::regclass);


--
-- TOC entry 4805 (class 2604 OID 32822)
-- Name: property_photos photo_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.property_photos ALTER COLUMN photo_id SET DEFAULT nextval('public.property_photos_photo_id_seq'::regclass);


--
-- TOC entry 4798 (class 2604 OID 32773)
-- Name: users user_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN user_id SET DEFAULT nextval('public.users_user_id_seq'::regclass);


--
-- TOC entry 5034 (class 0 OID 32838)
-- Dependencies: 226
-- Data for Name: applications; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.applications (application_id, property_id, tenant_id, message, desired_date, duration_days, answer, status, created_at, responded_at) FROM stdin;
282	161	11	Интересует аренда на длительный срок	2025-03-16	294	Добро пожаловать! Жду на подписание	rejected	2025-03-02 00:00:00	2025-03-04 00:00:00
283	159	7	Интересует аренда на длительный срок	2025-04-03	406	К сожалению, объект уже сдан	approved	2025-03-20 00:00:00	2025-03-23 00:00:00
284	159	11	Нужна дополнительная информация	2025-03-25	435	Добро пожаловать! Жду на подписание	approved	2025-03-11 00:00:00	2025-03-14 00:00:00
285	158	9	Интересует аренда на длительный срок	2025-03-30	373	Добро пожаловать! Жду на подписание	approved	2025-03-16 00:00:00	2025-03-23 00:00:00
286	5	17	Нужна дополнительная информация	2025-03-20	428	К сожалению, объект уже сдан	rejected	2025-03-06 00:00:00	2025-03-10 00:00:00
287	151	19	Нужна дополнительная информация	2025-03-28	310	Добро пожаловать! Жду на подписание	approved	2025-03-14 00:00:00	2025-03-15 00:00:00
288	165	11	Нужна дополнительная информация	2025-04-03	493	Можем встретиться для обсуждения	approved	2025-03-20 00:00:00	2025-03-26 00:00:00
289	133	18	Отличный вариант, готов обсудить условия	2025-04-06	473	Добро пожаловать! Жду на подписание	approved	2025-03-23 00:00:00	2025-03-25 00:00:00
290	1	7	Нужна дополнительная информация	2025-03-20	472	К сожалению, объект уже сдан	rejected	2025-03-06 00:00:00	2025-03-06 00:00:00
291	144	11	Отличный вариант, готов обсудить условия	2025-03-22	193	\N	pending	2025-03-08 00:00:00	\N
292	154	6	Хочу посмотреть объект в ближайшее время	2025-03-30	225	\N	pending	2025-03-16 00:00:00	\N
293	138	18	Интересует аренда на длительный срок	2025-04-02	437	К сожалению, объект уже сдан	approved	2025-03-19 00:00:00	2025-03-22 00:00:00
294	150	13	Интересует аренда на длительный срок	2025-05-02	466	К сожалению, объект уже сдан	rejected	2025-04-18 00:00:00	2025-04-18 00:00:00
295	158	11	Отличный вариант, готов обсудить условия	2025-04-29	311	К сожалению, объект уже сдан	rejected	2025-04-15 00:00:00	2025-04-18 00:00:00
296	6	7	Отличный вариант, готов обсудить условия	2025-04-28	458	\N	pending	2025-04-14 00:00:00	\N
297	164	18	Хочу посмотреть объект в ближайшее время	2025-04-21	240	К сожалению, объект уже сдан	approved	2025-04-07 00:00:00	2025-04-11 00:00:00
298	129	16	Нужна дополнительная информация	2025-05-03	406	Добро пожаловать! Жду на подписание	approved	2025-04-19 00:00:00	2025-04-25 00:00:00
299	151	16	Хочу посмотреть объект в ближайшее время	2025-04-29	450	Добро пожаловать! Жду на подписание	approved	2025-04-15 00:00:00	2025-04-21 00:00:00
300	154	6	Хочу посмотреть объект в ближайшее время	2025-04-20	351	К сожалению, объект уже сдан	approved	2025-04-06 00:00:00	2025-04-13 00:00:00
301	130	7	Хочу посмотреть объект в ближайшее время	2025-04-20	360	\N	pending	2025-04-06 00:00:00	\N
302	6	16	Интересует аренда на длительный срок	2025-05-04	493	Можем встретиться для обсуждения	rejected	2025-04-20 00:00:00	2025-04-21 00:00:00
303	156	11	Нужна дополнительная информация	2025-05-07	303	К сожалению, объект уже сдан	rejected	2025-04-23 00:00:00	2025-04-28 00:00:00
304	142	18	Хочу посмотреть объект в ближайшее время	2025-05-03	298	Добро пожаловать! Жду на подписание	approved	2025-04-19 00:00:00	2025-04-25 00:00:00
305	4	6	Нужна дополнительная информация	2025-05-17	314	Добро пожаловать! Жду на подписание	approved	2025-05-03 00:00:00	2025-05-03 00:00:00
306	142	13	Интересует аренда на длительный срок	2025-06-03	385	\N	pending	2025-05-20 00:00:00	\N
307	144	7	Интересует аренда на длительный срок	2025-05-28	471	\N	pending	2025-05-14 00:00:00	\N
308	159	15	Отличный вариант, готов обсудить условия	2025-05-28	528	\N	pending	2025-05-14 00:00:00	\N
2	2	7	Очень понравилась квартира, готов заключить договор	2024-06-10	180	Принято, жду вас в пятницу	approved	2026-02-13 21:58:34.48767	2026-02-14 21:58:34
3	3	6	Дороговато, есть возможность торга?	2024-06-20	30	Цена фиксированная	rejected	2026-02-13 21:58:34.488671	2026-02-14 11:58:34
1	1	6	Интересует квартира, хотел бы посмотреть в выходные	2024-06-15	365	Извините но уже поздно	rejected	2026-02-13 21:58:34.485672	2026-03-09 19:58:31.090004
127	129	6	Интересует таунхаус для постоянного проживания	2026-03-10	365	\N	rejected	2026-02-23 16:20:00	2026-03-09 20:06:14.10428
309	146	9	Нужна дополнительная информация	2025-05-21	518	К сожалению, объект уже сдан	approved	2025-05-07 00:00:00	2025-05-12 00:00:00
319	149	11	Нужна дополнительная информация	2025-07-02	270	Извините, уже поздно! Счастливого вам!	rejected	2025-06-18 00:00:00	2026-03-15 16:14:09.402629
330	158	11	Отличный вариант, готов обсудить условия	2025-07-21	544	Уже поздно, извините!	rejected	2025-07-07 00:00:00	2026-03-15 16:18:42.245079
310	131	11	Нужна дополнительная информация	2025-05-19	503	К сожалению, объект уже сдан	approved	2025-05-05 00:00:00	2025-05-10 00:00:00
311	141	15	Отличный вариант, готов обсудить условия	2025-06-09	269	Добро пожаловать! Жду на подписание	approved	2025-05-26 00:00:00	2025-05-31 00:00:00
312	6	13	Отличный вариант, готов обсудить условия	2025-07-06	402	\N	pending	2025-06-22 00:00:00	\N
313	129	11	Хочу посмотреть объект в ближайшее время	2025-06-29	238	Можем встретиться для обсуждения	rejected	2025-06-15 00:00:00	2025-06-17 00:00:00
314	150	11	Хочу посмотреть объект в ближайшее время	2025-06-30	314	Добро пожаловать! Жду на подписание	approved	2025-06-16 00:00:00	2025-06-16 00:00:00
315	158	6	Хочу посмотреть объект в ближайшее время	2025-06-17	216	К сожалению, объект уже сдан	rejected	2025-06-03 00:00:00	2025-06-05 00:00:00
316	146	6	Нужна дополнительная информация	2025-06-25	268	Добро пожаловать! Жду на подписание	approved	2025-06-11 00:00:00	2025-06-12 00:00:00
317	153	15	Интересует аренда на длительный срок	2025-06-16	294	К сожалению, объект уже сдан	approved	2025-06-02 00:00:00	2025-06-08 00:00:00
318	139	9	Нужна дополнительная информация	2025-07-01	509	Добро пожаловать! Жду на подписание	approved	2025-06-17 00:00:00	2025-06-21 00:00:00
320	4	13	Нужна дополнительная информация	2025-06-16	186	\N	pending	2025-06-02 00:00:00	\N
321	156	6	Интересует аренда на длительный срок	2025-07-21	361	Добро пожаловать! Жду на подписание	approved	2025-07-07 00:00:00	2025-07-09 00:00:00
322	6	6	Хочу посмотреть объект в ближайшее время	2025-07-18	390	\N	pending	2025-07-04 00:00:00	\N
323	152	17	Нужна дополнительная информация	2025-07-16	296	Добро пожаловать! Жду на подписание	rejected	2025-07-02 00:00:00	2025-07-08 00:00:00
324	147	15	Отличный вариант, готов обсудить условия	2025-07-29	412	Добро пожаловать! Жду на подписание	rejected	2025-07-15 00:00:00	2025-07-17 00:00:00
325	164	17	Интересует аренда на длительный срок	2025-07-27	314	Добро пожаловать! Жду на подписание	approved	2025-07-13 00:00:00	2025-07-15 00:00:00
326	129	15	Хочу посмотреть объект в ближайшее время	2025-08-04	242	Можем встретиться для обсуждения	rejected	2025-07-21 00:00:00	2025-07-28 00:00:00
327	139	13	Хочу посмотреть объект в ближайшее время	2025-08-07	436	Можем встретиться для обсуждения	rejected	2025-07-24 00:00:00	2025-07-29 00:00:00
328	128	9	Отличный вариант, готов обсудить условия	2025-07-29	416	Добро пожаловать! Жду на подписание	approved	2025-07-15 00:00:00	2025-07-18 00:00:00
329	153	13	Отличный вариант, готов обсудить условия	2025-07-26	284	\N	pending	2025-07-12 00:00:00	\N
331	151	6	Хочу посмотреть объект в ближайшее время	2025-07-18	386	Можем встретиться для обсуждения	rejected	2025-07-04 00:00:00	2025-07-07 00:00:00
332	141	6	Хочу посмотреть объект в ближайшее время	2025-08-24	399	Можем встретиться для обсуждения	approved	2025-08-10 00:00:00	2025-08-12 00:00:00
333	150	17	Интересует аренда на длительный срок	2025-08-29	199	К сожалению, объект уже сдан	approved	2025-08-15 00:00:00	2025-08-16 00:00:00
334	161	13	Нужна дополнительная информация	2025-08-21	419	Можем встретиться для обсуждения	rejected	2025-08-07 00:00:00	2025-08-09 00:00:00
335	158	17	Нужна дополнительная информация	2025-09-05	377	Можем встретиться для обсуждения	rejected	2025-08-22 00:00:00	2025-08-25 00:00:00
336	157	11	Нужна дополнительная информация	2025-08-24	216	Добро пожаловать! Жду на подписание	approved	2025-08-10 00:00:00	2025-08-12 00:00:00
337	153	15	Интересует аренда на длительный срок	2025-09-09	467	К сожалению, объект уже сдан	approved	2025-08-26 00:00:00	2025-09-01 00:00:00
338	151	18	Отличный вариант, готов обсудить условия	2025-10-05	303	Добро пожаловать! Жду на подписание	approved	2025-09-21 00:00:00	2025-09-26 00:00:00
339	140	15	Хочу посмотреть объект в ближайшее время	2025-09-18	242	Добро пожаловать! Жду на подписание	approved	2025-09-04 00:00:00	2025-09-05 00:00:00
340	155	17	Хочу посмотреть объект в ближайшее время	2025-09-26	516	\N	pending	2025-09-12 00:00:00	\N
341	165	9	Интересует аренда на длительный срок	2025-10-02	211	К сожалению, объект уже сдан	approved	2025-09-18 00:00:00	2025-09-23 00:00:00
342	140	6	Интересует аренда на длительный срок	2025-09-24	204	Добро пожаловать! Жду на подписание	approved	2025-09-10 00:00:00	2025-09-17 00:00:00
343	128	11	Интересует аренда на длительный срок	2025-09-25	507	К сожалению, объект уже сдан	approved	2025-09-11 00:00:00	2025-09-13 00:00:00
344	144	16	Нужна дополнительная информация	2025-10-25	209	К сожалению, объект уже сдан	approved	2025-10-11 00:00:00	2025-10-13 00:00:00
345	156	9	Хочу посмотреть объект в ближайшее время	2025-10-22	343	\N	pending	2025-10-08 00:00:00	\N
346	153	16	Нужна дополнительная информация	2025-10-16	205	Добро пожаловать! Жду на подписание	approved	2025-10-02 00:00:00	2025-10-02 00:00:00
347	146	19	Отличный вариант, готов обсудить условия	2025-11-07	281	Добро пожаловать! Жду на подписание	approved	2025-10-24 00:00:00	2025-10-27 00:00:00
348	5	7	Интересует аренда на длительный срок	2025-10-19	537	Добро пожаловать! Жду на подписание	rejected	2025-10-05 00:00:00	2025-10-10 00:00:00
349	5	7	Нужна дополнительная информация	2025-11-08	462	\N	pending	2025-10-25 00:00:00	\N
350	160	18	Нужна дополнительная информация	2025-11-07	368	Добро пожаловать! Жду на подписание	approved	2025-10-24 00:00:00	2025-10-24 00:00:00
351	167	19	Отличный вариант, готов обсудить условия	2025-10-21	367	Можем встретиться для обсуждения	rejected	2025-10-07 00:00:00	2025-10-11 00:00:00
151	3	11	Отличный вариант, готов обсудить условия	2025-02-05	634	Предлагаю встретиться в пятницу	approved	2025-01-29 00:00:00	2025-01-29 00:00:00
352	163	9	Нужна дополнительная информация	2025-10-29	209	Добро пожаловать! Жду на подписание	rejected	2025-10-15 00:00:00	2025-10-16 00:00:00
354	2	18	Хочу посмотреть объект в ближайшее время	2025-11-07	480	К сожалению, объект уже сдан	rejected	2025-10-24 00:00:00	2025-10-30 00:00:00
355	129	19	Нужна дополнительная информация	2025-12-09	351	Можем встретиться для обсуждения	rejected	2025-11-25 00:00:00	2025-12-01 00:00:00
356	130	16	Хочу посмотреть объект в ближайшее время	2025-11-29	407	Можем встретиться для обсуждения	approved	2025-11-15 00:00:00	2025-11-20 00:00:00
357	161	15	Нужна дополнительная информация	2025-11-15	271	Добро пожаловать! Жду на подписание	approved	2025-11-01 00:00:00	2025-11-07 00:00:00
358	5	17	Интересует аренда на длительный срок	2025-12-06	519	\N	pending	2025-11-22 00:00:00	\N
359	133	11	Нужна дополнительная информация	2025-11-25	236	Можем встретиться для обсуждения	rejected	2025-11-11 00:00:00	2025-11-16 00:00:00
160	2	7	Ищу жилье в этом районе, очень понравилось описание	2025-02-22	365	Обсудим при встрече	approved	2025-02-21 00:00:00	2025-02-16 00:00:00
360	143	16	Отличный вариант, готов обсудить условия	2025-11-18	297	К сожалению, объект уже сдан	approved	2025-11-04 00:00:00	2025-11-07 00:00:00
162	142	6	Планирую отдых летом, интересует аренда на курортный сезон	2025-07-22	127	Объект свободен на эти даты, жду подтверждения	approved	2025-04-02 00:00:00	2025-03-30 00:00:00
163	138	15	Планирую отдых летом, интересует аренда на курортный сезон	2025-08-09	139	Объект свободен на эти даты, жду подтверждения	approved	2025-03-23 00:00:00	2025-03-28 00:00:00
165	145	7	Планирую отдых летом, интересует аренда на курортный сезон	2025-08-14	116	Объект свободен на эти даты, жду подтверждения	approved	2025-03-24 00:00:00	2025-03-20 00:00:00
166	144	13	Планирую отдых летом, интересует аренда на курортный сезон	2025-07-23	121	Объект свободен на эти даты, жду подтверждения	approved	2025-03-04 00:00:00	2025-03-29 00:00:00
167	140	7	Планирую отдых летом, интересует аренда на курортный сезон	2025-08-11	99	Объект свободен на эти даты, жду подтверждения	approved	2025-03-19 00:00:00	2025-03-17 00:00:00
168	144	18	Планирую отдых летом, интересует аренда на курортный сезон	2025-07-06	121	Объект свободен на эти даты, жду подтверждения	approved	2025-04-06 00:00:00	2025-03-22 00:00:00
170	143	17	Планирую отдых летом, интересует аренда на курортный сезон	2025-08-07	112	Объект свободен на эти даты, жду подтверждения	approved	2025-03-12 00:00:00	2025-03-23 00:00:00
171	166	15	Планирую отдых летом, интересует аренда на курортный сезон	2025-08-18	118	Объект свободен на эти даты, жду подтверждения	approved	2025-03-11 00:00:00	2025-03-22 00:00:00
172	143	6	Планирую отдых летом, интересует аренда на курортный сезон	2025-07-23	142	Объект свободен на эти даты, жду подтверждения	approved	2025-03-21 00:00:00	2025-03-29 00:00:00
173	145	7	Планирую отдых летом, интересует аренда на курортный сезон	2025-07-05	129	Объект свободен на эти даты, жду подтверждения	approved	2025-04-06 00:00:00	2025-03-28 00:00:00
174	138	19	Планирую отдых летом, интересует аренда на курортный сезон	2025-07-28	90	Объект свободен на эти даты, жду подтверждения	approved	2025-04-15 00:00:00	2025-03-17 00:00:00
175	165	7	Планирую отдых летом, интересует аренда на курортный сезон	2025-07-20	110	Объект свободен на эти даты, жду подтверждения	approved	2025-03-29 00:00:00	2025-03-20 00:00:00
139	131	9	Желаю заселиться	2026-03-01	34	\N	cancelled	2026-02-26 17:26:41.519866	2026-02-26 13:45:00
140	133	9	Мне нужно заселиться	2026-03-15	140	\N	pending	2026-03-09 09:24:57.84671	2026-03-09 13:45:00
353	149	17	Интересует аренда на длительный срок	2026-03-21	180	По коммунальным причинам перенес уменьшил кол-во дней.	approved	2025-10-04 00:00:00	2026-03-15 21:04:53.018707
141	129	9	Как можно скорее	2026-03-19	365	\N	approved	2026-03-09 19:17:20.68289	2026-03-10 09:17:20
176	147	17	Планирую отдых летом, интересует аренда на курортный сезон	2025-08-24	100	Объект свободен на эти даты, жду подтверждения	approved	2025-03-30 00:00:00	2025-03-17 00:00:00
361	140	16	Нужна дополнительная информация	2025-12-04	452	К сожалению, объект уже сдан	approved	2025-11-20 00:00:00	2025-11-22 00:00:00
178	2	13	Срочно требуется жилье	2025-06-13	365	Можем заключить договор	approved	2025-05-16 00:00:00	2025-05-26 00:00:00
362	153	16	Нужна дополнительная информация	2025-11-27	426	К сожалению, объект уже сдан	approved	2025-11-13 00:00:00	2025-11-15 00:00:00
363	152	9	Отличный вариант, готов обсудить условия	2025-11-24	220	Можем встретиться для обсуждения	approved	2025-11-10 00:00:00	2025-11-10 00:00:00
364	133	17	Отличный вариант, готов обсудить условия	2025-11-26	502	Можем встретиться для обсуждения	approved	2025-11-12 00:00:00	2025-11-16 00:00:00
365	157	16	Нужна дополнительная информация	2025-12-23	442	Добро пожаловать! Жду на подписание	rejected	2025-12-09 00:00:00	2025-12-12 00:00:00
366	3	18	Отличный вариант, готов обсудить условия	2025-12-15	456	Добро пожаловать! Жду на подписание	rejected	2025-12-01 00:00:00	2025-12-06 00:00:00
367	159	16	Хочу посмотреть объект в ближайшее время	2025-12-23	182	К сожалению, объект уже сдан	approved	2025-12-09 00:00:00	2025-12-15 00:00:00
368	4	15	Хочу посмотреть объект в ближайшее время	2025-12-31	389	Добро пожаловать! Жду на подписание	rejected	2025-12-17 00:00:00	2025-12-18 00:00:00
369	132	15	Нужна дополнительная информация	2025-12-27	446	К сожалению, объект уже сдан	approved	2025-12-13 00:00:00	2025-12-15 00:00:00
370	165	13	Интересует аренда на длительный срок	2026-02-02	407	Добро пожаловать! Жду на подписание	rejected	2026-01-19 00:00:00	2026-01-24 00:00:00
371	165	16	Интересует аренда на длительный срок	2026-02-04	256	\N	pending	2026-01-21 00:00:00	\N
189	2	15	Срочно требуется жилье	2025-06-16	365	Можем заключить договор	approved	2025-05-15 00:00:00	2025-05-18 00:00:00
372	2	7	Интересует аренда на длительный срок	2026-02-06	183	Добро пожаловать! Жду на подписание	approved	2026-01-23 00:00:00	2026-01-24 00:00:00
373	166	17	Хочу посмотреть объект в ближайшее время	2026-02-01	459	\N	pending	2026-01-18 00:00:00	\N
192	4	19	Срочно требуется жилье	2025-06-23	365	Можем заключить договор	approved	2025-05-05 00:00:00	2025-05-23 00:00:00
374	149	19	Отличный вариант, готов обсудить условия	2026-01-29	213	\N	pending	2026-01-15 00:00:00	\N
375	6	19	Нужна дополнительная информация	2026-02-06	347	Можем встретиться для обсуждения	approved	2026-01-23 00:00:00	2026-01-29 00:00:00
197	139	19	Хотим снять на лето	2025-07-26	71	Подтверждаю бронь	approved	2025-06-22 00:00:00	2025-07-16 00:00:00
198	145	17	Хотим снять на лето	2025-08-21	108	Подтверждаю бронь	approved	2025-07-11 00:00:00	2025-07-12 00:00:00
199	142	6	Хотим снять на лето	2025-08-16	105	Подтверждаю бронь	approved	2025-06-27 00:00:00	2025-07-06 00:00:00
200	138	17	Хотим снять на лето	2025-08-06	88	Подтверждаю бронь	approved	2025-06-16 00:00:00	2025-07-15 00:00:00
201	149	15	Хотим снять на лето	2025-08-13	87	Подтверждаю бронь	approved	2025-06-29 00:00:00	2025-07-02 00:00:00
202	141	11	Хотим снять на лето	2025-07-17	80	Подтверждаю бронь	approved	2025-07-03 00:00:00	2025-07-07 00:00:00
203	144	16	Хотим снять на лето	2025-08-15	79	Подтверждаю бронь	approved	2025-07-01 00:00:00	2025-07-08 00:00:00
204	165	15	Хотим снять на лето	2025-08-02	78	Подтверждаю бронь	approved	2025-06-20 00:00:00	2025-07-08 00:00:00
205	139	18	Хотим снять на лето	2025-08-24	87	Подтверждаю бронь	approved	2025-07-01 00:00:00	2025-07-11 00:00:00
206	138	19	Хотим снять на лето	2025-08-03	72	Подтверждаю бронь	approved	2025-07-12 00:00:00	2025-07-02 00:00:00
207	142	11	Хотим снять на лето	2025-08-19	93	Подтверждаю бронь	approved	2025-06-17 00:00:00	2025-07-11 00:00:00
208	143	16	Хотим снять на лето	2025-08-15	87	Подтверждаю бронь	approved	2025-06-25 00:00:00	2025-07-03 00:00:00
209	138	6	Хотим снять на лето	2025-07-31	93	Подтверждаю бронь	approved	2025-06-18 00:00:00	2025-07-13 00:00:00
210	149	16	Хотим снять на лето	2025-08-07	66	Подтверждаю бронь	approved	2025-07-04 00:00:00	2025-07-09 00:00:00
211	142	11	Хотим снять на лето	2025-07-27	98	Подтверждаю бронь	approved	2025-07-09 00:00:00	2025-07-14 00:00:00
212	140	16	Хотим снять на лето	2025-08-26	86	Подтверждаю бронь	approved	2025-06-20 00:00:00	2025-07-10 00:00:00
213	165	15	Хотим снять на лето	2025-08-10	72	Подтверждаю бронь	approved	2025-07-09 00:00:00	2025-07-07 00:00:00
214	149	7	Хотим снять на лето	2025-08-26	88	Подтверждаю бронь	approved	2025-06-16 00:00:00	2025-07-01 00:00:00
215	165	15	Хотим снять на лето	2025-08-01	75	Подтверждаю бронь	approved	2025-07-14 00:00:00	2025-07-14 00:00:00
216	140	17	Хотим снять на лето	2025-08-06	71	Подтверждаю бронь	approved	2025-06-26 00:00:00	2025-07-09 00:00:00
217	144	7	Хотим снять на лето	2025-07-18	68	Подтверждаю бронь	approved	2025-06-21 00:00:00	2025-07-07 00:00:00
218	146	18	Хотим снять на лето	2025-07-19	66	Подтверждаю бронь	approved	2025-07-13 00:00:00	2025-07-05 00:00:00
219	143	18	Хотим снять на лето	2025-08-10	79	Подтверждаю бронь	approved	2025-06-20 00:00:00	2025-07-07 00:00:00
220	140	13	Хотим снять на лето	2025-08-04	90	Подтверждаю бронь	approved	2025-06-17 00:00:00	2025-07-02 00:00:00
221	139	7	Хотим снять на лето	2025-08-16	95	Подтверждаю бронь	approved	2025-06-28 00:00:00	2025-07-12 00:00:00
222	159	17	Ищу квартиру для постоянного проживания	2025-10-07	365	Приходите на просмотр	approved	2025-09-09 00:00:00	2025-09-21 00:00:00
223	156	15	Ищу квартиру для постоянного проживания	2025-10-04	365	Приходите на просмотр	approved	2025-09-23 00:00:00	2025-09-11 00:00:00
224	161	17	Ищу квартиру для постоянного проживания	2025-10-29	365	Приходите на просмотр	approved	2025-09-04 00:00:00	2025-09-18 00:00:00
225	160	19	Ищу квартиру для постоянного проживания	2025-10-23	365	Приходите на просмотр	approved	2025-09-30 00:00:00	2025-09-21 00:00:00
226	153	15	Ищу квартиру для постоянного проживания	2025-10-24	365	Приходите на просмотр	approved	2025-09-18 00:00:00	2025-09-23 00:00:00
227	157	7	Ищу квартиру для постоянного проживания	2025-10-23	365	Приходите на просмотр	approved	2025-09-28 00:00:00	2025-09-11 00:00:00
228	167	15	Ищу квартиру для постоянного проживания	2025-10-02	365	Приходите на просмотр	approved	2025-09-11 00:00:00	2025-09-22 00:00:00
229	153	19	Ищу квартиру для постоянного проживания	2025-10-03	365	Приходите на просмотр	approved	2025-09-04 00:00:00	2025-09-12 00:00:00
230	152	11	Ищу квартиру для постоянного проживания	2025-10-16	365	Приходите на просмотр	approved	2025-09-26 00:00:00	2025-09-11 00:00:00
231	152	6	Ищу квартиру для постоянного проживания	2025-10-06	365	Приходите на просмотр	approved	2025-09-27 00:00:00	2025-09-26 00:00:00
232	162	17	Ищу квартиру для постоянного проживания	2025-10-09	365	Приходите на просмотр	approved	2025-09-20 00:00:00	2025-09-17 00:00:00
233	130	13	Ищу квартиру для постоянного проживания	2025-10-25	365	Приходите на просмотр	approved	2025-09-14 00:00:00	2025-09-22 00:00:00
376	163	18	Нужна дополнительная информация	2026-01-27	508	Можем встретиться для обсуждения	rejected	2026-01-13 00:00:00	2026-01-20 00:00:00
377	165	17	Хочу посмотреть объект в ближайшее время	2026-01-20	300	К сожалению, объект уже сдан	approved	2026-01-06 00:00:00	2026-01-09 00:00:00
378	6	19	Нужна дополнительная информация	2026-01-21	497	Добро пожаловать! Жду на подписание	approved	2026-01-07 00:00:00	2026-01-11 00:00:00
379	146	6	Отличный вариант, готов обсудить условия	2026-01-28	452	К сожалению, объект уже сдан	approved	2026-01-14 00:00:00	2026-01-20 00:00:00
380	144	6	Хочу посмотреть объект в ближайшее время	2026-02-25	352	\N	pending	2026-02-11 00:00:00	\N
381	149	13	Интересует аренда на длительный срок	2026-03-01	507	К сожалению, объект уже сдан	approved	2026-02-15 00:00:00	2026-02-17 00:00:00
382	166	9	Интересует аренда на длительный срок	2026-02-17	212	Можем встретиться для обсуждения	rejected	2026-02-03 00:00:00	2026-02-08 00:00:00
383	144	18	Отличный вариант, готов обсудить условия	2026-03-07	524	Добро пожаловать! Жду на подписание	approved	2026-02-21 00:00:00	2026-02-25 00:00:00
384	165	13	Хочу посмотреть объект в ближайшее время	2026-03-07	271	\N	pending	2026-02-21 00:00:00	\N
385	149	11	Нужна дополнительная информация	2026-03-09	271	Можем встретиться для обсуждения	rejected	2026-02-23 00:00:00	2026-02-28 00:00:00
386	166	15	Отличный вариант, готов обсудить условия	2026-02-26	377	Можем встретиться для обсуждения	approved	2026-02-12 00:00:00	2026-02-17 00:00:00
387	161	13	Отличный вариант, готов обсудить условия	2026-04-05	430	Можем встретиться для обсуждения	approved	2026-03-22 00:00:00	2026-03-27 00:00:00
388	163	9	Интересует аренда на длительный срок	2026-03-18	455	К сожалению, объект уже сдан	approved	2026-03-04 00:00:00	2026-03-10 00:00:00
390	6	16	Хочу посмотреть объект в ближайшее время	2026-03-24	443	К сожалению, объект уже сдан	approved	2026-03-10 00:00:00	2026-03-15 00:00:00
391	152	15	Отличный вариант, готов обсудить условия	2026-03-28	351	Можем встретиться для обсуждения	approved	2026-03-14 00:00:00	2026-03-15 00:00:00
392	149	11	Интересует аренда на длительный срок	2026-03-18	211	Добро пожаловать! Жду на подписание	approved	2026-03-04 00:00:00	2026-03-10 00:00:00
393	155	15	Отличный вариант, готов обсудить условия	2026-03-27	233	Можем встретиться для обсуждения	approved	2026-03-13 00:00:00	2026-03-16 00:00:00
394	1	6	Тест	2026-03-14	365	\N	pending	2026-03-14 19:01:53.808364	\N
254	5	17	Нужна квартира срочно	2026-02-25	365	Можем встретиться на неделе	approved	2026-01-29 00:00:00	2026-01-20 00:00:00
263	6	6	Планирую переезд	2026-03-07	365	\N	cancelled	2026-02-03 00:00:00	\N
265	4	6	Планирую переезд	2026-03-20	365	Созвонимся для уточнения	approved	2026-02-05 00:00:00	2026-02-14 00:00:00
271	3	7	Срочный поиск жилья	2026-03-22	365	Жду вас на просмотр	approved	2026-03-08 00:00:00	2026-03-06 00:00:00
124	1	6	Здравствуйте! Хотел бы посмотреть квартиру в ближайшие выходные	2026-03-10	365	Добрый вечер извините что я вас задержал! Поэтому завтра заселитесь	approved	2026-02-20 10:30:00	2026-03-09 20:29:24.042456
273	5	6	Срочный поиск жилья	2026-03-16	365	Жду вас на просмотр	approved	2026-03-02 00:00:00	2026-03-10 00:00:00
125	3	6	Интересует помещение для магазина, возможен ли долгосрочный договор?	2026-03-05	730	Да, возможен. Жду вас на просмотр в среду	approved	2026-02-21 14:15:00	2026-02-22 14:15:00
126	5	6	Хотим снять дом на лето для семьи с детьми	2026-06-01	120	Дом уже сдан на этот период	rejected	2026-02-15 09:45:00	2026-02-16 09:45:00
128	2	7	Студия очень понравилась, готова заключить договор	2026-03-01	365	Приходите в пятницу в 15:00	approved	2026-02-18 12:30:00	2026-02-18 16:30:00
277	6	7	Срочный поиск жилья	2026-03-22	365	Жду вас на просмотр	approved	2026-03-01 00:00:00	2026-03-06 00:00:00
129	128	7	Квартира в новостройке - мечта! Когда можно посмотреть?	2026-03-02	180	\N	pending	2026-02-22 11:10:00	2026-02-22 19:30:00
130	4	7	Квартира на Невском - отличный вариант, но дороговато	2026-03-15	365	Цена фиксированная	rejected	2026-02-19 13:45:00	2026-02-19 14:45:00
131	131	7	Интересует квартира в Куровском	2026-03-05	365	Жду вас в субботу в 14:00	approved	2026-02-21 10:00:00	2026-02-22 13:45:00
132	128	9	Квартира в новостройке - супер! Можно посмотреть в выходные?	2026-03-03	180	\N	pending	2026-02-23 18:30:00	2026-02-23 19:45:00
133	130	9	Офис в Ликино-Дулёво для небольшой компании	2026-03-01	365	Приходите во вторник после 18:00	approved	2026-02-22 15:40:00	2026-02-23 13:45:00
134	129	9	Таунхаус интересует для семьи	2026-04-01	730	\N	cancelled	2026-02-24 09:15:00	2026-02-24 13:45:00
135	132	9	Апартаменты в Орехово-Зуево	2026-03-10	365	Можем обсудить	cancelled	2026-02-20 11:25:00	2026-02-21 13:45:00
136	1	6	Повторно интересуюсь квартирой на Тверской	2026-03-15	365	Квартира ещё свободна	approved	2026-02-17 08:50:00	2026-02-18 10:45:00
137	3	7	А дом у озера на лето ещё свободен?	2026-06-15	90	Уже сдан	rejected	2026-02-16 14:30:00	2026-02-17 08:45:00
138	5	9	Рассматриваю коммерческое помещение в Новосибирске	2026-04-01	365	\N	cancelled	2026-02-24 12:10:00	2026-02-25 13:45:00
395	149	9	Арендуем четко!	2026-05-09	90	\N	approved	2026-03-14 19:32:58.087737	2026-03-14 19:35:16.674374
\.


--
-- TOC entry 5040 (class 0 OID 32930)
-- Dependencies: 232
-- Data for Name: audit_logs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.audit_logs (log_id, user_id, action, entity_type, entity_id, details, created_at) FROM stdin;
1	2	UPDATE	property	3	{"changes": {"price": {"new": 120000.0, "old": 120000.0}, "title": {"new": "Загородный дом у озера", "old": "Загородный дом у озера"}}}	2026-03-08 19:18:42.101167
2	2	SIGN	contract	4	null	2026-03-08 19:27:21.921274
3	2	UPDATE	property	2	{"changes": {"price": {"new": 35000.0, "old": 35000.0}, "title": {"new": "Студия в новостройке", "old": "Студия в новостройке"}}}	2026-03-08 19:31:18.585235
4	2	UPDATE	property	136	{"changes": {"price": {"new": 4444.0, "old": 4444.0}, "title": {"new": "fsdsfsf", "old": "fsdsfsf"}}}	2026-03-08 19:47:20.956296
5	2	UPDATE	property	136	{"changes": {"price": {"new": 4444.0, "old": 4444.0}, "title": {"new": "fsdsfsf", "old": "fsdsfsf"}}}	2026-03-08 19:47:32.521449
6	\N	UPDATE	messages	172	{"changes": {"content": {"content": "Привет! Как дела?", "is_read": true, "created_at": "2025-06-27T08:15:45.859473", "message_id": 172, "to_user_id": 3, "from_user_id": 15}, "is_read": {"content": "Привет! Как дела?", "is_read": true, "created_at": "2025-06-27T08:15:45.859473", "message_id": 172, "to_user_id": 3, "from_user_id": 15}, "created_at": {"content": "Привет! Как дела?", "is_read": true, "created_at": "2025-06-27T08:15:45.859473", "message_id": 172, "to_user_id": 3, "from_user_id": 15}, "message_id": {"content": "Привет! Как дела?", "is_read": true, "created_at": "2025-06-27T08:15:45.859473", "message_id": 172, "to_user_id": 3, "from_user_id": 15}, "to_user_id": {"content": "Привет! Как дела?", "is_read": true, "created_at": "2025-06-27T08:15:45.859473", "message_id": 172, "to_user_id": 3, "from_user_id": 15}, "from_user_id": {"content": "Привет! Как дела?", "is_read": true, "created_at": "2025-06-27T08:15:45.859473", "message_id": 172, "to_user_id": 3, "from_user_id": 15}}, "old_data": {"content": "Привет! Как дела?", "is_read": false, "created_at": "2025-06-27T08:15:45.859473", "message_id": 172, "to_user_id": 3, "from_user_id": 15}}	2026-03-11 18:43:29.511961
7	\N	UPDATE	messages	125	{"changes": {"content": {"content": "Хочу уточнить детали перед подписанием", "is_read": true, "created_at": "2026-02-06T20:07:05.096526", "message_id": 125, "to_user_id": 3, "from_user_id": 6}, "is_read": {"content": "Хочу уточнить детали перед подписанием", "is_read": true, "created_at": "2026-02-06T20:07:05.096526", "message_id": 125, "to_user_id": 3, "from_user_id": 6}, "created_at": {"content": "Хочу уточнить детали перед подписанием", "is_read": true, "created_at": "2026-02-06T20:07:05.096526", "message_id": 125, "to_user_id": 3, "from_user_id": 6}, "message_id": {"content": "Хочу уточнить детали перед подписанием", "is_read": true, "created_at": "2026-02-06T20:07:05.096526", "message_id": 125, "to_user_id": 3, "from_user_id": 6}, "to_user_id": {"content": "Хочу уточнить детали перед подписанием", "is_read": true, "created_at": "2026-02-06T20:07:05.096526", "message_id": 125, "to_user_id": 3, "from_user_id": 6}, "from_user_id": {"content": "Хочу уточнить детали перед подписанием", "is_read": true, "created_at": "2026-02-06T20:07:05.096526", "message_id": 125, "to_user_id": 3, "from_user_id": 6}}, "old_data": {"content": "Хочу уточнить детали перед подписанием", "is_read": false, "created_at": "2026-02-06T20:07:05.096526", "message_id": 125, "to_user_id": 3, "from_user_id": 6}}	2026-03-11 18:43:57.573652
8	\N	UPDATE	messages	20	{"changes": {"content": {"content": "ок", "is_read": true, "created_at": "2026-03-09T06:26:26.333851", "message_id": 20, "to_user_id": 3, "from_user_id": 9}, "is_read": {"content": "ок", "is_read": true, "created_at": "2026-03-09T06:26:26.333851", "message_id": 20, "to_user_id": 3, "from_user_id": 9}, "created_at": {"content": "ок", "is_read": true, "created_at": "2026-03-09T06:26:26.333851", "message_id": 20, "to_user_id": 3, "from_user_id": 9}, "message_id": {"content": "ок", "is_read": true, "created_at": "2026-03-09T06:26:26.333851", "message_id": 20, "to_user_id": 3, "from_user_id": 9}, "to_user_id": {"content": "ок", "is_read": true, "created_at": "2026-03-09T06:26:26.333851", "message_id": 20, "to_user_id": 3, "from_user_id": 9}, "from_user_id": {"content": "ок", "is_read": true, "created_at": "2026-03-09T06:26:26.333851", "message_id": 20, "to_user_id": 3, "from_user_id": 9}}, "old_data": {"content": "ок", "is_read": false, "created_at": "2026-03-09T06:26:26.333851", "message_id": 20, "to_user_id": 3, "from_user_id": 9}}	2026-03-11 18:53:47.239539
9	\N	UPDATE	users	7	{"changes": {"email": {"email": "tenant.maria@mail.ru", "user_id": 7, "full_name": "Мария Васильева", "is_active": false, "user_type": "tenant", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 789-01-23"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "user_id": {"email": "tenant.maria@mail.ru", "user_id": 7, "full_name": "Мария Васильева", "is_active": false, "user_type": "tenant", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 789-01-23"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "full_name": {"email": "tenant.maria@mail.ru", "user_id": 7, "full_name": "Мария Васильева", "is_active": false, "user_type": "tenant", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 789-01-23"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "is_active": {"email": "tenant.maria@mail.ru", "user_id": 7, "full_name": "Мария Васильева", "is_active": false, "user_type": "tenant", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 789-01-23"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "user_type": {"email": "tenant.maria@mail.ru", "user_id": 7, "full_name": "Мария Васильева", "is_active": false, "user_type": "tenant", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 789-01-23"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "avatar_url": {"email": "tenant.maria@mail.ru", "user_id": 7, "full_name": "Мария Васильева", "is_active": false, "user_type": "tenant", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 789-01-23"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "created_at": {"email": "tenant.maria@mail.ru", "user_id": 7, "full_name": "Мария Васильева", "is_active": false, "user_type": "tenant", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 789-01-23"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "contact_info": {"email": "tenant.maria@mail.ru", "user_id": 7, "full_name": "Мария Васильева", "is_active": false, "user_type": "tenant", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 789-01-23"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "password_hash": {"email": "tenant.maria@mail.ru", "user_id": 7, "full_name": "Мария Васильева", "is_active": false, "user_type": "tenant", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 789-01-23"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}}, "old_data": {"email": "tenant.maria@mail.ru", "user_id": 7, "full_name": "Мария Васильева", "is_active": true, "user_type": "tenant", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 789-01-23"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}}	2026-03-11 19:52:58.175577
10	1	TOGGLE_BLOCK	user	7	{"changes": {"is_active": false}}	2026-03-11 16:52:58.220446
11	\N	UPDATE	users	7	{"changes": {"email": {"email": "tenant.maria@mail.ru", "user_id": 7, "full_name": "Мария Васильева", "is_active": true, "user_type": "tenant", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 789-01-23"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "user_id": {"email": "tenant.maria@mail.ru", "user_id": 7, "full_name": "Мария Васильева", "is_active": true, "user_type": "tenant", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 789-01-23"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "full_name": {"email": "tenant.maria@mail.ru", "user_id": 7, "full_name": "Мария Васильева", "is_active": true, "user_type": "tenant", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 789-01-23"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "is_active": {"email": "tenant.maria@mail.ru", "user_id": 7, "full_name": "Мария Васильева", "is_active": true, "user_type": "tenant", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 789-01-23"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "user_type": {"email": "tenant.maria@mail.ru", "user_id": 7, "full_name": "Мария Васильева", "is_active": true, "user_type": "tenant", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 789-01-23"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "avatar_url": {"email": "tenant.maria@mail.ru", "user_id": 7, "full_name": "Мария Васильева", "is_active": true, "user_type": "tenant", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 789-01-23"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "created_at": {"email": "tenant.maria@mail.ru", "user_id": 7, "full_name": "Мария Васильева", "is_active": true, "user_type": "tenant", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 789-01-23"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "contact_info": {"email": "tenant.maria@mail.ru", "user_id": 7, "full_name": "Мария Васильева", "is_active": true, "user_type": "tenant", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 789-01-23"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "password_hash": {"email": "tenant.maria@mail.ru", "user_id": 7, "full_name": "Мария Васильева", "is_active": true, "user_type": "tenant", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 789-01-23"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}}, "old_data": {"email": "tenant.maria@mail.ru", "user_id": 7, "full_name": "Мария Васильева", "is_active": false, "user_type": "tenant", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 789-01-23"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}}	2026-03-11 20:00:03.164551
12	1	TOGGLE_BLOCK	user	7	{"changes": {"is_active": true}}	2026-03-11 17:00:03.182895
13	\N	UPDATE	users	4	{"changes": {"email": {"email": "owner.elena@mail.ru", "user_id": 4, "full_name": "Елена Смирнова", "is_active": false, "user_type": "owner", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 456-78-90"}, "password_hash": "43a0d17178a9d26c9e0fe9a74b0b45e38d32f27aed887a008a54bf6e033bf7b9"}, "user_id": {"email": "owner.elena@mail.ru", "user_id": 4, "full_name": "Елена Смирнова", "is_active": false, "user_type": "owner", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 456-78-90"}, "password_hash": "43a0d17178a9d26c9e0fe9a74b0b45e38d32f27aed887a008a54bf6e033bf7b9"}, "full_name": {"email": "owner.elena@mail.ru", "user_id": 4, "full_name": "Елена Смирнова", "is_active": false, "user_type": "owner", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 456-78-90"}, "password_hash": "43a0d17178a9d26c9e0fe9a74b0b45e38d32f27aed887a008a54bf6e033bf7b9"}, "is_active": {"email": "owner.elena@mail.ru", "user_id": 4, "full_name": "Елена Смирнова", "is_active": false, "user_type": "owner", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 456-78-90"}, "password_hash": "43a0d17178a9d26c9e0fe9a74b0b45e38d32f27aed887a008a54bf6e033bf7b9"}, "user_type": {"email": "owner.elena@mail.ru", "user_id": 4, "full_name": "Елена Смирнова", "is_active": false, "user_type": "owner", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 456-78-90"}, "password_hash": "43a0d17178a9d26c9e0fe9a74b0b45e38d32f27aed887a008a54bf6e033bf7b9"}, "avatar_url": {"email": "owner.elena@mail.ru", "user_id": 4, "full_name": "Елена Смирнова", "is_active": false, "user_type": "owner", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 456-78-90"}, "password_hash": "43a0d17178a9d26c9e0fe9a74b0b45e38d32f27aed887a008a54bf6e033bf7b9"}, "created_at": {"email": "owner.elena@mail.ru", "user_id": 4, "full_name": "Елена Смирнова", "is_active": false, "user_type": "owner", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 456-78-90"}, "password_hash": "43a0d17178a9d26c9e0fe9a74b0b45e38d32f27aed887a008a54bf6e033bf7b9"}, "contact_info": {"email": "owner.elena@mail.ru", "user_id": 4, "full_name": "Елена Смирнова", "is_active": false, "user_type": "owner", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 456-78-90"}, "password_hash": "43a0d17178a9d26c9e0fe9a74b0b45e38d32f27aed887a008a54bf6e033bf7b9"}, "password_hash": {"email": "owner.elena@mail.ru", "user_id": 4, "full_name": "Елена Смирнова", "is_active": false, "user_type": "owner", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 456-78-90"}, "password_hash": "43a0d17178a9d26c9e0fe9a74b0b45e38d32f27aed887a008a54bf6e033bf7b9"}}, "old_data": {"email": "owner.elena@mail.ru", "user_id": 4, "full_name": "Елена Смирнова", "is_active": true, "user_type": "owner", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 456-78-90"}, "password_hash": "43a0d17178a9d26c9e0fe9a74b0b45e38d32f27aed887a008a54bf6e033bf7b9"}}	2026-03-11 20:01:36.801022
14	1	TOGGLE_BLOCK	user	4	{"changes": {"is_active": false}}	2026-03-11 17:01:36.814981
16	1	TOGGLE_BLOCK	user	4	{"changes": {"is_active": true}}	2026-03-11 17:01:45.761013
15	\N	UPDATE	users	4	{"changes": {"email": {"email": "owner.elena@mail.ru", "user_id": 4, "full_name": "Елена Смирнова", "is_active": true, "user_type": "owner", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 456-78-90"}, "password_hash": "43a0d17178a9d26c9e0fe9a74b0b45e38d32f27aed887a008a54bf6e033bf7b9"}, "user_id": {"email": "owner.elena@mail.ru", "user_id": 4, "full_name": "Елена Смирнова", "is_active": true, "user_type": "owner", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 456-78-90"}, "password_hash": "43a0d17178a9d26c9e0fe9a74b0b45e38d32f27aed887a008a54bf6e033bf7b9"}, "full_name": {"email": "owner.elena@mail.ru", "user_id": 4, "full_name": "Елена Смирнова", "is_active": true, "user_type": "owner", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 456-78-90"}, "password_hash": "43a0d17178a9d26c9e0fe9a74b0b45e38d32f27aed887a008a54bf6e033bf7b9"}, "is_active": {"email": "owner.elena@mail.ru", "user_id": 4, "full_name": "Елена Смирнова", "is_active": true, "user_type": "owner", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 456-78-90"}, "password_hash": "43a0d17178a9d26c9e0fe9a74b0b45e38d32f27aed887a008a54bf6e033bf7b9"}, "user_type": {"email": "owner.elena@mail.ru", "user_id": 4, "full_name": "Елена Смирнова", "is_active": true, "user_type": "owner", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 456-78-90"}, "password_hash": "43a0d17178a9d26c9e0fe9a74b0b45e38d32f27aed887a008a54bf6e033bf7b9"}, "avatar_url": {"email": "owner.elena@mail.ru", "user_id": 4, "full_name": "Елена Смирнова", "is_active": true, "user_type": "owner", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 456-78-90"}, "password_hash": "43a0d17178a9d26c9e0fe9a74b0b45e38d32f27aed887a008a54bf6e033bf7b9"}, "created_at": {"email": "owner.elena@mail.ru", "user_id": 4, "full_name": "Елена Смирнова", "is_active": true, "user_type": "owner", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 456-78-90"}, "password_hash": "43a0d17178a9d26c9e0fe9a74b0b45e38d32f27aed887a008a54bf6e033bf7b9"}, "contact_info": {"email": "owner.elena@mail.ru", "user_id": 4, "full_name": "Елена Смирнова", "is_active": true, "user_type": "owner", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 456-78-90"}, "password_hash": "43a0d17178a9d26c9e0fe9a74b0b45e38d32f27aed887a008a54bf6e033bf7b9"}, "password_hash": {"email": "owner.elena@mail.ru", "user_id": 4, "full_name": "Елена Смирнова", "is_active": true, "user_type": "owner", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 456-78-90"}, "password_hash": "43a0d17178a9d26c9e0fe9a74b0b45e38d32f27aed887a008a54bf6e033bf7b9"}}, "old_data": {"email": "owner.elena@mail.ru", "user_id": 4, "full_name": "Елена Смирнова", "is_active": false, "user_type": "owner", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 456-78-90"}, "password_hash": "43a0d17178a9d26c9e0fe9a74b0b45e38d32f27aed887a008a54bf6e033bf7b9"}}	2026-03-11 20:01:45.743108
17	\N	UPDATE	users	7	{"changes": {"email": {"email": "tenant.maria@mail.ru", "user_id": 7, "full_name": "Мария Васильева", "is_active": false, "user_type": "tenant", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 789-01-23"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "user_id": {"email": "tenant.maria@mail.ru", "user_id": 7, "full_name": "Мария Васильева", "is_active": false, "user_type": "tenant", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 789-01-23"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "full_name": {"email": "tenant.maria@mail.ru", "user_id": 7, "full_name": "Мария Васильева", "is_active": false, "user_type": "tenant", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 789-01-23"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "is_active": {"email": "tenant.maria@mail.ru", "user_id": 7, "full_name": "Мария Васильева", "is_active": false, "user_type": "tenant", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 789-01-23"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "user_type": {"email": "tenant.maria@mail.ru", "user_id": 7, "full_name": "Мария Васильева", "is_active": false, "user_type": "tenant", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 789-01-23"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "avatar_url": {"email": "tenant.maria@mail.ru", "user_id": 7, "full_name": "Мария Васильева", "is_active": false, "user_type": "tenant", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 789-01-23"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "created_at": {"email": "tenant.maria@mail.ru", "user_id": 7, "full_name": "Мария Васильева", "is_active": false, "user_type": "tenant", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 789-01-23"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "contact_info": {"email": "tenant.maria@mail.ru", "user_id": 7, "full_name": "Мария Васильева", "is_active": false, "user_type": "tenant", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 789-01-23"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "password_hash": {"email": "tenant.maria@mail.ru", "user_id": 7, "full_name": "Мария Васильева", "is_active": false, "user_type": "tenant", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 789-01-23"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}}, "old_data": {"email": "tenant.maria@mail.ru", "user_id": 7, "full_name": "Мария Васильева", "is_active": true, "user_type": "tenant", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 789-01-23"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}}	2026-03-11 20:20:36.031447
18	1	TOGGLE_BLOCK	user	7	{"changes": {"is_active": false}}	2026-03-11 17:20:36.056661
19	\N	UPDATE	users	7	{"changes": {"email": {"email": "tenant.maria@mail.ru", "user_id": 7, "full_name": "Мария Васильева", "is_active": true, "user_type": "tenant", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 789-01-23"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "user_id": {"email": "tenant.maria@mail.ru", "user_id": 7, "full_name": "Мария Васильева", "is_active": true, "user_type": "tenant", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 789-01-23"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "full_name": {"email": "tenant.maria@mail.ru", "user_id": 7, "full_name": "Мария Васильева", "is_active": true, "user_type": "tenant", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 789-01-23"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "is_active": {"email": "tenant.maria@mail.ru", "user_id": 7, "full_name": "Мария Васильева", "is_active": true, "user_type": "tenant", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 789-01-23"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "user_type": {"email": "tenant.maria@mail.ru", "user_id": 7, "full_name": "Мария Васильева", "is_active": true, "user_type": "tenant", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 789-01-23"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "avatar_url": {"email": "tenant.maria@mail.ru", "user_id": 7, "full_name": "Мария Васильева", "is_active": true, "user_type": "tenant", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 789-01-23"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "created_at": {"email": "tenant.maria@mail.ru", "user_id": 7, "full_name": "Мария Васильева", "is_active": true, "user_type": "tenant", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 789-01-23"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "contact_info": {"email": "tenant.maria@mail.ru", "user_id": 7, "full_name": "Мария Васильева", "is_active": true, "user_type": "tenant", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 789-01-23"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "password_hash": {"email": "tenant.maria@mail.ru", "user_id": 7, "full_name": "Мария Васильева", "is_active": true, "user_type": "tenant", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 789-01-23"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}}, "old_data": {"email": "tenant.maria@mail.ru", "user_id": 7, "full_name": "Мария Васильева", "is_active": false, "user_type": "tenant", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 789-01-23"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}}	2026-03-11 20:20:38.728114
20	1	TOGGLE_BLOCK	user	7	{"changes": {"is_active": true}}	2026-03-11 17:20:38.734662
21	\N	UPDATE	users	15	{"changes": {"email": {"email": "kruchkova.oksana@mail.ru", "user_id": 15, "full_name": "Крючкова Оксана Вячеславовна", "is_active": false, "user_type": "tenant", "avatar_url": null, "created_at": "2026-03-10T20:22:23.818207", "contact_info": {"city": "Москва", "phone": "+7 (916) 123-45-67"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "user_id": {"email": "kruchkova.oksana@mail.ru", "user_id": 15, "full_name": "Крючкова Оксана Вячеславовна", "is_active": false, "user_type": "tenant", "avatar_url": null, "created_at": "2026-03-10T20:22:23.818207", "contact_info": {"city": "Москва", "phone": "+7 (916) 123-45-67"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "full_name": {"email": "kruchkova.oksana@mail.ru", "user_id": 15, "full_name": "Крючкова Оксана Вячеславовна", "is_active": false, "user_type": "tenant", "avatar_url": null, "created_at": "2026-03-10T20:22:23.818207", "contact_info": {"city": "Москва", "phone": "+7 (916) 123-45-67"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "is_active": {"email": "kruchkova.oksana@mail.ru", "user_id": 15, "full_name": "Крючкова Оксана Вячеславовна", "is_active": false, "user_type": "tenant", "avatar_url": null, "created_at": "2026-03-10T20:22:23.818207", "contact_info": {"city": "Москва", "phone": "+7 (916) 123-45-67"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "user_type": {"email": "kruchkova.oksana@mail.ru", "user_id": 15, "full_name": "Крючкова Оксана Вячеславовна", "is_active": false, "user_type": "tenant", "avatar_url": null, "created_at": "2026-03-10T20:22:23.818207", "contact_info": {"city": "Москва", "phone": "+7 (916) 123-45-67"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "avatar_url": {"email": "kruchkova.oksana@mail.ru", "user_id": 15, "full_name": "Крючкова Оксана Вячеславовна", "is_active": false, "user_type": "tenant", "avatar_url": null, "created_at": "2026-03-10T20:22:23.818207", "contact_info": {"city": "Москва", "phone": "+7 (916) 123-45-67"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "created_at": {"email": "kruchkova.oksana@mail.ru", "user_id": 15, "full_name": "Крючкова Оксана Вячеславовна", "is_active": false, "user_type": "tenant", "avatar_url": null, "created_at": "2026-03-10T20:22:23.818207", "contact_info": {"city": "Москва", "phone": "+7 (916) 123-45-67"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "contact_info": {"email": "kruchkova.oksana@mail.ru", "user_id": 15, "full_name": "Крючкова Оксана Вячеславовна", "is_active": false, "user_type": "tenant", "avatar_url": null, "created_at": "2026-03-10T20:22:23.818207", "contact_info": {"city": "Москва", "phone": "+7 (916) 123-45-67"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "password_hash": {"email": "kruchkova.oksana@mail.ru", "user_id": 15, "full_name": "Крючкова Оксана Вячеславовна", "is_active": false, "user_type": "tenant", "avatar_url": null, "created_at": "2026-03-10T20:22:23.818207", "contact_info": {"city": "Москва", "phone": "+7 (916) 123-45-67"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}}, "old_data": {"email": "kruchkova.oksana@mail.ru", "user_id": 15, "full_name": "Крючкова Оксана Вячеславовна", "is_active": true, "user_type": "tenant", "avatar_url": null, "created_at": "2026-03-10T20:22:23.818207", "contact_info": {"city": "Москва", "phone": "+7 (916) 123-45-67"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}}	2026-03-11 20:26:02.198382
22	1	TOGGLE_BLOCK	user	15	{"changes": {"is_active": false}}	2026-03-11 17:26:02.205198
23	\N	UPDATE	users	15	{"changes": {"email": {"email": "kruchkova.oksana@mail.ru", "user_id": 15, "full_name": "Крючкова Оксана Вячеславовна", "is_active": true, "user_type": "tenant", "avatar_url": null, "created_at": "2026-03-10T20:22:23.818207", "contact_info": {"city": "Москва", "phone": "+7 (916) 123-45-67"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "user_id": {"email": "kruchkova.oksana@mail.ru", "user_id": 15, "full_name": "Крючкова Оксана Вячеславовна", "is_active": true, "user_type": "tenant", "avatar_url": null, "created_at": "2026-03-10T20:22:23.818207", "contact_info": {"city": "Москва", "phone": "+7 (916) 123-45-67"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "full_name": {"email": "kruchkova.oksana@mail.ru", "user_id": 15, "full_name": "Крючкова Оксана Вячеславовна", "is_active": true, "user_type": "tenant", "avatar_url": null, "created_at": "2026-03-10T20:22:23.818207", "contact_info": {"city": "Москва", "phone": "+7 (916) 123-45-67"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "is_active": {"email": "kruchkova.oksana@mail.ru", "user_id": 15, "full_name": "Крючкова Оксана Вячеславовна", "is_active": true, "user_type": "tenant", "avatar_url": null, "created_at": "2026-03-10T20:22:23.818207", "contact_info": {"city": "Москва", "phone": "+7 (916) 123-45-67"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "user_type": {"email": "kruchkova.oksana@mail.ru", "user_id": 15, "full_name": "Крючкова Оксана Вячеславовна", "is_active": true, "user_type": "tenant", "avatar_url": null, "created_at": "2026-03-10T20:22:23.818207", "contact_info": {"city": "Москва", "phone": "+7 (916) 123-45-67"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "avatar_url": {"email": "kruchkova.oksana@mail.ru", "user_id": 15, "full_name": "Крючкова Оксана Вячеславовна", "is_active": true, "user_type": "tenant", "avatar_url": null, "created_at": "2026-03-10T20:22:23.818207", "contact_info": {"city": "Москва", "phone": "+7 (916) 123-45-67"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "created_at": {"email": "kruchkova.oksana@mail.ru", "user_id": 15, "full_name": "Крючкова Оксана Вячеславовна", "is_active": true, "user_type": "tenant", "avatar_url": null, "created_at": "2026-03-10T20:22:23.818207", "contact_info": {"city": "Москва", "phone": "+7 (916) 123-45-67"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "contact_info": {"email": "kruchkova.oksana@mail.ru", "user_id": 15, "full_name": "Крючкова Оксана Вячеславовна", "is_active": true, "user_type": "tenant", "avatar_url": null, "created_at": "2026-03-10T20:22:23.818207", "contact_info": {"city": "Москва", "phone": "+7 (916) 123-45-67"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}, "password_hash": {"email": "kruchkova.oksana@mail.ru", "user_id": 15, "full_name": "Крючкова Оксана Вячеславовна", "is_active": true, "user_type": "tenant", "avatar_url": null, "created_at": "2026-03-10T20:22:23.818207", "contact_info": {"city": "Москва", "phone": "+7 (916) 123-45-67"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}}, "old_data": {"email": "kruchkova.oksana@mail.ru", "user_id": 15, "full_name": "Крючкова Оксана Вячеславовна", "is_active": false, "user_type": "tenant", "avatar_url": null, "created_at": "2026-03-10T20:22:23.818207", "contact_info": {"city": "Москва", "phone": "+7 (916) 123-45-67"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}}	2026-03-11 20:26:08.886599
24	1	TOGGLE_BLOCK	user	15	{"changes": {"is_active": true}}	2026-03-11 17:26:08.892909
25	\N	UPDATE	users	14	{"changes": {"email": {"email": "aquanomore@gmail.com", "user_id": 14, "full_name": "Марков Иван Александрович", "is_active": false, "user_type": "owner", "avatar_url": "/static/uploads/avatars/cc5b1d5043b042538ddb8ad6ae566afb.jpg", "created_at": "2026-03-10T20:14:15.429596", "contact_info": {"inn": "2556647474", "city": "Авсюнино", "phone": "+79267890023", "passport": "7818478395", "birth_date": "2007-05-17"}, "password_hash": "4d49ca0443be87f6eff65f63508ff8f27954eaa051df0fe1baa318179439b60c"}, "user_id": {"email": "aquanomore@gmail.com", "user_id": 14, "full_name": "Марков Иван Александрович", "is_active": false, "user_type": "owner", "avatar_url": "/static/uploads/avatars/cc5b1d5043b042538ddb8ad6ae566afb.jpg", "created_at": "2026-03-10T20:14:15.429596", "contact_info": {"inn": "2556647474", "city": "Авсюнино", "phone": "+79267890023", "passport": "7818478395", "birth_date": "2007-05-17"}, "password_hash": "4d49ca0443be87f6eff65f63508ff8f27954eaa051df0fe1baa318179439b60c"}, "full_name": {"email": "aquanomore@gmail.com", "user_id": 14, "full_name": "Марков Иван Александрович", "is_active": false, "user_type": "owner", "avatar_url": "/static/uploads/avatars/cc5b1d5043b042538ddb8ad6ae566afb.jpg", "created_at": "2026-03-10T20:14:15.429596", "contact_info": {"inn": "2556647474", "city": "Авсюнино", "phone": "+79267890023", "passport": "7818478395", "birth_date": "2007-05-17"}, "password_hash": "4d49ca0443be87f6eff65f63508ff8f27954eaa051df0fe1baa318179439b60c"}, "is_active": {"email": "aquanomore@gmail.com", "user_id": 14, "full_name": "Марков Иван Александрович", "is_active": false, "user_type": "owner", "avatar_url": "/static/uploads/avatars/cc5b1d5043b042538ddb8ad6ae566afb.jpg", "created_at": "2026-03-10T20:14:15.429596", "contact_info": {"inn": "2556647474", "city": "Авсюнино", "phone": "+79267890023", "passport": "7818478395", "birth_date": "2007-05-17"}, "password_hash": "4d49ca0443be87f6eff65f63508ff8f27954eaa051df0fe1baa318179439b60c"}, "user_type": {"email": "aquanomore@gmail.com", "user_id": 14, "full_name": "Марков Иван Александрович", "is_active": false, "user_type": "owner", "avatar_url": "/static/uploads/avatars/cc5b1d5043b042538ddb8ad6ae566afb.jpg", "created_at": "2026-03-10T20:14:15.429596", "contact_info": {"inn": "2556647474", "city": "Авсюнино", "phone": "+79267890023", "passport": "7818478395", "birth_date": "2007-05-17"}, "password_hash": "4d49ca0443be87f6eff65f63508ff8f27954eaa051df0fe1baa318179439b60c"}, "avatar_url": {"email": "aquanomore@gmail.com", "user_id": 14, "full_name": "Марков Иван Александрович", "is_active": false, "user_type": "owner", "avatar_url": "/static/uploads/avatars/cc5b1d5043b042538ddb8ad6ae566afb.jpg", "created_at": "2026-03-10T20:14:15.429596", "contact_info": {"inn": "2556647474", "city": "Авсюнино", "phone": "+79267890023", "passport": "7818478395", "birth_date": "2007-05-17"}, "password_hash": "4d49ca0443be87f6eff65f63508ff8f27954eaa051df0fe1baa318179439b60c"}, "created_at": {"email": "aquanomore@gmail.com", "user_id": 14, "full_name": "Марков Иван Александрович", "is_active": false, "user_type": "owner", "avatar_url": "/static/uploads/avatars/cc5b1d5043b042538ddb8ad6ae566afb.jpg", "created_at": "2026-03-10T20:14:15.429596", "contact_info": {"inn": "2556647474", "city": "Авсюнино", "phone": "+79267890023", "passport": "7818478395", "birth_date": "2007-05-17"}, "password_hash": "4d49ca0443be87f6eff65f63508ff8f27954eaa051df0fe1baa318179439b60c"}, "contact_info": {"email": "aquanomore@gmail.com", "user_id": 14, "full_name": "Марков Иван Александрович", "is_active": false, "user_type": "owner", "avatar_url": "/static/uploads/avatars/cc5b1d5043b042538ddb8ad6ae566afb.jpg", "created_at": "2026-03-10T20:14:15.429596", "contact_info": {"inn": "2556647474", "city": "Авсюнино", "phone": "+79267890023", "passport": "7818478395", "birth_date": "2007-05-17"}, "password_hash": "4d49ca0443be87f6eff65f63508ff8f27954eaa051df0fe1baa318179439b60c"}, "password_hash": {"email": "aquanomore@gmail.com", "user_id": 14, "full_name": "Марков Иван Александрович", "is_active": false, "user_type": "owner", "avatar_url": "/static/uploads/avatars/cc5b1d5043b042538ddb8ad6ae566afb.jpg", "created_at": "2026-03-10T20:14:15.429596", "contact_info": {"inn": "2556647474", "city": "Авсюнино", "phone": "+79267890023", "passport": "7818478395", "birth_date": "2007-05-17"}, "password_hash": "4d49ca0443be87f6eff65f63508ff8f27954eaa051df0fe1baa318179439b60c"}}, "old_data": {"email": "aquanomore@gmail.com", "user_id": 14, "full_name": "Марков Иван Александрович", "is_active": true, "user_type": "owner", "avatar_url": "/static/uploads/avatars/cc5b1d5043b042538ddb8ad6ae566afb.jpg", "created_at": "2026-03-10T20:14:15.429596", "contact_info": {"inn": "2556647474", "city": "Авсюнино", "phone": "+79267890023", "passport": "7818478395", "birth_date": "2007-05-17"}, "password_hash": "4d49ca0443be87f6eff65f63508ff8f27954eaa051df0fe1baa318179439b60c"}}	2026-03-11 20:26:41.876265
26	1	TOGGLE_BLOCK	user	14	{"changes": {"is_active": false}}	2026-03-11 17:26:41.883233
27	\N	UPDATE	messages	193	{"changes": {"content": {"content": "Слышал, цены на аренду выросли", "is_read": true, "created_at": "2026-01-18T16:05:20.898848", "message_id": 193, "to_user_id": 1, "from_user_id": 3}, "is_read": {"content": "Слышал, цены на аренду выросли", "is_read": true, "created_at": "2026-01-18T16:05:20.898848", "message_id": 193, "to_user_id": 1, "from_user_id": 3}, "created_at": {"content": "Слышал, цены на аренду выросли", "is_read": true, "created_at": "2026-01-18T16:05:20.898848", "message_id": 193, "to_user_id": 1, "from_user_id": 3}, "message_id": {"content": "Слышал, цены на аренду выросли", "is_read": true, "created_at": "2026-01-18T16:05:20.898848", "message_id": 193, "to_user_id": 1, "from_user_id": 3}, "to_user_id": {"content": "Слышал, цены на аренду выросли", "is_read": true, "created_at": "2026-01-18T16:05:20.898848", "message_id": 193, "to_user_id": 1, "from_user_id": 3}, "from_user_id": {"content": "Слышал, цены на аренду выросли", "is_read": true, "created_at": "2026-01-18T16:05:20.898848", "message_id": 193, "to_user_id": 1, "from_user_id": 3}}, "old_data": {"content": "Слышал, цены на аренду выросли", "is_read": false, "created_at": "2026-01-18T16:05:20.898848", "message_id": 193, "to_user_id": 1, "from_user_id": 3}}	2026-03-11 20:28:20.13589
28	\N	UPDATE	messages	179	{"changes": {"content": {"content": "Видел новый объект в нашем районе?", "is_read": true, "created_at": "2025-04-30T15:59:41.65094", "message_id": 179, "to_user_id": 1, "from_user_id": 7}, "is_read": {"content": "Видел новый объект в нашем районе?", "is_read": true, "created_at": "2025-04-30T15:59:41.65094", "message_id": 179, "to_user_id": 1, "from_user_id": 7}, "created_at": {"content": "Видел новый объект в нашем районе?", "is_read": true, "created_at": "2025-04-30T15:59:41.65094", "message_id": 179, "to_user_id": 1, "from_user_id": 7}, "message_id": {"content": "Видел новый объект в нашем районе?", "is_read": true, "created_at": "2025-04-30T15:59:41.65094", "message_id": 179, "to_user_id": 1, "from_user_id": 7}, "to_user_id": {"content": "Видел новый объект в нашем районе?", "is_read": true, "created_at": "2025-04-30T15:59:41.65094", "message_id": 179, "to_user_id": 1, "from_user_id": 7}, "from_user_id": {"content": "Видел новый объект в нашем районе?", "is_read": true, "created_at": "2025-04-30T15:59:41.65094", "message_id": 179, "to_user_id": 1, "from_user_id": 7}}, "old_data": {"content": "Видел новый объект в нашем районе?", "is_read": false, "created_at": "2025-04-30T15:59:41.65094", "message_id": 179, "to_user_id": 1, "from_user_id": 7}}	2026-03-11 20:28:23.341415
30	1	ADMIN_DELETE	property	148	{"changes": {"title": "Дом в Тонком Мысе", "owner_id": 5}}	2026-03-11 17:44:23.234147
42	\N	DELETE	properties	169	{"table": "properties", "action": "DELETE", "deleted_data": {"area": 0.00, "city": "dgdg", "price": 0.00, "rooms": 0, "title": "dgdgg", "status": "active", "address": "dgdgdg", "owner_id": 2, "created_at": "2026-03-13T17:13:54.143996", "description": "", "property_id": 169, "interval_pay": "month", "property_type": "apartment"}}	2026-03-13 20:36:45.582659
29	\N	UPDATE	messages	200	{"changes": {"content": {"content": "Слышал, цены на аренду выросли", "is_read": true, "created_at": "2025-08-25T15:05:25.10128", "message_id": 200, "to_user_id": 1, "from_user_id": 5}, "is_read": {"content": "Слышал, цены на аренду выросли", "is_read": true, "created_at": "2025-08-25T15:05:25.10128", "message_id": 200, "to_user_id": 1, "from_user_id": 5}, "created_at": {"content": "Слышал, цены на аренду выросли", "is_read": true, "created_at": "2025-08-25T15:05:25.10128", "message_id": 200, "to_user_id": 1, "from_user_id": 5}, "message_id": {"content": "Слышал, цены на аренду выросли", "is_read": true, "created_at": "2025-08-25T15:05:25.10128", "message_id": 200, "to_user_id": 1, "from_user_id": 5}, "to_user_id": {"content": "Слышал, цены на аренду выросли", "is_read": true, "created_at": "2025-08-25T15:05:25.10128", "message_id": 200, "to_user_id": 1, "from_user_id": 5}, "from_user_id": {"content": "Слышал, цены на аренду выросли", "is_read": true, "created_at": "2025-08-25T15:05:25.10128", "message_id": 200, "to_user_id": 1, "from_user_id": 5}}, "old_data": {"content": "Слышал, цены на аренду выросли", "is_read": false, "created_at": "2025-08-25T15:05:25.10128", "message_id": 200, "to_user_id": 1, "from_user_id": 5}}	2026-03-11 20:28:24.196271
31	\N	UPDATE	contracts	28	{"changes": {"end_date": {"end_date": "2025-11-13", "created_at": "2025-03-29T06:05:50.041976", "start_date": "2025-07-29", "contract_id": 28, "owner_signed": true, "total_amount": 344030.52, "tenant_signed": true, "application_id": null, "signing_status": "signed"}, "created_at": {"end_date": "2025-11-13", "created_at": "2025-03-29T06:05:50.041976", "start_date": "2025-07-29", "contract_id": 28, "owner_signed": true, "total_amount": 344030.52, "tenant_signed": true, "application_id": null, "signing_status": "signed"}, "start_date": {"end_date": "2025-11-13", "created_at": "2025-03-29T06:05:50.041976", "start_date": "2025-07-29", "contract_id": 28, "owner_signed": true, "total_amount": 344030.52, "tenant_signed": true, "application_id": null, "signing_status": "signed"}, "contract_id": {"end_date": "2025-11-13", "created_at": "2025-03-29T06:05:50.041976", "start_date": "2025-07-29", "contract_id": 28, "owner_signed": true, "total_amount": 344030.52, "tenant_signed": true, "application_id": null, "signing_status": "signed"}, "owner_signed": {"end_date": "2025-11-13", "created_at": "2025-03-29T06:05:50.041976", "start_date": "2025-07-29", "contract_id": 28, "owner_signed": true, "total_amount": 344030.52, "tenant_signed": true, "application_id": null, "signing_status": "signed"}, "total_amount": {"end_date": "2025-11-13", "created_at": "2025-03-29T06:05:50.041976", "start_date": "2025-07-29", "contract_id": 28, "owner_signed": true, "total_amount": 344030.52, "tenant_signed": true, "application_id": null, "signing_status": "signed"}, "tenant_signed": {"end_date": "2025-11-13", "created_at": "2025-03-29T06:05:50.041976", "start_date": "2025-07-29", "contract_id": 28, "owner_signed": true, "total_amount": 344030.52, "tenant_signed": true, "application_id": null, "signing_status": "signed"}, "application_id": {"end_date": "2025-11-13", "created_at": "2025-03-29T06:05:50.041976", "start_date": "2025-07-29", "contract_id": 28, "owner_signed": true, "total_amount": 344030.52, "tenant_signed": true, "application_id": null, "signing_status": "signed"}, "signing_status": {"end_date": "2025-11-13", "created_at": "2025-03-29T06:05:50.041976", "start_date": "2025-07-29", "contract_id": 28, "owner_signed": true, "total_amount": 344030.52, "tenant_signed": true, "application_id": null, "signing_status": "signed"}}, "old_data": {"end_date": "2025-11-13", "created_at": "2025-03-29T06:05:50.041976", "start_date": "2025-07-29", "contract_id": 28, "owner_signed": true, "total_amount": 344030.52, "tenant_signed": true, "application_id": 164, "signing_status": "signed"}}	2026-03-11 20:44:23.238356
32	\N	UPDATE	contracts	33	{"changes": {"end_date": {"end_date": "2025-11-26", "created_at": "2025-03-19T09:07:32.453203", "start_date": "2025-07-22", "contract_id": 33, "owner_signed": true, "total_amount": 435800.25, "tenant_signed": true, "application_id": null, "signing_status": "signed"}, "created_at": {"end_date": "2025-11-26", "created_at": "2025-03-19T09:07:32.453203", "start_date": "2025-07-22", "contract_id": 33, "owner_signed": true, "total_amount": 435800.25, "tenant_signed": true, "application_id": null, "signing_status": "signed"}, "start_date": {"end_date": "2025-11-26", "created_at": "2025-03-19T09:07:32.453203", "start_date": "2025-07-22", "contract_id": 33, "owner_signed": true, "total_amount": 435800.25, "tenant_signed": true, "application_id": null, "signing_status": "signed"}, "contract_id": {"end_date": "2025-11-26", "created_at": "2025-03-19T09:07:32.453203", "start_date": "2025-07-22", "contract_id": 33, "owner_signed": true, "total_amount": 435800.25, "tenant_signed": true, "application_id": null, "signing_status": "signed"}, "owner_signed": {"end_date": "2025-11-26", "created_at": "2025-03-19T09:07:32.453203", "start_date": "2025-07-22", "contract_id": 33, "owner_signed": true, "total_amount": 435800.25, "tenant_signed": true, "application_id": null, "signing_status": "signed"}, "total_amount": {"end_date": "2025-11-26", "created_at": "2025-03-19T09:07:32.453203", "start_date": "2025-07-22", "contract_id": 33, "owner_signed": true, "total_amount": 435800.25, "tenant_signed": true, "application_id": null, "signing_status": "signed"}, "tenant_signed": {"end_date": "2025-11-26", "created_at": "2025-03-19T09:07:32.453203", "start_date": "2025-07-22", "contract_id": 33, "owner_signed": true, "total_amount": 435800.25, "tenant_signed": true, "application_id": null, "signing_status": "signed"}, "application_id": {"end_date": "2025-11-26", "created_at": "2025-03-19T09:07:32.453203", "start_date": "2025-07-22", "contract_id": 33, "owner_signed": true, "total_amount": 435800.25, "tenant_signed": true, "application_id": null, "signing_status": "signed"}, "signing_status": {"end_date": "2025-11-26", "created_at": "2025-03-19T09:07:32.453203", "start_date": "2025-07-22", "contract_id": 33, "owner_signed": true, "total_amount": 435800.25, "tenant_signed": true, "application_id": null, "signing_status": "signed"}}, "old_data": {"end_date": "2025-11-26", "created_at": "2025-03-19T09:07:32.453203", "start_date": "2025-07-22", "contract_id": 33, "owner_signed": true, "total_amount": 435800.25, "tenant_signed": true, "application_id": 169, "signing_status": "signed"}}	2026-03-11 20:44:23.238356
33	\N	DELETE	applications	164	{"action": "DELETE", "deleted_data": {"answer": "Объект свободен на эти даты, жду подтверждения", "status": "approved", "message": "Планирую отдых летом, интересует аренда на курортный сезон", "tenant_id": 13, "created_at": "2025-03-21T00:00:00", "property_id": 148, "desired_date": "2025-07-29", "responded_at": "2025-03-25T00:00:00", "duration_days": 107, "application_id": 164}}	2026-03-11 20:44:23.238356
34	\N	DELETE	applications	169	{"action": "DELETE", "deleted_data": {"answer": "Объект свободен на эти даты, жду подтверждения", "status": "approved", "message": "Планирую отдых летом, интересует аренда на курортный сезон", "tenant_id": 13, "created_at": "2025-03-04T00:00:00", "property_id": 148, "desired_date": "2025-07-22", "responded_at": "2025-03-18T00:00:00", "duration_days": 127, "application_id": 169}}	2026-03-11 20:44:23.238356
35	\N	DELETE	applications	389	{"action": "DELETE", "deleted_data": {"answer": "Можем встретиться для обсуждения", "status": "approved", "message": "Интересует аренда на длительный срок", "tenant_id": 18, "created_at": "2026-03-16T00:00:00", "property_id": 148, "desired_date": "2026-03-30", "responded_at": "2026-03-20T00:00:00", "duration_days": 362, "application_id": 389}}	2026-03-11 20:44:23.238356
36	\N	DELETE	properties	148	{"action": "DELETE", "deleted_data": {"area": 85.00, "city": "Геленджик", "price": 90000.00, "rooms": 3, "title": "Дом в Тонком Мысе", "status": "active", "address": "Тонкий Мыс, ул. Прибрежная, д. 12", "owner_id": 5, "created_at": "2026-03-10T20:27:37.442124", "description": "Уютный дом в тихом районе, до моря 10 минут пешком", "property_id": 148, "interval_pay": "month", "property_type": "house"}}	2026-03-11 20:44:23.238356
37	1	UPDATE	properties	1	{"table": "properties", "changes": {"description": {"new": "Тест аудита", "old": "Просторная квартира с видом на набережную, отличный ремонт, вся техника новая"}}, "old_data": {"area": 65.50, "city": "Москва", "price": 45000.00, "rooms": 2, "title": "Уютная квартира в центре", "status": "active", "address": "ул. Тверская, д. 10, кв. 45", "owner_id": 2, "created_at": "2026-02-13T21:58:34.38867", "description": "Просторная квартира с видом на набережную, отличный ремонт, вся техника новая", "property_id": 1, "interval_pay": "month", "property_type": "apartment"}}	2026-03-11 21:15:44.297524
38	1	UPDATE	users	6	{"table": "users", "changes": {"full_name": {"new": "Тестовый пользователь", "old": "Алексей Кузнецов"}}, "old_data": {"email": "tenant.alex@mail.ru", "user_id": 6, "full_name": "Алексей Кузнецов", "is_active": true, "user_type": "tenant", "avatar_url": null, "created_at": "2026-02-13T21:58:34.368669", "contact_info": {"phone": "+7 (999) 678-90-12"}, "password_hash": "b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33"}}	2026-03-11 21:15:44.297524
39	\N	INSERT	properties	168	{"table": "properties", "action": "INSERT", "new_data": {"area": 33.00, "city": "Орехово-Зуево", "price": 3222.00, "rooms": 3, "title": "Коммерческое помещение", "status": "active", "address": "ул. Спортивная, д. 10", "owner_id": 2, "created_at": "2026-03-12T19:19:54.693729", "description": "ууауауа", "property_id": 168, "interval_pay": "week", "property_type": "apartment"}}	2026-03-12 22:19:54.636604
40	\N	DELETE	properties	168	{"table": "properties", "action": "DELETE", "deleted_data": {"area": 33.00, "city": "Орехово-Зуево", "price": 3222.00, "rooms": 3, "title": "Коммерческое помещение", "status": "active", "address": "ул. Спортивная, д. 10", "owner_id": 2, "created_at": "2026-03-12T19:19:54.693729", "description": "ууауауа", "property_id": 168, "interval_pay": "week", "property_type": "apartment"}}	2026-03-12 22:20:13.143864
41	\N	INSERT	properties	169	{"table": "properties", "action": "INSERT", "new_data": {"area": 0.00, "city": "dgdg", "price": 0.00, "rooms": 0, "title": "dgdgg", "status": "active", "address": "dgdgdg", "owner_id": 2, "created_at": "2026-03-13T17:13:54.143996", "description": "", "property_id": 169, "interval_pay": "month", "property_type": "apartment"}}	2026-03-13 20:13:54.075931
43	\N	INSERT	properties	170	{"table": "properties", "action": "INSERT", "new_data": {"area": 0.00, "city": "dfdfdf", "price": 0.00, "rooms": 0, "title": "fddfdf", "status": "draft", "address": "dfdfdfdf", "owner_id": 2, "created_at": "2026-03-13T17:37:31.550616", "description": "", "property_id": 170, "interval_pay": "month", "property_type": "apartment"}}	2026-03-13 20:37:31.52798
44	\N	UPDATE	properties	170	{"table": "properties", "changes": {"status": {"new": "active", "old": "draft"}}, "old_data": {"area": 0.00, "city": "dfdfdf", "price": 0.00, "rooms": 0, "title": "fddfdf", "status": "draft", "address": "dfdfdfdf", "owner_id": 2, "created_at": "2026-03-13T17:37:31.550616", "description": "", "property_id": 170, "interval_pay": "month", "property_type": "apartment"}}	2026-03-13 20:37:41.374322
45	\N	DELETE	properties	170	{"table": "properties", "action": "DELETE", "deleted_data": {"area": 0.00, "city": "dfdfdf", "price": 0.00, "rooms": 0, "title": "fddfdf", "status": "active", "address": "dfdfdfdf", "owner_id": 2, "created_at": "2026-03-13T17:37:31.550616", "description": "", "property_id": 170, "interval_pay": "month", "property_type": "apartment"}}	2026-03-13 20:37:48.966196
46	\N	INSERT	properties	171	{"table": "properties", "action": "INSERT", "new_data": {"area": 0.00, "city": "fff", "price": 0.00, "rooms": 0, "title": "fff", "status": "draft", "address": "ffff", "owner_id": 2, "created_at": "2026-03-13T17:38:06.254228", "description": "fffff", "property_id": 171, "interval_pay": "month", "property_type": "apartment"}}	2026-03-13 20:38:06.232998
47	\N	UPDATE	properties	171	{"table": "properties", "changes": {"status": {"new": "active", "old": "draft"}}, "old_data": {"area": 0.00, "city": "fff", "price": 0.00, "rooms": 0, "title": "fff", "status": "draft", "address": "ffff", "owner_id": 2, "created_at": "2026-03-13T17:38:06.254228", "description": "fffff", "property_id": 171, "interval_pay": "month", "property_type": "apartment"}}	2026-03-13 20:38:34.695797
48	\N	INSERT	properties	172	{"table": "properties", "action": "INSERT", "new_data": {"area": 0.00, "city": "ввв", "price": 0.00, "rooms": 0, "title": "ввв", "status": "draft", "address": "ввв", "owner_id": 2, "created_at": "2026-03-13T17:45:01.582798", "description": "вввв", "property_id": 172, "interval_pay": "month", "property_type": "apartment"}}	2026-03-13 20:45:01.555296
49	\N	UPDATE	properties	172	{"table": "properties", "changes": {"status": {"new": "active", "old": "draft"}}, "old_data": {"area": 0.00, "city": "ввв", "price": 0.00, "rooms": 0, "title": "ввв", "status": "draft", "address": "ввв", "owner_id": 2, "created_at": "2026-03-13T17:45:01.582798", "description": "вввв", "property_id": 172, "interval_pay": "month", "property_type": "apartment"}}	2026-03-13 20:50:01.051161
50	\N	DELETE	properties	172	{"table": "properties", "action": "DELETE", "deleted_data": {"area": 0.00, "city": "ввв", "price": 0.00, "rooms": 0, "title": "ввв", "status": "active", "address": "ввв", "owner_id": 2, "created_at": "2026-03-13T17:45:01.582798", "description": "вввв", "property_id": 172, "interval_pay": "month", "property_type": "apartment"}}	2026-03-13 21:22:00.550799
51	\N	INSERT	properties	173	{"table": "properties", "action": "INSERT", "new_data": {"area": 0.00, "city": "thth", "price": 0.00, "rooms": 0, "title": "ytry", "status": "draft", "address": "hthth", "owner_id": 2, "created_at": "2026-03-13T18:22:17.07505", "description": "hrhrhhrt", "property_id": 173, "interval_pay": "month", "property_type": "apartment"}}	2026-03-13 21:22:17.047807
52	\N	DELETE	properties	171	{"table": "properties", "action": "DELETE", "deleted_data": {"area": 0.00, "city": "fff", "price": 0.00, "rooms": 0, "title": "fff", "status": "active", "address": "ffff", "owner_id": 2, "created_at": "2026-03-13T17:38:06.254228", "description": "fffff", "property_id": 171, "interval_pay": "month", "property_type": "apartment"}}	2026-03-13 21:26:34.898288
53	\N	UPDATE	applications	2	{"table": "applications", "changes": {"responded_at": {"new": "2026-02-14T21:58:34", "old": null}}, "old_data": {"answer": "Принято, жду вас в пятницу", "status": "approved", "message": "Очень понравилась квартира, готов заключить договор", "tenant_id": 7, "created_at": "2026-02-13T21:58:34.48767", "property_id": 2, "desired_date": "2024-06-10", "responded_at": null, "duration_days": 180, "application_id": 2}}	2026-03-13 21:53:27.631634
54	\N	UPDATE	applications	3	{"table": "applications", "changes": {"responded_at": {"new": "2026-02-14T11:58:34", "old": null}}, "old_data": {"answer": "Цена фиксированная", "status": "rejected", "message": "Дороговато, есть возможность торга?", "tenant_id": 6, "created_at": "2026-02-13T21:58:34.488671", "property_id": 3, "desired_date": "2024-06-20", "responded_at": null, "duration_days": 30, "application_id": 3}}	2026-03-13 21:53:27.631634
55	\N	UPDATE	applications	125	{"table": "applications", "changes": {"responded_at": {"new": "2026-02-22T14:15:00", "old": null}}, "old_data": {"answer": "Да, возможен. Жду вас на просмотр в среду", "status": "approved", "message": "Интересует помещение для магазина, возможен ли долгосрочный договор?", "tenant_id": 6, "created_at": "2026-02-21T14:15:00", "property_id": 3, "desired_date": "2026-03-05", "responded_at": null, "duration_days": 730, "application_id": 125}}	2026-03-13 21:53:27.631634
56	\N	UPDATE	applications	126	{"table": "applications", "changes": {"responded_at": {"new": "2026-02-16T09:45:00", "old": null}}, "old_data": {"answer": "Дом уже сдан на этот период", "status": "rejected", "message": "Хотим снять дом на лето для семьи с детьми", "tenant_id": 6, "created_at": "2026-02-15T09:45:00", "property_id": 5, "desired_date": "2026-06-01", "responded_at": null, "duration_days": 120, "application_id": 126}}	2026-03-13 21:53:27.631634
57	\N	UPDATE	applications	128	{"table": "applications", "changes": {"responded_at": {"new": "2026-02-18T16:30:00", "old": null}}, "old_data": {"answer": "Приходите в пятницу в 15:00", "status": "approved", "message": "Студия очень понравилась, готова заключить договор", "tenant_id": 7, "created_at": "2026-02-18T12:30:00", "property_id": 2, "desired_date": "2026-03-01", "responded_at": null, "duration_days": 365, "application_id": 128}}	2026-03-13 21:53:27.631634
90	\N	INSERT	messages	248	{"table": "messages", "action": "INSERT", "new_data": {"content": "**Заявка approved** на объект 'Коттедж с бассейном'. ", "is_read": false, "created_at": "2026-03-14T19:35:16.768746", "message_id": 248, "to_user_id": 9, "from_user_id": null}}	2026-03-14 19:35:16.766092
58	\N	UPDATE	applications	129	{"table": "applications", "changes": {"responded_at": {"new": "2026-02-22T19:30:00", "old": null}}, "old_data": {"answer": null, "status": "pending", "message": "Квартира в новостройке - мечта! Когда можно посмотреть?", "tenant_id": 7, "created_at": "2026-02-22T11:10:00", "property_id": 128, "desired_date": "2026-03-02", "responded_at": null, "duration_days": 180, "application_id": 129}}	2026-03-13 21:53:27.631634
59	\N	UPDATE	applications	130	{"table": "applications", "changes": {"responded_at": {"new": "2026-02-19T14:45:00", "old": null}}, "old_data": {"answer": "Цена фиксированная", "status": "rejected", "message": "Квартира на Невском - отличный вариант, но дороговато", "tenant_id": 7, "created_at": "2026-02-19T13:45:00", "property_id": 4, "desired_date": "2026-03-15", "responded_at": null, "duration_days": 365, "application_id": 130}}	2026-03-13 21:53:27.631634
60	\N	UPDATE	applications	131	{"table": "applications", "changes": {"responded_at": {"new": "2026-02-22T13:45:00", "old": null}}, "old_data": {"answer": "Жду вас в субботу в 14:00", "status": "approved", "message": "Интересует квартира в Куровском", "tenant_id": 7, "created_at": "2026-02-21T10:00:00", "property_id": 131, "desired_date": "2026-03-05", "responded_at": null, "duration_days": 365, "application_id": 131}}	2026-03-13 21:53:27.631634
61	\N	UPDATE	applications	132	{"table": "applications", "changes": {"responded_at": {"new": "2026-02-23T19:45:00", "old": null}}, "old_data": {"answer": null, "status": "pending", "message": "Квартира в новостройке - супер! Можно посмотреть в выходные?", "tenant_id": 9, "created_at": "2026-02-23T18:30:00", "property_id": 128, "desired_date": "2026-03-03", "responded_at": null, "duration_days": 180, "application_id": 132}}	2026-03-13 21:53:27.631634
62	\N	UPDATE	applications	133	{"table": "applications", "changes": {"responded_at": {"new": "2026-02-23T13:45:00", "old": null}}, "old_data": {"answer": "Приходите во вторник после 18:00", "status": "approved", "message": "Офис в Ликино-Дулёво для небольшой компании", "tenant_id": 9, "created_at": "2026-02-22T15:40:00", "property_id": 130, "desired_date": "2026-03-01", "responded_at": null, "duration_days": 365, "application_id": 133}}	2026-03-13 21:53:27.631634
63	\N	UPDATE	applications	134	{"table": "applications", "changes": {"responded_at": {"new": "2026-02-24T13:45:00", "old": null}}, "old_data": {"answer": null, "status": "cancelled", "message": "Таунхаус интересует для семьи", "tenant_id": 9, "created_at": "2026-02-24T09:15:00", "property_id": 129, "desired_date": "2026-04-01", "responded_at": null, "duration_days": 730, "application_id": 134}}	2026-03-13 21:53:27.631634
64	\N	UPDATE	applications	135	{"table": "applications", "changes": {"responded_at": {"new": "2026-02-21T13:45:00", "old": null}}, "old_data": {"answer": "Можем обсудить", "status": "cancelled", "message": "Апартаменты в Орехово-Зуево", "tenant_id": 9, "created_at": "2026-02-20T11:25:00", "property_id": 132, "desired_date": "2026-03-10", "responded_at": null, "duration_days": 365, "application_id": 135}}	2026-03-13 21:53:27.631634
65	\N	UPDATE	applications	136	{"table": "applications", "changes": {"responded_at": {"new": "2026-02-18T10:45:00", "old": null}}, "old_data": {"answer": "Квартира ещё свободна", "status": "approved", "message": "Повторно интересуюсь квартирой на Тверской", "tenant_id": 6, "created_at": "2026-02-17T08:50:00", "property_id": 1, "desired_date": "2026-03-15", "responded_at": null, "duration_days": 365, "application_id": 136}}	2026-03-13 21:53:27.631634
66	\N	UPDATE	applications	137	{"table": "applications", "changes": {"responded_at": {"new": "2026-02-17T08:45:00", "old": null}}, "old_data": {"answer": "Уже сдан", "status": "rejected", "message": "А дом у озера на лето ещё свободен?", "tenant_id": 7, "created_at": "2026-02-16T14:30:00", "property_id": 3, "desired_date": "2026-06-15", "responded_at": null, "duration_days": 90, "application_id": 137}}	2026-03-13 21:53:27.631634
67	\N	UPDATE	applications	138	{"table": "applications", "changes": {"responded_at": {"new": "2026-02-25T13:45:00", "old": null}}, "old_data": {"answer": null, "status": "cancelled", "message": "Рассматриваю коммерческое помещение в Новосибирске", "tenant_id": 9, "created_at": "2026-02-24T12:10:00", "property_id": 5, "desired_date": "2026-04-01", "responded_at": null, "duration_days": 365, "application_id": 138}}	2026-03-13 21:53:27.631634
68	\N	UPDATE	applications	139	{"table": "applications", "changes": {"responded_at": {"new": "2026-02-26T13:45:00", "old": null}}, "old_data": {"answer": null, "status": "cancelled", "message": "Желаю заселиться", "tenant_id": 9, "created_at": "2026-02-26T17:26:41.519866", "property_id": 131, "desired_date": "2026-03-01", "responded_at": null, "duration_days": 34, "application_id": 139}}	2026-03-13 21:53:27.631634
69	\N	UPDATE	applications	140	{"table": "applications", "changes": {"responded_at": {"new": "2026-03-09T13:45:00", "old": null}}, "old_data": {"answer": null, "status": "pending", "message": "Мне нужно заселиться", "tenant_id": 9, "created_at": "2026-03-09T09:24:57.84671", "property_id": 133, "desired_date": "2026-03-15", "responded_at": null, "duration_days": 140, "application_id": 140}}	2026-03-13 21:53:27.631634
70	\N	UPDATE	applications	141	{"table": "applications", "changes": {"responded_at": {"new": "2026-03-10T09:17:20", "old": null}}, "old_data": {"answer": null, "status": "pending", "message": "Как можно скорее", "tenant_id": 9, "created_at": "2026-03-09T19:17:20.68289", "property_id": 129, "desired_date": "2026-03-19", "responded_at": null, "duration_days": 365, "application_id": 141}}	2026-03-13 21:53:27.631634
71	\N	UPDATE	properties	2	{"table": "properties", "changes": {"status": {"new": "rented", "old": "active"}}, "old_data": {"area": 32.00, "city": "Москва", "price": 35000.00, "rooms": 1, "title": "Студия в новостройке", "status": "active", "address": "ул. Ленина, д. 15", "owner_id": 2, "created_at": "2026-02-13T21:58:34.38867", "description": "Современная студия с дизайнерским ремонтом, есть всё для комфортного проживания", "property_id": 2, "interval_pay": "month", "property_type": "apartment"}}	2026-03-13 21:54:39.221094
72	\N	UPDATE	properties	1	{"table": "properties", "changes": {"status": {"new": "rented", "old": "active"}}, "old_data": {"area": 65.50, "city": "Москва", "price": 45000.00, "rooms": 2, "title": "Уютная квартира в центре", "status": "active", "address": "ул. Тверская, д. 10, кв. 45", "owner_id": 2, "created_at": "2026-02-13T21:58:34.38867", "description": "Тест аудита", "property_id": 1, "interval_pay": "month", "property_type": "apartment"}}	2026-03-13 21:54:39.221094
73	\N	UPDATE	properties	129	{"table": "properties", "changes": {"status": {"new": "rented", "old": "active"}}, "old_data": {"area": 95.00, "city": "Авсюнино", "price": 65000.00, "rooms": 3, "title": "Таунхаус", "status": "active", "address": "ул. Спортивная, д. 10", "owner_id": 2, "created_at": "2026-02-18T15:50:00", "description": "Двухуровневый таунхаус с террасой", "property_id": 129, "interval_pay": "month", "property_type": "house"}}	2026-03-13 21:54:39.221094
74	\N	INSERT	applications	394	{"table": "applications", "action": "INSERT", "new_data": {"answer": null, "status": "pending", "message": "Тест", "tenant_id": 6, "created_at": "2026-03-14T19:01:53.808364", "property_id": 1, "desired_date": "2026-03-14", "responded_at": null, "duration_days": 365, "application_id": 394}}	2026-03-14 19:01:53.808364
75	\N	INSERT	messages	242	{"table": "messages", "action": "INSERT", "new_data": {"content": "📋 **Новая заявка** от Тестовый пользователь на объект \\"Уютная квартира в центре\\"", "is_read": false, "created_at": "2026-03-14T19:01:53.808364", "message_id": 242, "to_user_id": 2, "from_user_id": null}}	2026-03-14 19:01:53.808364
76	\N	UPDATE	messages	187	{"table": "messages", "changes": {"is_read": {"new": true, "old": false}}, "old_data": {"content": "Посоветуй хорошего агента по недвижимости", "is_read": false, "created_at": "2025-06-03T04:52:27.321125", "message_id": 187, "to_user_id": 9, "from_user_id": 3}}	2026-03-14 19:31:27.262299
77	\N	UPDATE	messages	237	{"table": "messages", "changes": {"is_read": {"new": true, "old": false}}, "old_data": {"content": "**Системное сообщение** Скоро заканчивается срок аренды", "is_read": false, "created_at": "2026-01-24T06:35:46.48803", "message_id": 237, "to_user_id": 9, "from_user_id": null}}	2026-03-14 19:31:37.859181
78	\N	UPDATE	messages	231	{"table": "messages", "changes": {"is_read": {"new": true, "old": false}}, "old_data": {"content": "**Внимание** Обновите данные в профиле", "is_read": false, "created_at": "2026-02-25T01:44:37.017336", "message_id": 231, "to_user_id": 9, "from_user_id": null}}	2026-03-14 19:31:44.658047
79	\N	UPDATE	messages	224	{"table": "messages", "changes": {"is_read": {"new": true, "old": false}}, "old_data": {"content": "**Внимание** Обновите данные в профиле", "is_read": false, "created_at": "2025-04-08T20:05:58.992198", "message_id": 224, "to_user_id": 9, "from_user_id": null}}	2026-03-14 19:31:45.983687
80	\N	INSERT	applications	395	{"table": "applications", "action": "INSERT", "new_data": {"answer": null, "status": "pending", "message": "Арендуем четко!", "tenant_id": 9, "created_at": "2026-03-14T19:32:58.087737", "property_id": 149, "desired_date": "2026-05-09", "responded_at": null, "duration_days": 90, "application_id": 395}}	2026-03-14 19:32:58.068672
81	\N	INSERT	messages	243	{"table": "messages", "action": "INSERT", "new_data": {"content": "📋 **Новая заявка** от Боев Владислав Максимович на объект \\"Коттедж с бассейном\\"", "is_read": false, "created_at": "2026-03-14T19:32:58.068672", "message_id": 243, "to_user_id": 12, "from_user_id": null}}	2026-03-14 19:32:58.068672
82	\N	UPDATE	messages	243	{"table": "messages", "changes": {"is_read": {"new": true, "old": false}}, "old_data": {"content": "📋 **Новая заявка** от Боев Владислав Максимович на объект \\"Коттедж с бассейном\\"", "is_read": false, "created_at": "2026-03-14T19:32:58.068672", "message_id": 243, "to_user_id": 12, "from_user_id": null}}	2026-03-14 19:33:16.422863
83	\N	INSERT	messages	244	{"table": "messages", "action": "INSERT", "new_data": {"content": "✍️ **Арендатор подписал договор**: Боев Владислав Максимович подписал договор на объект \\"Квартира\\"", "is_read": false, "created_at": "2026-03-14T19:34:43.385256", "message_id": 244, "to_user_id": 5, "from_user_id": null}}	2026-03-14 19:34:43.385256
84	\N	INSERT	messages	245	{"table": "messages", "action": "INSERT", "new_data": {"content": "✍️ **Арендатор подписал договор**: Боев Владислав Максимович подписал договор на объект \\"Квартира\\"", "is_read": false, "created_at": "2026-03-14T19:34:43.385256", "message_id": 245, "to_user_id": 5, "from_user_id": null}}	2026-03-14 19:34:43.385256
85	\N	UPDATE	contracts	92	{"table": "contracts", "changes": {"tenant_signed": {"new": true, "old": false}, "signing_status": {"new": "pending", "old": "draft"}}, "old_data": {"end_date": "2027-06-16", "created_at": "2026-03-14T00:03:50.015217", "start_date": "2026-03-18", "contract_id": 92, "owner_signed": false, "total_amount": 208000.00, "tenant_signed": false, "application_id": 388, "signing_status": "draft"}}	2026-03-14 19:34:43.385256
86	\N	INSERT	contracts	95	{"table": "contracts", "action": "INSERT", "new_data": {"end_date": "2026-08-07", "created_at": "2026-03-14T19:35:16.672442", "start_date": "2026-05-09", "contract_id": 95, "owner_signed": false, "total_amount": 750000.00, "tenant_signed": false, "application_id": 395, "signing_status": "draft"}}	2026-03-14 19:35:16.672442
87	\N	INSERT	messages	246	{"table": "messages", "action": "INSERT", "new_data": {"content": "✅ **Заявка одобрена** на объект \\"Коттедж с бассейном\\"", "is_read": false, "created_at": "2026-03-14T19:35:16.672442", "message_id": 246, "to_user_id": 9, "from_user_id": null}}	2026-03-14 19:35:16.672442
88	\N	INSERT	messages	247	{"table": "messages", "action": "INSERT", "new_data": {"content": "✅ **Заявка одобрена** на объект \\"Коттедж с бассейном\\"", "is_read": false, "created_at": "2026-03-14T19:35:16.672442", "message_id": 247, "to_user_id": 9, "from_user_id": null}}	2026-03-14 19:35:16.672442
89	\N	UPDATE	applications	395	{"table": "applications", "changes": {"status": {"new": "approved", "old": "pending"}, "responded_at": {"new": "2026-03-14T19:35:16.674374", "old": null}}, "old_data": {"answer": null, "status": "pending", "message": "Арендуем четко!", "tenant_id": 9, "created_at": "2026-03-14T19:32:58.087737", "property_id": 149, "desired_date": "2026-05-09", "responded_at": null, "duration_days": 90, "application_id": 395}}	2026-03-14 19:35:16.672442
91	\N	UPDATE	messages	247	{"table": "messages", "changes": {"is_read": {"new": true, "old": false}}, "old_data": {"content": "✅ **Заявка одобрена** на объект \\"Коттедж с бассейном\\"", "is_read": false, "created_at": "2026-03-14T19:35:16.672442", "message_id": 247, "to_user_id": 9, "from_user_id": null}}	2026-03-14 19:35:33.459262
92	\N	UPDATE	messages	248	{"table": "messages", "changes": {"is_read": {"new": true, "old": false}}, "old_data": {"content": "**Заявка approved** на объект 'Коттедж с бассейном'. ", "is_read": false, "created_at": "2026-03-14T19:35:16.768746", "message_id": 248, "to_user_id": 9, "from_user_id": null}}	2026-03-14 19:35:36.370394
93	\N	UPDATE	messages	246	{"table": "messages", "changes": {"is_read": {"new": true, "old": false}}, "old_data": {"content": "✅ **Заявка одобрена** на объект \\"Коттедж с бассейном\\"", "is_read": false, "created_at": "2026-03-14T19:35:16.672442", "message_id": 246, "to_user_id": 9, "from_user_id": null}}	2026-03-14 19:35:39.466484
94	\N	INSERT	messages	249	{"table": "messages", "action": "INSERT", "new_data": {"content": "✍️ **Собственник подписал договор**: Соловьёва Юлия Сергеевна подписал договор на объект \\"Коттедж с бассейном\\"", "is_read": false, "created_at": "2026-03-14T20:00:50.450466", "message_id": 249, "to_user_id": 9, "from_user_id": null}}	2026-03-14 20:00:50.450466
95	\N	INSERT	messages	250	{"table": "messages", "action": "INSERT", "new_data": {"content": "✍️ **Собственник подписал договор**: Соловьёва Юлия Сергеевна подписал договор на объект \\"Коттедж с бассейном\\"", "is_read": false, "created_at": "2026-03-14T20:00:50.450466", "message_id": 250, "to_user_id": 9, "from_user_id": null}}	2026-03-14 20:00:50.450466
96	\N	UPDATE	contracts	95	{"table": "contracts", "changes": {"owner_signed": {"new": true, "old": false}, "signing_status": {"new": "pending", "old": "draft"}}, "old_data": {"end_date": "2026-08-07", "created_at": "2026-03-14T19:35:16.672442", "start_date": "2026-05-09", "contract_id": 95, "owner_signed": false, "total_amount": 750000.00, "tenant_signed": false, "application_id": 395, "signing_status": "draft"}}	2026-03-14 20:00:50.450466
97	\N	UPDATE	messages	250	{"table": "messages", "changes": {"is_read": {"new": true, "old": false}}, "old_data": {"content": "✍️ **Собственник подписал договор**: Соловьёва Юлия Сергеевна подписал договор на объект \\"Коттедж с бассейном\\"", "is_read": false, "created_at": "2026-03-14T20:00:50.450466", "message_id": 250, "to_user_id": 9, "from_user_id": null}}	2026-03-14 20:10:52.000821
98	\N	UPDATE	messages	249	{"table": "messages", "changes": {"is_read": {"new": true, "old": false}}, "old_data": {"content": "✍️ **Собственник подписал договор**: Соловьёва Юлия Сергеевна подписал договор на объект \\"Коттедж с бассейном\\"", "is_read": false, "created_at": "2026-03-14T20:00:50.450466", "message_id": 249, "to_user_id": 9, "from_user_id": null}}	2026-03-14 20:10:59.489419
99	\N	INSERT	contracts	96	{"table": "contracts", "action": "INSERT", "new_data": {"end_date": "2027-03-19", "created_at": "2026-03-14T20:27:01.682142", "start_date": "2026-03-19", "contract_id": 96, "owner_signed": false, "total_amount": 845000.00, "tenant_signed": false, "application_id": 141, "signing_status": "draft"}}	2026-03-14 20:27:01.682142
100	\N	INSERT	messages	251	{"table": "messages", "action": "INSERT", "new_data": {"content": "✅ **Заявка одобрена** на объект \\"Таунхаус\\"", "is_read": false, "created_at": "2026-03-14T20:27:01.682142", "message_id": 251, "to_user_id": 9, "from_user_id": null}}	2026-03-14 20:27:01.682142
101	\N	INSERT	messages	252	{"table": "messages", "action": "INSERT", "new_data": {"content": "✅ **Заявка одобрена** на объект \\"Таунхаус\\"", "is_read": false, "created_at": "2026-03-14T20:27:01.682142", "message_id": 252, "to_user_id": 9, "from_user_id": null}}	2026-03-14 20:27:01.682142
102	\N	UPDATE	applications	141	{"table": "applications", "changes": {"status": {"new": "approved", "old": "pending"}}, "old_data": {"answer": null, "status": "pending", "message": "Как можно скорее", "tenant_id": 9, "created_at": "2026-03-09T19:17:20.68289", "property_id": 129, "desired_date": "2026-03-19", "responded_at": "2026-03-10T09:17:20", "duration_days": 365, "application_id": 141}}	2026-03-14 20:27:01.682142
105	\N	INSERT	messages	253	{"table": "messages", "action": "INSERT", "new_data": {"content": "**Договор отменён** на объект \\"Коттедж с бассейном\\"", "is_read": false, "created_at": "2026-03-14T20:34:30.943048", "message_id": 253, "to_user_id": 9, "from_user_id": null}}	2026-03-14 20:34:30.943048
106	\N	INSERT	messages	254	{"table": "messages", "action": "INSERT", "new_data": {"content": "**Договор отменён** на объект \\"Коттедж с бассейном\\"", "is_read": false, "created_at": "2026-03-14T20:34:30.943048", "message_id": 254, "to_user_id": 12, "from_user_id": null}}	2026-03-14 20:34:30.943048
107	\N	UPDATE	contracts	95	{"table": "contracts", "changes": {"signing_status": {"new": "cancelled", "old": "pending"}}, "old_data": {"end_date": "2026-08-07", "created_at": "2026-03-14T19:35:16.672442", "start_date": "2026-05-09", "contract_id": 95, "owner_signed": true, "total_amount": 750000.00, "tenant_signed": false, "application_id": 395, "signing_status": "pending"}}	2026-03-14 20:34:30.943048
108	\N	INSERT	messages	255	{"table": "messages", "action": "INSERT", "new_data": {"content": "**Договор отменён** на объект 'Коттедж с бассейном'. Договор №95", "is_read": false, "created_at": "2026-03-14T20:34:30.972685", "message_id": 255, "to_user_id": 9, "from_user_id": null}}	2026-03-14 20:34:30.96904
109	\N	UPDATE	messages	255	{"table": "messages", "changes": {"is_read": {"new": true, "old": false}}, "old_data": {"content": "**Договор отменён** на объект 'Коттедж с бассейном'. Договор №95", "is_read": false, "created_at": "2026-03-14T20:34:30.972685", "message_id": 255, "to_user_id": 9, "from_user_id": null}}	2026-03-14 20:34:58.93099
110	\N	UPDATE	messages	253	{"table": "messages", "changes": {"is_read": {"new": true, "old": false}}, "old_data": {"content": "**Договор отменён** на объект \\"Коттедж с бассейном\\"", "is_read": false, "created_at": "2026-03-14T20:34:30.943048", "message_id": 253, "to_user_id": 9, "from_user_id": null}}	2026-03-14 20:35:00.256632
111	\N	UPDATE	messages	251	{"table": "messages", "changes": {"is_read": {"new": true, "old": false}}, "old_data": {"content": "✅ **Заявка одобрена** на объект \\"Таунхаус\\"", "is_read": false, "created_at": "2026-03-14T20:27:01.682142", "message_id": 251, "to_user_id": 9, "from_user_id": null}}	2026-03-14 20:35:01.312104
112	\N	UPDATE	messages	252	{"table": "messages", "changes": {"is_read": {"new": true, "old": false}}, "old_data": {"content": "✅ **Заявка одобрена** на объект \\"Таунхаус\\"", "is_read": false, "created_at": "2026-03-14T20:27:01.682142", "message_id": 252, "to_user_id": 9, "from_user_id": null}}	2026-03-14 20:35:01.312104
113	\N	DELETE	messages	245	{"table": "messages", "action": "DELETE", "deleted_data": {"content": "✍️ **Арендатор подписал договор**: Боев Владислав Максимович подписал договор на объект \\"Квартира\\"", "is_read": false, "created_at": "2026-03-14T19:34:43.385256", "message_id": 245, "to_user_id": 5, "from_user_id": null}}	2026-03-15 15:00:29.663945
114	\N	DELETE	messages	247	{"table": "messages", "action": "DELETE", "deleted_data": {"content": "✅ **Заявка одобрена** на объект \\"Коттедж с бассейном\\"", "is_read": true, "created_at": "2026-03-14T19:35:16.672442", "message_id": 247, "to_user_id": 9, "from_user_id": null}}	2026-03-15 15:00:29.663945
115	\N	DELETE	messages	250	{"table": "messages", "action": "DELETE", "deleted_data": {"content": "✍️ **Собственник подписал договор**: Соловьёва Юлия Сергеевна подписал договор на объект \\"Коттедж с бассейном\\"", "is_read": true, "created_at": "2026-03-14T20:00:50.450466", "message_id": 250, "to_user_id": 9, "from_user_id": null}}	2026-03-15 15:00:29.663945
116	\N	DELETE	messages	252	{"table": "messages", "action": "DELETE", "deleted_data": {"content": "✅ **Заявка одобрена** на объект \\"Таунхаус\\"", "is_read": true, "created_at": "2026-03-14T20:27:01.682142", "message_id": 252, "to_user_id": 9, "from_user_id": null}}	2026-03-15 15:00:29.663945
117	\N	UPDATE	messages	254	{"table": "messages", "changes": {"is_read": {"new": true, "old": false}}, "old_data": {"content": "**Договор отменён** на объект \\"Коттедж с бассейном\\"", "is_read": false, "created_at": "2026-03-14T20:34:30.943048", "message_id": 254, "to_user_id": 12, "from_user_id": null}}	2026-03-15 15:04:54.968618
118	\N	INSERT	messages	256	{"table": "messages", "action": "INSERT", "new_data": {"content": "❌ **Заявка отклонена** на объект \\"Коттедж с бассейном\\"", "is_read": false, "created_at": "2026-03-15T16:14:09.400207", "message_id": 256, "to_user_id": 11, "from_user_id": null}}	2026-03-15 16:14:09.400207
119	\N	UPDATE	applications	319	{"table": "applications", "changes": {"answer": {"new": "Извините, уже поздно! Счастливого вам!", "old": null}, "status": {"new": "rejected", "old": "pending"}, "responded_at": {"new": "2026-03-15T16:14:09.402629", "old": null}}, "old_data": {"answer": null, "status": "pending", "message": "Нужна дополнительная информация", "tenant_id": 11, "created_at": "2025-06-18T00:00:00", "property_id": 149, "desired_date": "2025-07-02", "responded_at": null, "duration_days": 270, "application_id": 319}}	2026-03-15 16:14:09.400207
120	\N	INSERT	messages	257	{"table": "messages", "action": "INSERT", "new_data": {"content": "**Заявка rejected** на объект 'Коттедж с бассейном'. Ответ: Извините, уже поздно! Счастливого вам!", "is_read": false, "created_at": "2026-03-15T16:14:09.492351", "message_id": 257, "to_user_id": 11, "from_user_id": null}}	2026-03-15 16:14:09.488008
121	\N	INSERT	messages	258	{"table": "messages", "action": "INSERT", "new_data": {"content": "❌ **Заявка отклонена** на объект \\"Коммерческое помещение\\"", "is_read": false, "created_at": "2026-03-15T16:18:42.242342", "message_id": 258, "to_user_id": 11, "from_user_id": null}}	2026-03-15 16:18:42.242342
122	\N	UPDATE	applications	330	{"table": "applications", "changes": {"answer": {"new": "Уже поздно, извините!", "old": null}, "status": {"new": "rejected", "old": "pending"}, "responded_at": {"new": "2026-03-15T16:18:42.245079", "old": null}}, "old_data": {"answer": null, "status": "pending", "message": "Отличный вариант, готов обсудить условия", "tenant_id": 11, "created_at": "2025-07-07T00:00:00", "property_id": 158, "desired_date": "2025-07-21", "responded_at": null, "duration_days": 544, "application_id": 330}}	2026-03-15 16:18:42.242342
123	\N	INSERT	messages	259	{"table": "messages", "action": "INSERT", "new_data": {"content": "**Заявка rejected** на объект 'Коммерческое помещение'. Ответ: Уже поздно, извините!", "is_read": false, "created_at": "2026-03-15T16:18:42.253063", "message_id": 259, "to_user_id": 11, "from_user_id": null}}	2026-03-15 16:18:42.25179
124	\N	INSERT	messages	260	{"table": "messages", "action": "INSERT", "new_data": {"content": "ааа", "is_read": false, "created_at": "2026-03-15T15:17:08.888541", "message_id": 260, "to_user_id": 3, "from_user_id": 9}}	2026-03-15 18:17:08.886259
125	\N	INSERT	users	21	{"table": "users", "action": "INSERT", "new_data": {"email": "taranenko@rentease.ru", "user_id": 21, "full_name": "Тараненко Иван Сергеевич", "is_active": true, "user_type": "tenant", "avatar_url": null, "created_at": "2026-03-15T18:27:54.989358", "contact_info": {"inn": "2556647474", "passport": "5667778883"}, "password_hash": "533210cab25f6672bf323836b0c6bc8db5ead1fae818cea67865fe1f6daf4368"}}	2026-03-15 18:27:54.992849
126	\N	UPDATE	users	21	{"table": "users", "changes": {"avatar_url": {"new": "/static/uploads/avatars/f730e34f54024682ac271e381da8a3e7.png", "old": null}}, "old_data": {"email": "taranenko@rentease.ru", "user_id": 21, "full_name": "Тараненко Иван Сергеевич", "is_active": true, "user_type": "tenant", "avatar_url": null, "created_at": "2026-03-15T18:27:54.989358", "contact_info": {"inn": "2556647474", "passport": "5667778883"}, "password_hash": "533210cab25f6672bf323836b0c6bc8db5ead1fae818cea67865fe1f6daf4368"}}	2026-03-15 18:27:55.047231
127	\N	UPDATE	users	1	{"table": "users", "changes": {"is_active": {"new": false, "old": true}}, "old_data": {"email": "admin@rentease.ru", "user_id": 1, "full_name": "Администратор Системы", "is_active": true, "user_type": "admin", "avatar_url": "/static/uploads/avatars/1fe7541a1df541f4a6abadc71e67463e.jpg", "created_at": "2026-02-13T21:58:34.325669", "contact_info": {"phone": "+7 (999) 123-45-67", "birth_date": "2000-01-02"}, "password_hash": "240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9"}}	2026-03-15 20:34:48.373555
128	1	TOGGLE_BLOCK	user	1	{"changes": {"is_active": false}}	2026-03-15 17:34:48.425434
129	\N	UPDATE	users	1	{"table": "users", "changes": {"is_active": {"new": true, "old": false}}, "old_data": {"email": "admin@rentease.ru", "user_id": 1, "full_name": "Администратор Системы", "is_active": false, "user_type": "admin", "avatar_url": "/static/uploads/avatars/1fe7541a1df541f4a6abadc71e67463e.jpg", "created_at": "2026-02-13T21:58:34.325669", "contact_info": {"phone": "+7 (999) 123-45-67", "birth_date": "2000-01-02"}, "password_hash": "240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9"}}	2026-03-15 20:34:51.17918
130	1	TOGGLE_BLOCK	user	1	{"changes": {"is_active": true}}	2026-03-15 17:34:51.190107
131	\N	UPDATE	users	12	{"table": "users", "changes": {"is_active": {"new": false, "old": true}}, "old_data": {"email": "qmett1@gmail.com", "user_id": 12, "full_name": "Соловьёва Юлия Сергеевна", "is_active": true, "user_type": "agent", "avatar_url": "/static/uploads/avatars/e5afd064062f46de89802f5ef3ca4bae.jpg", "created_at": "2026-03-10T20:02:42.602234", "contact_info": {"inn": "4324435667", "city": "Ликино-Дулёво", "phone": "+79066784781", "passport": "4621789012", "birth_date": "2007-01-02"}, "password_hash": "bdc1e3618db56b35a6c7d8c0375166fd7b11893c9bca67113b4ea963b454fb8e"}}	2026-03-15 20:35:20.878305
132	1	TOGGLE_BLOCK	user	12	{"changes": {"is_active": false}}	2026-03-15 17:35:20.88673
133	\N	UPDATE	users	12	{"table": "users", "changes": {"is_active": {"new": true, "old": false}}, "old_data": {"email": "qmett1@gmail.com", "user_id": 12, "full_name": "Соловьёва Юлия Сергеевна", "is_active": false, "user_type": "agent", "avatar_url": "/static/uploads/avatars/e5afd064062f46de89802f5ef3ca4bae.jpg", "created_at": "2026-03-10T20:02:42.602234", "contact_info": {"inn": "4324435667", "city": "Ликино-Дулёво", "phone": "+79066784781", "passport": "4621789012", "birth_date": "2007-01-02"}, "password_hash": "bdc1e3618db56b35a6c7d8c0375166fd7b11893c9bca67113b4ea963b454fb8e"}}	2026-03-15 20:35:24.036294
134	1	TOGGLE_BLOCK	user	12	{"changes": {"is_active": true}}	2026-03-15 17:35:24.042493
135	\N	INSERT	messages	261	{"table": "messages", "action": "INSERT", "new_data": {"content": "оло", "is_read": false, "created_at": "2026-03-15T17:46:44.202952", "message_id": 261, "to_user_id": 4, "from_user_id": 1}}	2026-03-15 20:46:44.200839
136	\N	UPDATE	messages	261	{"table": "messages", "changes": {"is_read": {"new": true, "old": false}}, "old_data": {"content": "оло", "is_read": false, "created_at": "2026-03-15T17:46:44.202952", "message_id": 261, "to_user_id": 4, "from_user_id": 1}}	2026-03-15 20:46:49.206285
137	\N	UPDATE	messages	127	{"table": "messages", "changes": {"is_read": {"new": true, "old": false}}, "old_data": {"content": "Хочу уточнить детали перед подписанием", "is_read": false, "created_at": "2026-03-02T14:52:24.819384", "message_id": 127, "to_user_id": 4, "from_user_id": 6}}	2026-03-15 20:50:04.988394
138	\N	UPDATE	messages	220	{"table": "messages", "changes": {"is_read": {"new": true, "old": false}}, "old_data": {"content": "**Системное сообщение** Скоро заканчивается срок аренды", "is_read": false, "created_at": "2025-11-03T13:37:21.858491", "message_id": 220, "to_user_id": 17, "from_user_id": null}}	2026-03-15 21:03:07.390662
139	\N	UPDATE	messages	235	{"table": "messages", "changes": {"is_read": {"new": true, "old": false}}, "old_data": {"content": "**Уведомление** Ваша заявка №1069 одобрена", "is_read": false, "created_at": "2025-01-05T19:11:16.268937", "message_id": 235, "to_user_id": 17, "from_user_id": null}}	2026-03-15 21:03:15.485251
140	\N	INSERT	contracts	97	{"table": "contracts", "action": "INSERT", "new_data": {"end_date": "2026-09-17", "created_at": "2026-03-15T21:04:53.015646", "start_date": "2026-03-21", "contract_id": 97, "owner_signed": false, "total_amount": 1500000.00, "tenant_signed": false, "application_id": 353, "signing_status": "draft"}}	2026-03-15 21:04:53.015646
141	\N	INSERT	messages	262	{"table": "messages", "action": "INSERT", "new_data": {"content": "📄 **Договор создан** на объект \\"Коттедж с бассейном\\". Ожидается подписание.", "is_read": false, "created_at": "2026-03-15T21:04:53.015646", "message_id": 262, "to_user_id": 17, "from_user_id": null}}	2026-03-15 21:04:53.015646
142	\N	INSERT	messages	263	{"table": "messages", "action": "INSERT", "new_data": {"content": "📄 **Договор создан** на объект \\"Коттедж с бассейном\\" с арендатором Феоктистов Глеб Юрьевич. Ожидается подписание.", "is_read": false, "created_at": "2026-03-15T21:04:53.015646", "message_id": 263, "to_user_id": 12, "from_user_id": null}}	2026-03-15 21:04:53.015646
143	\N	INSERT	messages	264	{"table": "messages", "action": "INSERT", "new_data": {"content": "✅ **Заявка одобрена** на объект \\"Коттедж с бассейном\\"", "is_read": false, "created_at": "2026-03-15T21:04:53.015646", "message_id": 264, "to_user_id": 17, "from_user_id": null}}	2026-03-15 21:04:53.015646
144	\N	UPDATE	applications	353	{"table": "applications", "changes": {"answer": {"new": "По коммунальным причинам перенес уменьшил кол-во дней.", "old": null}, "status": {"new": "approved", "old": "pending"}, "desired_date": {"new": "2026-03-21", "old": "2025-10-18"}, "responded_at": {"new": "2026-03-15T21:04:53.018707", "old": null}, "duration_days": {"new": 180, "old": 260}}, "old_data": {"answer": null, "status": "pending", "message": "Интересует аренда на длительный срок", "tenant_id": 17, "created_at": "2025-10-04T00:00:00", "property_id": 149, "desired_date": "2025-10-18", "responded_at": null, "duration_days": 260, "application_id": 353}}	2026-03-15 21:04:53.015646
145	\N	INSERT	messages	265	{"table": "messages", "action": "INSERT", "new_data": {"content": "**Заявка approved** на объект 'Коттедж с бассейном'. Ответ: По коммунальным причинам перенес уменьшил кол-во дней.", "is_read": false, "created_at": "2026-03-15T21:04:53.044705", "message_id": 265, "to_user_id": 17, "from_user_id": null}}	2026-03-15 21:04:53.042128
146	\N	DELETE	messages	265	{"table": "messages", "action": "DELETE", "deleted_data": {"content": "**Заявка approved** на объект 'Коттедж с бассейном'. Ответ: По коммунальным причинам перенес уменьшил кол-во дней.", "is_read": false, "created_at": "2026-03-15T21:04:53.044705", "message_id": 265, "to_user_id": 17, "from_user_id": null}}	2026-03-15 21:07:39.24178
147	\N	DELETE	messages	248	{"table": "messages", "action": "DELETE", "deleted_data": {"content": "**Заявка approved** на объект 'Коттедж с бассейном'. ", "is_read": true, "created_at": "2026-03-14T19:35:16.768746", "message_id": 248, "to_user_id": 9, "from_user_id": null}}	2026-03-15 21:07:39.24178
148	\N	INSERT	messages	266	{"table": "messages", "action": "INSERT", "new_data": {"content": "✍️ **Арендатор подписал договор** Д-97: Феоктистов Глеб Юрьевич подписал договор на объект \\"Коттедж с бассейном\\"", "is_read": false, "created_at": "2026-03-15T21:08:19.622137", "message_id": 266, "to_user_id": 12, "from_user_id": null}}	2026-03-15 21:08:19.622137
149	\N	UPDATE	contracts	97	{"table": "contracts", "changes": {"tenant_signed": {"new": true, "old": false}, "signing_status": {"new": "pending", "old": "draft"}}, "old_data": {"end_date": "2026-09-17", "created_at": "2026-03-15T21:04:53.015646", "start_date": "2026-03-21", "contract_id": 97, "owner_signed": false, "total_amount": 1500000.00, "tenant_signed": false, "application_id": 353, "signing_status": "draft"}}	2026-03-15 21:08:19.622137
150	\N	INSERT	messages	267	{"table": "messages", "action": "INSERT", "new_data": {"content": "кк", "is_read": false, "created_at": "2026-03-15T18:09:27.436444", "message_id": 267, "to_user_id": 17, "from_user_id": 12}}	2026-03-15 21:09:27.435704
151	\N	UPDATE	messages	267	{"table": "messages", "changes": {"is_read": {"new": true, "old": false}}, "old_data": {"content": "кк", "is_read": false, "created_at": "2026-03-15T18:09:27.436444", "message_id": 267, "to_user_id": 17, "from_user_id": 12}}	2026-03-15 21:15:36.616168
152	\N	UPDATE	messages	263	{"table": "messages", "changes": {"is_read": {"new": true, "old": false}}, "old_data": {"content": "📄 **Договор создан** на объект \\"Коттедж с бассейном\\" с арендатором Феоктистов Глеб Юрьевич. Ожидается подписание.", "is_read": false, "created_at": "2026-03-15T21:04:53.015646", "message_id": 263, "to_user_id": 12, "from_user_id": null}}	2026-03-15 21:16:03.356715
153	\N	UPDATE	messages	266	{"table": "messages", "changes": {"is_read": {"new": true, "old": false}}, "old_data": {"content": "✍️ **Арендатор подписал договор** Д-97: Феоктистов Глеб Юрьевич подписал договор на объект \\"Коттедж с бассейном\\"", "is_read": false, "created_at": "2026-03-15T21:08:19.622137", "message_id": 266, "to_user_id": 12, "from_user_id": null}}	2026-03-15 21:16:05.005921
154	\N	UPDATE	messages	262	{"table": "messages", "changes": {"is_read": {"new": true, "old": false}}, "old_data": {"content": "📄 **Договор создан** на объект \\"Коттедж с бассейном\\". Ожидается подписание.", "is_read": false, "created_at": "2026-03-15T21:04:53.015646", "message_id": 262, "to_user_id": 17, "from_user_id": null}}	2026-03-15 21:16:06.184676
155	\N	UPDATE	messages	264	{"table": "messages", "changes": {"is_read": {"new": true, "old": false}}, "old_data": {"content": "✅ **Заявка одобрена** на объект \\"Коттедж с бассейном\\"", "is_read": false, "created_at": "2026-03-15T21:04:53.015646", "message_id": 264, "to_user_id": 17, "from_user_id": null}}	2026-03-15 21:16:06.184676
156	\N	INSERT	messages	268	{"table": "messages", "action": "INSERT", "new_data": {"content": "✍️ **Собственник подписал договор** Д-97: Соловьёва Юлия Сергеевна подписал договор на объект \\"Коттедж с бассейном\\"", "is_read": false, "created_at": "2026-03-15T21:17:17.719383", "message_id": 268, "to_user_id": 17, "from_user_id": null}}	2026-03-15 21:17:17.719383
157	\N	INSERT	messages	269	{"table": "messages", "action": "INSERT", "new_data": {"content": "✅ **Договор полностью подписан** Д-97 на объект \\"Коттедж с бассейном\\"", "is_read": false, "created_at": "2026-03-15T21:17:17.719383", "message_id": 269, "to_user_id": 17, "from_user_id": null}}	2026-03-15 21:17:17.719383
158	\N	INSERT	messages	270	{"table": "messages", "action": "INSERT", "new_data": {"content": "✅ **Договор полностью подписан** Д-97 на объект \\"Коттедж с бассейном\\"", "is_read": false, "created_at": "2026-03-15T21:17:17.719383", "message_id": 270, "to_user_id": 12, "from_user_id": null}}	2026-03-15 21:17:17.719383
159	\N	UPDATE	properties	149	{"table": "properties", "changes": {"status": {"new": "rented", "old": "active"}}, "old_data": {"area": 200.00, "city": "Геленджик", "price": 250000.00, "rooms": 5, "title": "Коттедж с бассейном", "status": "active", "address": "с. Кабардинка, ул. Морская, д. 7", "owner_id": 12, "created_at": "2026-03-10T20:27:37.442124", "description": "Элитный коттедж с закрытой территорией и бассейном", "property_id": 149, "interval_pay": "month", "property_type": "house"}}	2026-03-15 21:17:17.719383
160	\N	UPDATE	contracts	97	{"table": "contracts", "changes": {"owner_signed": {"new": true, "old": false}, "signing_status": {"new": "signed", "old": "pending"}}, "old_data": {"end_date": "2026-09-17", "created_at": "2026-03-15T21:04:53.015646", "start_date": "2026-03-21", "contract_id": 97, "owner_signed": false, "total_amount": 1500000.00, "tenant_signed": true, "application_id": 353, "signing_status": "pending"}}	2026-03-15 21:17:17.719383
161	\N	UPDATE	messages	268	{"table": "messages", "changes": {"is_read": {"new": true, "old": false}}, "old_data": {"content": "✍️ **Собственник подписал договор** Д-97: Соловьёва Юлия Сергеевна подписал договор на объект \\"Коттедж с бассейном\\"", "is_read": false, "created_at": "2026-03-15T21:17:17.719383", "message_id": 268, "to_user_id": 17, "from_user_id": null}}	2026-03-15 21:17:34.356202
162	\N	UPDATE	messages	269	{"table": "messages", "changes": {"is_read": {"new": true, "old": false}}, "old_data": {"content": "✅ **Договор полностью подписан** Д-97 на объект \\"Коттедж с бассейном\\"", "is_read": false, "created_at": "2026-03-15T21:17:17.719383", "message_id": 269, "to_user_id": 17, "from_user_id": null}}	2026-03-15 21:17:36.425139
163	\N	UPDATE	messages	270	{"table": "messages", "changes": {"is_read": {"new": true, "old": false}}, "old_data": {"content": "✅ **Договор полностью подписан** Д-97 на объект \\"Коттедж с бассейном\\"", "is_read": false, "created_at": "2026-03-15T21:17:17.719383", "message_id": 270, "to_user_id": 12, "from_user_id": null}}	2026-03-15 21:52:58.242355
164	\N	UPDATE	users	12	{"table": "users", "changes": {"contact_info": {"new": {"inn": "4324435667", "city": "Донецк", "phone": "+79066784781", "passport": "4621789012", "birth_date": "2007-01-02"}, "old": {"inn": "4324435667", "city": "Ликино-Дулёво", "phone": "+79066784781", "passport": "4621789012", "birth_date": "2007-01-02"}}}, "old_data": {"email": "qmett1@gmail.com", "user_id": 12, "full_name": "Соловьёва Юлия Сергеевна", "is_active": true, "user_type": "agent", "avatar_url": "/static/uploads/avatars/e5afd064062f46de89802f5ef3ca4bae.jpg", "created_at": "2026-03-10T20:02:42.602234", "contact_info": {"inn": "4324435667", "city": "Ликино-Дулёво", "phone": "+79066784781", "passport": "4621789012", "birth_date": "2007-01-02"}, "password_hash": "bdc1e3618db56b35a6c7d8c0375166fd7b11893c9bca67113b4ea963b454fb8e"}}	2026-03-15 21:59:42.174753
165	\N	UPDATE	users	12	{"table": "users", "changes": {"contact_info": {"new": {"inn": "4324435667", "city": "Ликино-Дулево  (Московская область)", "phone": "+79066784781", "passport": "4621789012", "birth_date": "2007-01-02"}, "old": {"inn": "4324435667", "city": "Донецк", "phone": "+79066784781", "passport": "4621789012", "birth_date": "2007-01-02"}}}, "old_data": {"email": "qmett1@gmail.com", "user_id": 12, "full_name": "Соловьёва Юлия Сергеевна", "is_active": true, "user_type": "agent", "avatar_url": "/static/uploads/avatars/e5afd064062f46de89802f5ef3ca4bae.jpg", "created_at": "2026-03-10T20:02:42.602234", "contact_info": {"inn": "4324435667", "city": "Донецк", "phone": "+79066784781", "passport": "4621789012", "birth_date": "2007-01-02"}, "password_hash": "bdc1e3618db56b35a6c7d8c0375166fd7b11893c9bca67113b4ea963b454fb8e"}}	2026-03-15 21:59:59.047157
166	\N	UPDATE	users	12	{"table": "users", "changes": {"contact_info": {"new": {"inn": "4324435667", "city": "Куровское  (Московская область)", "phone": "+79066784781", "passport": "4621789012", "birth_date": "2007-01-02"}, "old": {"inn": "4324435667", "city": "Ликино-Дулево  (Московская область)", "phone": "+79066784781", "passport": "4621789012", "birth_date": "2007-01-02"}}}, "old_data": {"email": "qmett1@gmail.com", "user_id": 12, "full_name": "Соловьёва Юлия Сергеевна", "is_active": true, "user_type": "agent", "avatar_url": "/static/uploads/avatars/e5afd064062f46de89802f5ef3ca4bae.jpg", "created_at": "2026-03-10T20:02:42.602234", "contact_info": {"inn": "4324435667", "city": "Ликино-Дулево  (Московская область)", "phone": "+79066784781", "passport": "4621789012", "birth_date": "2007-01-02"}, "password_hash": "bdc1e3618db56b35a6c7d8c0375166fd7b11893c9bca67113b4ea963b454fb8e"}}	2026-03-15 22:03:56.870232
167	\N	UPDATE	users	12	{"table": "users", "changes": {"contact_info": {"new": {"inn": "4324435667", "city": "Ликино-Дулево  (Московская область)", "phone": "+79066784781", "passport": "4621789012", "birth_date": "2007-01-02"}, "old": {"inn": "4324435667", "city": "Куровское  (Московская область)", "phone": "+79066784781", "passport": "4621789012", "birth_date": "2007-01-02"}}}, "old_data": {"email": "qmett1@gmail.com", "user_id": 12, "full_name": "Соловьёва Юлия Сергеевна", "is_active": true, "user_type": "agent", "avatar_url": "/static/uploads/avatars/e5afd064062f46de89802f5ef3ca4bae.jpg", "created_at": "2026-03-10T20:02:42.602234", "contact_info": {"inn": "4324435667", "city": "Куровское  (Московская область)", "phone": "+79066784781", "passport": "4621789012", "birth_date": "2007-01-02"}, "password_hash": "bdc1e3618db56b35a6c7d8c0375166fd7b11893c9bca67113b4ea963b454fb8e"}}	2026-03-15 22:04:04.034013
\.


--
-- TOC entry 5036 (class 0 OID 32868)
-- Dependencies: 228
-- Data for Name: contracts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.contracts (contract_id, application_id, start_date, end_date, total_amount, signing_status, created_at, tenant_signed, owner_signed) FROM stdin;
1	128	2026-03-01	2027-02-28	420000.00	signed	2026-02-19 15:45:00	f	f
3	131	2026-03-05	2027-03-04	384000.00	draft	2026-02-22 11:20:00	f	f
84	372	2026-02-06	2026-08-08	245000.00	signed	2026-01-25 17:03:02.726785	t	t
4	136	2026-03-15	2027-03-14	540000.00	signed	2026-02-18 09:55:00	t	t
85	375	2026-02-06	2027-01-19	456000.00	draft	2026-01-30 02:26:40.929202	t	t
86	377	2026-01-20	2026-11-16	1200000.00	signed	2026-01-12 13:43:40.048189	f	t
87	378	2026-01-21	2027-06-02	646000.00	pending	2026-01-15 08:28:16.317948	f	t
2	133	2026-03-01	2027-02-28	540000.00	signed	2026-02-23 17:10:00	t	t
5	124	2026-03-10	2027-03-10	585000.00	cancelled	2026-03-09 20:29:24.040336	f	t
24	151	2025-02-05	2026-11-01	2762932.94	signed	2025-02-01 23:40:12.895313	t	t
25	160	2025-02-22	2026-02-22	443483.32	cancelled	2025-02-16 22:54:09.852943	f	t
26	162	2025-07-22	2025-11-26	546085.97	cancelled	2025-03-30 10:48:35.126599	t	t
27	163	2025-08-09	2025-12-26	415108.42	signed	2025-04-01 05:00:19.200222	t	f
29	165	2025-08-14	2025-12-08	839838.81	cancelled	2025-03-22 16:11:57.064554	t	t
30	166	2025-07-23	2025-11-21	386527.86	signed	2025-03-29 10:43:29.735032	t	t
31	167	2025-08-11	2025-11-18	188798.38	signed	2025-03-21 00:05:34.915894	t	t
32	168	2025-07-06	2025-11-04	374014.51	cancelled	2025-03-26 04:31:39.646165	t	f
34	170	2025-08-07	2025-11-27	286421.82	signed	2025-03-27 04:16:08.444625	t	t
35	171	2025-08-18	2025-12-14	357899.80	cancelled	2025-03-26 11:21:10.00883	t	t
36	172	2025-07-23	2025-12-12	353994.56	signed	2025-04-01 00:25:57.04622	t	t
37	173	2025-07-05	2025-11-11	972048.24	signed	2025-03-29 07:28:03.451644	t	t
38	174	2025-07-28	2025-10-26	245611.42	signed	2025-03-17 12:18:04.122229	t	t
39	175	2025-07-20	2025-11-07	474197.57	cancelled	2025-03-22 02:33:11.959758	t	t
40	176	2025-08-24	2025-12-02	272399.61	signed	2025-03-20 13:57:34.995857	f	t
41	178	2025-06-13	2026-06-13	464520.29	signed	2025-05-26 13:37:01.250667	t	t
42	189	2025-06-16	2026-06-16	452595.08	cancelled	2025-05-21 07:50:47.679911	t	t
43	192	2025-06-23	2026-06-23	931322.95	signed	2025-05-23 06:58:21.067627	t	t
44	197	2025-07-26	2025-10-05	445015.97	signed	2025-07-17 01:41:12.490025	t	t
45	198	2025-08-21	2025-12-07	800909.75	signed	2025-07-14 19:38:44.902965	t	t
46	199	2025-08-16	2025-11-29	443455.08	cancelled	2025-07-08 15:05:47.22388	t	t
47	200	2025-08-06	2025-11-02	257612.79	signed	2025-07-17 16:10:29.527078	t	t
48	201	2025-08-13	2025-11-08	715474.30	cancelled	2025-07-02 09:00:14.216915	t	t
50	265	2026-03-20	2027-03-20	975000.00	draft	2026-02-15 15:04:38.596171	t	t
51	271	2026-03-22	2027-03-22	1560000.00	signed	2026-03-06 03:45:29.267071	t	t
53	277	2026-03-22	2027-03-22	494000.00	signed	2026-03-06 13:52:38.085582	t	t
52	273	2026-03-16	2027-03-16	780000.00	signed	2026-03-11 11:07:58.448718	t	t
49	254	2026-02-25	2027-02-25	780000.00	signed	2026-01-20 08:45:21.9864	t	t
54	283	2025-04-03	2026-05-14	232879.45	signed	2025-03-23 08:10:02.386912	t	t
55	284	2025-03-25	2026-06-03	265390.20	signed	2025-03-14 12:28:35.413734	t	t
56	285	2025-03-30	2026-04-07	328476.60	cancelled	2025-03-25 05:18:30.757125	t	t
57	287	2025-03-28	2026-02-01	287639.38	cancelled	2025-03-16 09:21:31.229018	t	t
58	288	2025-04-03	2026-08-09	1984862.23	signed	2025-03-28 00:57:39.284154	t	t
59	289	2025-04-06	2026-07-23	1392686.44	signed	2025-03-27 22:46:20.154737	t	t
60	293	2025-04-02	2026-06-13	1270064.44	cancelled	2025-03-23 00:25:12.390833	t	t
61	297	2025-04-21	2025-12-17	125879.62	cancelled	2025-04-11 05:15:03.586421	t	t
62	298	2025-05-03	2026-06-13	952477.80	signed	2025-04-27 08:37:08.149738	t	t
63	299	2025-04-29	2026-07-23	378314.67	signed	2025-04-22 16:58:27.10086	t	t
64	300	2025-04-20	2026-04-06	185392.58	signed	2025-04-14 03:55:58.156998	t	t
65	304	2025-05-03	2026-02-25	1088548.19	signed	2025-04-25 19:30:20.486357	t	t
66	305	2025-05-17	2026-03-27	859174.18	signed	2025-05-03 05:51:58.816804	t	t
67	309	2025-05-21	2026-10-21	2839715.91	signed	2025-05-12 20:51:17.782072	t	t
68	310	2025-05-19	2026-10-04	536291.33	signed	2025-05-10 18:27:25.587575	t	t
69	311	2025-06-09	2026-03-05	886219.18	signed	2025-06-02 00:02:18.881389	t	t
70	314	2025-06-30	2026-05-10	309631.30	signed	2025-06-17 23:22:08.991238	t	t
71	316	2025-06-25	2026-03-20	1439749.22	cancelled	2025-06-14 22:32:46.11868	t	t
72	317	2025-06-16	2026-04-06	230250.65	signed	2025-06-09 11:46:28.49343	t	t
73	318	2025-07-01	2026-11-22	2470820.95	cancelled	2025-06-22 01:13:29.183914	t	t
74	321	2025-07-21	2026-07-17	234286.63	signed	2025-07-09 17:50:57.638241	t	t
75	325	2025-07-27	2026-06-06	169366.34	signed	2025-07-17 04:55:39.590167	t	t
76	328	2025-07-29	2026-09-18	604865.36	cancelled	2025-07-18 21:52:41.427138	t	t
77	332	2025-08-24	2026-09-27	1386541.26	signed	2025-08-14 11:27:44.289166	t	t
78	333	2025-08-29	2026-03-16	201284.24	signed	2025-08-17 14:44:31.000386	t	t
79	336	2025-08-24	2026-03-28	167561.09	cancelled	2025-08-12 13:09:31.580341	t	t
80	337	2025-09-09	2026-12-20	355018.33	signed	2025-09-02 19:19:24.158908	t	t
81	338	2025-10-05	2026-08-04	272559.93	cancelled	2025-09-26 01:38:44.345476	t	t
83	341	2025-10-02	2026-05-01	975054.75	cancelled	2025-09-23 21:37:07.15689	t	t
88	379	2026-01-28	2027-04-25	2480000.00	signed	2026-01-24 03:13:19.246402	t	t
89	381	2026-03-01	2027-07-21	4250000.00	signed	2026-02-18 22:03:53.761163	t	f
90	383	2026-03-07	2027-08-13	1350000.00	draft	2026-02-28 09:39:48.928579	f	t
91	386	2026-02-26	2027-03-10	1170000.00	draft	2026-02-17 04:22:13.082841	f	t
93	390	2026-03-24	2027-06-10	570000.00	signed	2026-03-18 07:42:33.854232	t	f
94	392	2026-03-18	2026-10-15	2000000.00	draft	2026-03-14 03:33:32.932517	t	t
82	339	2025-09-18	2026-05-18	408065.80	signed	2025-09-05 00:19:01.248952	t	t
28	\N	2025-07-29	2025-11-13	344030.52	signed	2025-03-29 06:05:50.041976	t	t
33	\N	2025-07-22	2025-11-26	435800.25	signed	2025-03-19 09:07:32.453203	t	t
92	388	2026-03-18	2027-06-16	208000.00	pending	2026-03-14 00:03:50.015217	t	f
96	141	2026-03-19	2027-03-19	845000.00	draft	2026-03-14 20:27:01.682142	f	f
95	395	2026-05-09	2026-08-07	750000.00	cancelled	2026-03-14 19:35:16.672442	f	t
97	353	2026-03-21	2026-09-17	1500000.00	signed	2026-03-15 21:04:53.015646	t	t
\.


--
-- TOC entry 5038 (class 0 OID 32907)
-- Dependencies: 230
-- Data for Name: messages; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.messages (message_id, from_user_id, to_user_id, content, is_read, created_at) FROM stdin;
4	7	2	Добрый день! Очень понравилась студия	t	2026-02-18 13:15:00
5	2	7	Здравствуйте! Рада, что понравилось. Когда удобно посмотреть?	t	2026-02-18 14:30:00
6	7	2	Могу завтра после 18:00	t	2026-02-18 15:45:00
7	2	7	Договорились, жду в 18:30	t	2026-02-18 16:20:00
9	9	2	Добрый вечер! Интересует офис в Ликино-Дулёво	t	2026-02-22 16:10:00
10	2	9	Здравствуйте! Да, офис свободен. Можем показать завтра	t	2026-02-22 17:25:00
11	9	2	Отлично, во сколько?	t	2026-02-22 18:00:00
8	9	2	Здравствуйте! Квартира в новостройке ещё свободна?	t	2026-02-23 18:35:00
12	2	9	В 19:00 вас устроит?	t	2026-02-22 18:30:00
13	2	9	ок	t	2026-02-27 18:41:03.516937
14	9	2	во сколько могу я прийти?	t	2026-02-27 18:50:34.431176
15	2	9	приходите в 10:30 завтра	t	2026-02-27 19:02:00.081636
16	9	2	ммм	t	2026-02-27 19:03:12.906357
17	2	9	Здравствуйте, я вас очень долго жду когда сможем встретиться?	t	2026-03-06 12:09:36.26616
19	2	4	Здравствуйте, свободно ли место?	t	2026-03-08 20:03:33.140989
18	2	9	Hello	t	2026-03-08 18:41:47.253071
21	\N	6	**Заявка rejected** на объект 'Уютная квартира в центре'. Ответ: Извините но уже поздно	f	2026-03-09 19:58:31.105021
22	\N	6	**Заявка rejected** на объект 'Таунхаус'. 	f	2026-03-09 20:06:14.109282
23	\N	6	**Заявка approved** на объект 'Уютная квартира в центре'. Ответ: Добрый вечер извините что я вас задержал! Поэтому завтра заселитесь	f	2026-03-09 20:29:24.074459
24	\N	6	**Договор отменён** на объект 'Уютная квартира в центре'. Договор №5	f	2026-03-10 16:05:31.120171
27	11	3	Здравствуйте! Когда можно подъехать на просмотр?	t	2025-01-30 07:42:09.64018
28	3	11	Ваша заявка одобрена! Можем приступать к оформлению договора.	t	2025-01-29 08:06:27.67736
29	7	2	Здравствуйте! Когда можно подъехать на просмотр?	f	2025-02-24 20:10:07.744105
30	2	7	Договорились, напишите за час до прихода	t	2025-02-26 11:08:59.503637
31	2	7	Ваша заявка одобрена! Можем приступать к оформлению договора.	t	2025-02-21 22:52:18.16458
32	6	5	Какие документы нужны для заключения договора?	f	2025-04-05 11:28:00.234056
33	5	6	Договорились, напишите за час до прихода	t	2025-04-05 17:05:35.841539
34	15	4	Какие документы нужны для заключения договора?	f	2025-03-27 18:58:43.767642
35	4	15	Договорились, напишите за час до прихода	t	2025-03-27 20:57:15.08007
36	4	15	Ваша заявка одобрена! Можем приступать к оформлению договора.	t	2025-03-23 10:24:26.265852
37	13	5	Здравствуйте! Когда можно подъехать на просмотр?	t	2025-03-24 14:52:09.492261
38	5	13	Договорились, напишите за час до прихода	t	2025-03-25 19:08:53.837603
39	5	13	Ваша заявка одобрена! Можем приступать к оформлению договора.	t	2025-03-21 00:45:00.908103
40	7	5	Здравствуйте! Когда можно подъехать на просмотр?	t	2025-03-24 08:09:43.550061
41	5	7	Договорились, напишите за час до прихода	t	2025-03-25 18:30:23.769502
42	13	4	Какие документы нужны для заключения договора?	t	2025-03-07 10:05:37.749957
43	4	13	Все документы подготовлю к встрече	t	2025-03-07 20:06:13.889839
45	12	7	Договорились, напишите за час до прихода	t	2025-03-22 23:14:06.401275
46	18	4	Какие документы нужны для заключения договора?	t	2025-04-08 18:26:10.953043
47	4	18	Все документы подготовлю к встрече	f	2025-04-09 06:03:13.922685
48	4	18	Ваша заявка одобрена! Можем приступать к оформлению договора.	f	2025-04-08 13:06:07.696714
49	13	5	Могу ли я внести предоплату?	t	2025-03-06 17:28:25.069956
50	5	13	Ваша заявка одобрена! Можем приступать к оформлению договора.	t	2025-03-05 15:19:07.725225
51	17	12	Какие документы нужны для заключения договора?	t	2025-03-14 07:24:00.115584
52	12	17	Да, жду вас завтра в 15:00	t	2025-03-16 03:35:41.916233
53	12	17	Ваша заявка одобрена! Можем приступать к оформлению договора.	t	2025-03-13 07:21:45.399209
54	15	18	Могу ли я внести предоплату?	t	2025-03-12 03:25:54.168011
55	18	15	Договорились, напишите за час до прихода	t	2025-03-13 08:04:13.065362
44	7	12	Здравствуйте! Когда можно подъехать на просмотр?	t	2025-03-22 00:20:46.988558
20	9	3	ок	t	2026-03-09 06:26:26.333851
56	6	12	Могу ли я внести предоплату?	t	2025-03-24 10:09:06.176309
57	12	6	Договорились, напишите за час до прихода	t	2025-03-24 12:23:58.492591
58	7	5	Какие документы нужны для заключения договора?	t	2025-04-06 17:52:21.676089
59	5	7	Договорились, напишите за час до прихода	t	2025-04-08 12:38:32.814808
60	19	4	Спасибо за показ квартиры, мне очень понравилось	t	2025-04-18 17:48:45.339241
61	4	19	Все документы подготовлю к встрече	f	2025-04-19 22:14:50.1971
62	7	18	Здравствуйте! Когда можно подъехать на просмотр?	f	2025-03-31 11:33:44.189573
63	17	4	Могу ли я внести предоплату?	t	2025-04-01 12:04:24.287368
64	4	17	Все документы подготовлю к встрече	t	2025-04-02 22:39:46.854375
65	13	2	Здравствуйте! Когда можно подъехать на просмотр?	f	2025-05-16 15:13:42.876698
66	2	13	Ваша заявка одобрена! Можем приступать к оформлению договора.	t	2025-05-16 14:51:31.225115
67	15	2	Какие документы нужны для заключения договора?	f	2025-05-19 03:27:12.511211
68	2	15	Договорились, напишите за час до прихода	t	2025-05-20 13:40:21.68064
69	2	15	Ваша заявка одобрена! Можем приступать к оформлению договора.	f	2025-05-17 04:03:51.881306
70	19	3	Спасибо за показ квартиры, мне очень понравилось	t	2025-05-06 02:47:02.443722
71	3	19	Договорились, напишите за час до прихода	t	2025-05-07 21:09:17.943137
72	19	5	Здравствуйте! Когда можно подъехать на просмотр?	f	2025-06-25 15:21:28.095914
73	5	19	Все документы подготовлю к встрече	t	2025-06-26 15:21:24.02282
74	5	19	Ваша заявка одобрена! Можем приступать к оформлению договора.	t	2025-06-22 16:15:51.773734
75	17	5	Могу ли я внести предоплату?	t	2025-07-14 03:25:18.884089
76	5	17	Ваша заявка одобрена! Можем приступать к оформлению договора.	t	2025-07-13 02:34:49.752965
77	6	5	Здравствуйте! Когда можно подъехать на просмотр?	t	2025-06-29 20:40:46.120177
78	5	6	Договорились, напишите за час до прихода	t	2025-07-01 19:20:46.852254
79	5	6	Ваша заявка одобрена! Можем приступать к оформлению договора.	t	2025-06-27 01:54:30.6901
80	17	4	Здравствуйте! Когда можно подъехать на просмотр?	t	2025-06-20 05:13:03.908957
81	4	17	Все документы подготовлю к встрече	t	2025-06-20 12:29:24.306982
82	4	17	Ваша заявка одобрена! Можем приступать к оформлению договора.	t	2025-06-18 00:48:01.68645
83	15	12	Спасибо за показ квартиры, мне очень понравилось	t	2025-07-01 21:36:19.131005
84	12	15	Договорились, напишите за час до прихода	t	2025-07-03 19:05:45.056919
85	12	15	Ваша заявка одобрена! Можем приступать к оформлению договора.	t	2025-06-29 19:18:07.383546
86	11	4	Спасибо за показ квартиры, мне очень понравилось	f	2025-07-06 15:31:57.400865
87	4	11	Все документы подготовлю к встрече	t	2025-07-08 08:33:27.449393
88	16	4	Какие документы нужны для заключения договора?	f	2025-07-04 00:20:04.331528
89	4	16	Ваша заявка одобрена! Можем приступать к оформлению договора.	t	2025-07-01 12:44:35.61737
90	15	18	Какие документы нужны для заключения договора?	f	2025-06-21 23:33:57.70402
91	18	5	Могу ли я внести предоплату?	f	2025-07-05 13:24:13.881697
92	5	18	Ваша заявка одобрена! Можем приступать к оформлению договора.	t	2025-07-02 14:37:53.092873
93	19	4	Здравствуйте! Когда можно подъехать на просмотр?	t	2025-07-13 10:13:25.422937
94	4	19	Да, жду вас завтра в 15:00	t	2025-07-15 08:48:44.191609
95	11	5	Могу ли я внести предоплату?	t	2025-06-17 04:19:51.073423
96	5	11	Все документы подготовлю к встрече	t	2025-06-17 16:23:16.996334
97	5	11	Ваша заявка одобрена! Можем приступать к оформлению договора.	t	2025-06-18 17:48:34.106485
98	16	12	Какие документы нужны для заключения договора?	t	2025-06-27 22:57:08.196583
99	12	16	Да, жду вас завтра в 15:00	t	2025-06-29 03:48:03.373132
100	6	4	Здравствуйте! Когда можно подъехать на просмотр?	t	2025-06-20 02:44:57.851905
101	4	6	Да, жду вас завтра в 15:00	t	2025-06-21 17:46:08.670229
102	4	6	Ваша заявка одобрена! Можем приступать к оформлению договора.	t	2025-06-18 01:33:25.794262
104	12	16	Договорились, напишите за час до прихода	t	2025-07-07 11:31:18.851645
105	12	16	Ваша заявка одобрена! Можем приступать к оформлению договора.	t	2025-07-05 06:22:25.89875
106	11	5	Могу ли я внести предоплату?	t	2025-07-13 08:22:42.946882
107	5	11	Все документы подготовлю к встрече	t	2025-07-15 00:49:01.354412
108	16	12	Спасибо за показ квартиры, мне очень понравилось	t	2025-06-22 05:51:31.410386
109	12	16	Все документы подготовлю к встрече	t	2025-06-22 06:21:40.045354
110	12	16	Ваша заявка одобрена! Можем приступать к оформлению договора.	t	2025-06-21 15:16:26.896877
111	15	18	Здравствуйте! Когда можно подъехать на просмотр?	t	2025-07-11 06:42:55.217941
112	18	15	Да, жду вас завтра в 15:00	t	2025-07-11 09:49:12.088047
113	18	15	Ваша заявка одобрена! Можем приступать к оформлению договора.	t	2025-07-11 08:39:07.357911
115	12	7	Договорились, напишите за час до прихода	f	2025-06-16 14:37:14.951329
116	12	7	Ваша заявка одобрена! Можем приступать к оформлению договора.	t	2025-06-17 05:40:15.550206
114	7	12	Могу ли я внести предоплату?	t	2025-06-16 07:29:20.079121
117	15	18	Здравствуйте! Когда можно подъехать на просмотр?	f	2025-07-17 00:01:20.597764
118	18	15	Договорились, напишите за час до прихода	t	2025-07-18 23:05:22.228592
119	18	15	Ваша заявка одобрена! Можем приступать к оформлению договора.	t	2025-07-14 18:42:02.231699
120	17	12	Спасибо за показ квартиры, мне очень понравилось	t	2025-06-30 15:36:33.39929
121	12	17	Да, жду вас завтра в 15:00	t	2025-07-01 23:31:55.016979
122	9	2	Хочу уточнить детали перед подписанием	f	2026-03-10 03:05:58.440139
123	17	4	Добрый день! Интересует вопрос по аренде	t	2026-01-30 22:56:32.45819
124	6	5	Хочу уточнить детали перед подписанием	f	2026-02-05 14:59:53.370891
126	7	3	Добрый день! Интересует вопрос по аренде	t	2026-03-10 14:13:06.853469
128	7	5	Когда можно заехать?	f	2026-03-01 07:34:01.268135
129	11	3	Как происходит оплата коммунальных услуг?	t	2025-02-04 21:08:16.404291
130	7	2	Когда нужно будет внести первый платеж?	t	2025-02-18 07:17:31.656187
131	6	5	Нужно ли подписывать дополнительные документы?	t	2025-03-31 04:51:00.142306
132	15	4	Когда нужно будет внести первый платеж?	t	2025-04-02 01:28:00.742329
133	4	15	Поздравляю с подписанием договора! Рад сотрудничеству!	t	2025-04-01 09:34:19.031923
134	13	5	Спасибо за сотрудничество!	f	2025-03-31 10:37:33.553167
135	7	5	Когда нужно будет внести первый платеж?	t	2025-03-22 22:41:56.439026
136	13	4	Нужно ли подписывать дополнительные документы?	f	2025-04-01 03:09:42.114452
137	7	12	Когда нужно будет внести первый платеж?	t	2025-03-22 07:31:01.202725
138	18	4	Спасибо за сотрудничество!	f	2025-03-29 06:18:06.156585
139	13	5	Спасибо за сотрудничество!	t	2025-03-20 19:29:58.227534
140	5	13	Поздравляю с подписанием договора! Рад сотрудничеству!	f	2025-03-19 19:56:31.127936
142	15	18	Спасибо за сотрудничество!	f	2025-03-27 22:13:13.726915
143	6	12	Когда нужно будет внести первый платеж?	t	2025-04-01 18:11:42.904775
144	7	5	Нужно ли подписывать дополнительные документы?	t	2025-03-30 09:04:11.494879
145	19	4	Спасибо за сотрудничество!	t	2025-03-19 06:04:04.196141
146	4	19	Поздравляю с подписанием договора! Рад сотрудничеству!	t	2025-03-18 19:41:32.449283
147	7	18	Как происходит оплата коммунальных услуг?	t	2025-03-22 12:59:28.7776
148	17	4	Когда нужно будет внести первый платеж?	t	2025-03-24 08:15:56.445722
149	13	2	Как происходит оплата коммунальных услуг?	t	2025-05-29 17:43:48.157499
150	2	13	Поздравляю с подписанием договора! Рад сотрудничеству!	t	2025-05-27 22:41:34.090461
151	15	2	Спасибо за сотрудничество!	t	2025-05-23 20:33:11.192389
152	19	3	Как происходит оплата коммунальных услуг?	f	2025-05-26 16:49:41.363924
153	19	5	Нужно ли подписывать дополнительные документы?	t	2025-07-20 09:51:30.122962
154	17	5	Спасибо за сотрудничество!	t	2025-07-17 18:21:06.733294
155	6	5	Как происходит оплата коммунальных услуг?	t	2025-07-11 07:39:29.271323
156	17	4	Спасибо за сотрудничество!	t	2025-07-19 08:41:33.375286
157	15	12	Как происходит оплата коммунальных услуг?	t	2025-07-05 01:59:44.419999
158	17	4	Как происходит оплата коммунальных услуг?	t	2026-01-22 03:13:42.630853
159	6	3	Спасибо за сотрудничество!	t	2026-02-17 05:09:10.744682
160	7	3	Когда нужно будет внести первый платеж?	t	2026-03-06 12:20:04.645864
161	7	5	Как происходит оплата коммунальных услуг?	t	2026-03-07 11:14:51.495088
164	16	11	Слышал, цены на аренду выросли	f	2025-04-20 10:14:58.447142
165	6	19	Привет! Как дела?	f	2025-07-11 12:32:40.380498
166	2	20	Посоветуй хорошего агента по недвижимости	t	2025-03-29 15:08:34.521862
168	18	15	Есть вопросы по документам, можешь помочь?	f	2026-02-05 12:03:48.642653
169	18	5	Сколько сейчас стоит аренда в центре?	f	2025-07-15 17:28:08.841269
170	18	2	Посоветуй хорошего агента по недвижимости	f	2026-03-10 07:07:42.048366
171	9	4	Посоветуй хорошего агента по недвижимости	t	2025-02-28 14:22:27.853024
173	16	15	Слышал, цены на аренду выросли	f	2025-09-01 18:12:24.409243
174	5	2	Есть вопросы по документам, можешь помочь?	f	2025-12-05 11:13:03.491227
175	17	13	Слышал, цены на аренду выросли	t	2025-06-15 14:12:12.464107
176	20	19	Привет! Как дела?	t	2025-02-28 07:01:47.481401
177	15	1	Есть вопросы по документам, можешь помочь?	t	2025-09-28 07:17:56.562257
178	7	4	Есть вопросы по документам, можешь помочь?	f	2025-01-14 18:30:59.259478
180	20	16	Посоветуй хорошего агента по недвижимости	t	2025-05-29 18:16:29.400196
181	7	6	Видел новый объект в нашем районе?	t	2025-08-22 04:43:12.148301
182	20	2	Есть вопросы по документам, можешь помочь?	f	2025-04-01 18:47:57.557026
141	17	12	Нужно ли подписывать дополнительные документы?	t	2025-03-30 04:14:35.767876
163	7	12	Сколько сейчас стоит аренда в центре?	t	2025-11-24 01:38:25.802252
172	15	3	Привет! Как дела?	t	2025-06-27 08:15:45.859473
125	6	3	Хочу уточнить детали перед подписанием	t	2026-02-06 20:07:05.096526
179	7	1	Видел новый объект в нашем районе?	t	2025-04-30 15:59:41.65094
127	6	4	Хочу уточнить детали перед подписанием	t	2026-03-02 14:52:24.819384
183	15	11	Видел новый объект в нашем районе?	t	2025-09-19 22:52:40.965106
184	9	6	Есть вопросы по документам, можешь помочь?	f	2025-10-30 20:21:20.489922
185	3	7	Привет! Как дела?	f	2026-01-04 18:39:26.638369
188	19	6	Посоветуй хорошего агента по недвижимости	f	2025-03-23 20:09:46.204338
189	16	14	Привет! Как дела?	t	2026-01-03 01:12:44.76113
190	4	7	Сколько сейчас стоит аренда в центре?	f	2025-05-29 16:21:45.855766
191	3	5	Видел новый объект в нашем районе?	f	2025-12-06 05:57:33.857582
192	13	2	Слышал, цены на аренду выросли	t	2025-12-29 01:04:30.051856
194	14	15	Привет! Как дела?	t	2025-08-22 09:43:43.560036
195	2	14	Видел новый объект в нашем районе?	t	2025-04-09 08:46:11.76171
196	11	5	Есть вопросы по документам, можешь помочь?	t	2025-06-04 16:27:29.062731
197	4	19	Привет! Как дела?	f	2025-06-25 05:54:33.11973
198	5	7	Видел новый объект в нашем районе?	t	2025-08-25 16:11:05.552571
199	12	19	Посоветуй хорошего агента по недвижимости	t	2025-05-31 10:38:41.807928
201	3	15	Сколько сейчас стоит аренда в центре?	t	2026-01-28 02:29:52.133575
202	18	4	Сколько сейчас стоит аренда в центре?	f	2025-03-18 01:05:39.325815
203	11	2	Есть вопросы по документам, можешь помочь?	t	2025-04-14 11:05:00.486719
204	13	7	Посоветуй хорошего агента по недвижимости	t	2025-02-05 16:32:16.139229
205	16	15	Привет! Как дела?	t	2025-12-03 17:36:30.046541
206	1	18	Слышал, цены на аренду выросли	t	2026-02-27 15:39:04.484141
207	19	13	Сколько сейчас стоит аренда в центре?	t	2026-02-05 05:26:39.474428
208	17	9	Видел новый объект в нашем районе?	t	2025-11-13 10:54:01.248353
209	18	1	Слышал, цены на аренду выросли	t	2025-12-10 05:05:25.865121
210	3	11	Видел новый объект в нашем районе?	f	2025-11-21 09:44:50.482513
211	16	9	Слышал, цены на аренду выросли	t	2025-06-23 16:36:09.899381
212	\N	16	**Системное сообщение** Скоро заканчивается срок аренды	f	2025-09-08 22:25:33.812668
213	\N	13	**Напоминание** о предстоящем платеже по договору №1029	f	2025-10-23 13:31:22.223982
214	\N	18	**Напоминание** о предстоящем платеже по договору №1038	t	2025-03-22 13:10:30.919216
215	\N	7	**Уведомление** Ваша заявка №1002 одобрена	t	2025-07-19 11:47:52.67127
216	\N	13	**Системное сообщение** Скоро заканчивается срок аренды	f	2025-11-30 13:20:47.752914
217	\N	18	**Внимание** Обновите данные в профиле	t	2025-08-15 12:33:52.67706
218	\N	6	**Системное сообщение** Скоро заканчивается срок аренды	f	2026-01-14 20:49:06.858851
219	\N	13	**Уведомление** Ваша заявка №1062 одобрена	t	2025-09-13 06:25:03.425665
221	\N	16	**Системное сообщение** Скоро заканчивается срок аренды	t	2025-06-23 13:13:06.010214
222	\N	19	**Напоминание** о предстоящем платеже по договору №1098	f	2025-09-11 18:15:19.33286
223	\N	11	**Напоминание** о предстоящем платеже по договору №1035	t	2026-01-10 21:09:43.627285
225	\N	15	**Внимание** Обновите данные в профиле	t	2025-12-14 19:42:02.287013
226	\N	16	**Внимание** Обновите данные в профиле	t	2025-04-07 11:50:23.954436
227	\N	13	**Внимание** Обновите данные в профиле	f	2026-02-24 00:03:58.655305
228	\N	15	**Внимание** Обновите данные в профиле	f	2025-05-16 07:33:19.985049
229	\N	15	**Системное сообщение** Скоро заканчивается срок аренды	t	2026-01-31 09:14:06.944503
230	\N	18	**Системное сообщение** Скоро заканчивается срок аренды	f	2025-02-24 00:14:48.988684
232	\N	9	**Внимание** Обновите данные в профиле	t	2025-12-28 06:37:48.760187
233	\N	19	**Внимание** Обновите данные в профиле	f	2025-03-28 09:07:36.974217
234	\N	19	**Напоминание** о предстоящем платеже по договору №1077	t	2025-07-27 15:49:17.064854
236	\N	19	**Системное сообщение** Скоро заканчивается срок аренды	f	2025-04-28 23:14:41.309387
238	\N	7	**Внимание** Обновите данные в профиле	t	2025-08-21 06:19:39.612303
239	\N	16	**Уведомление** Ваша заявка №1043 одобрена	f	2025-12-04 16:11:52.699589
240	\N	11	**Напоминание** о предстоящем платеже по договору №1016	f	2026-02-24 07:15:24.308022
241	\N	13	**Уведомление** Ваша заявка №1082 одобрена	t	2025-03-03 21:03:29.684452
167	9	14	Посоветуй хорошего агента по недвижимости	t	2025-04-09 00:40:28.899146
186	18	14	Привет! Как дела?	t	2025-07-17 21:28:20.020758
103	16	12	Здравствуйте! Когда можно подъехать на просмотр?	t	2025-07-06 20:31:52.025269
193	3	1	Слышал, цены на аренду выросли	t	2026-01-18 16:05:20.898848
200	5	1	Слышал, цены на аренду выросли	t	2025-08-25 15:05:25.10128
242	\N	2	📋 **Новая заявка** от Тестовый пользователь на объект "Уютная квартира в центре"	f	2026-03-14 19:01:53.808364
187	3	9	Посоветуй хорошего агента по недвижимости	t	2025-06-03 04:52:27.321125
237	\N	9	**Системное сообщение** Скоро заканчивается срок аренды	t	2026-01-24 06:35:46.48803
231	\N	9	**Внимание** Обновите данные в профиле	t	2026-02-25 01:44:37.017336
224	\N	9	**Внимание** Обновите данные в профиле	t	2025-04-08 20:05:58.992198
243	\N	12	📋 **Новая заявка** от Боев Владислав Максимович на объект "Коттедж с бассейном"	t	2026-03-14 19:32:58.068672
220	\N	17	**Системное сообщение** Скоро заканчивается срок аренды	t	2025-11-03 13:37:21.858491
235	\N	17	**Уведомление** Ваша заявка №1069 одобрена	t	2025-01-05 19:11:16.268937
244	\N	5	✍️ **Арендатор подписал договор**: Боев Владислав Максимович подписал договор на объект "Квартира"	f	2026-03-14 19:34:43.385256
246	\N	9	✅ **Заявка одобрена** на объект "Коттедж с бассейном"	t	2026-03-14 19:35:16.672442
249	\N	9	✍️ **Собственник подписал договор**: Соловьёва Юлия Сергеевна подписал договор на объект "Коттедж с бассейном"	t	2026-03-14 20:00:50.450466
255	\N	9	**Договор отменён** на объект 'Коттедж с бассейном'. Договор №95	t	2026-03-14 20:34:30.972685
253	\N	9	**Договор отменён** на объект "Коттедж с бассейном"	t	2026-03-14 20:34:30.943048
251	\N	9	✅ **Заявка одобрена** на объект "Таунхаус"	t	2026-03-14 20:27:01.682142
254	\N	12	**Договор отменён** на объект "Коттедж с бассейном"	t	2026-03-14 20:34:30.943048
256	\N	11	❌ **Заявка отклонена** на объект "Коттедж с бассейном"	f	2026-03-15 16:14:09.400207
257	\N	11	**Заявка rejected** на объект 'Коттедж с бассейном'. Ответ: Извините, уже поздно! Счастливого вам!	f	2026-03-15 16:14:09.492351
258	\N	11	❌ **Заявка отклонена** на объект "Коммерческое помещение"	f	2026-03-15 16:18:42.242342
259	\N	11	**Заявка rejected** на объект 'Коммерческое помещение'. Ответ: Уже поздно, извините!	f	2026-03-15 16:18:42.253063
260	9	3	ааа	f	2026-03-15 15:17:08.888541
261	1	4	оло	t	2026-03-15 17:46:44.202952
267	12	17	кк	t	2026-03-15 18:09:27.436444
263	\N	12	📄 **Договор создан** на объект "Коттедж с бассейном" с арендатором Феоктистов Глеб Юрьевич. Ожидается подписание.	t	2026-03-15 21:04:53.015646
266	\N	12	✍️ **Арендатор подписал договор** Д-97: Феоктистов Глеб Юрьевич подписал договор на объект "Коттедж с бассейном"	t	2026-03-15 21:08:19.622137
262	\N	17	📄 **Договор создан** на объект "Коттедж с бассейном". Ожидается подписание.	t	2026-03-15 21:04:53.015646
264	\N	17	✅ **Заявка одобрена** на объект "Коттедж с бассейном"	t	2026-03-15 21:04:53.015646
268	\N	17	✍️ **Собственник подписал договор** Д-97: Соловьёва Юлия Сергеевна подписал договор на объект "Коттедж с бассейном"	t	2026-03-15 21:17:17.719383
269	\N	17	✅ **Договор полностью подписан** Д-97 на объект "Коттедж с бассейном"	t	2026-03-15 21:17:17.719383
270	\N	12	✅ **Договор полностью подписан** Д-97 на объект "Коттедж с бассейном"	t	2026-03-15 21:17:17.719383
\.


--
-- TOC entry 5030 (class 0 OID 32789)
-- Dependencies: 222
-- Data for Name: properties; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.properties (property_id, owner_id, title, description, address, city, property_type, area, rooms, price, interval_pay, status, created_at) FROM stdin;
6	5	Квартира у метро	Уютная квартира в 5 минутах от метро, хороший ремонт, есть мебель	ул. Гагарина, д. 7	Екатеринбург	apartment	55.00	2	38000.00	month	active	2026-02-13 21:58:34.420669
5	4	Коммерческое помещение	Помещение свободного назначения на первом этаже жилого дома	пр. Мира, д. 32	Новосибирск	house	85.00	2	60000.00	month	active	2026-02-13 21:58:34.420669
2	2	Студия в новостройке	Современная студия с дизайнерским ремонтом, есть всё для комфортного проживания	ул. Ленина, д. 15	Москва	apartment	32.00	1	35000.00	month	rented	2026-02-13 21:58:34.38867
3	3	Загородный дом у озера	Двухэтажный дом с участком, камин, сауна, отличное место для отдыха	пос. Репино, ул. Лесная, д. 5	Ленинградская область	house	150.00	4	120000.00	month	active	2026-02-13 21:58:34.41967
4	3	Квартира на Невском	Квартира в историческом центре, высокие потолки, лепнина, паркет	Невский пр., д. 25, кв. 12	Санкт-Петербург	apartment	95.00	3	75000.00	week	active	2026-02-13 21:58:34.41967
1	2	Уютная квартира в центре	Тест аудита	ул. Тверская, д. 10, кв. 45	Москва	apartment	65.50	2	45000.00	month	rented	2026-02-13 21:58:34.38867
137	2	Коммерческое помещение	fgr	rdf	Орехово-Зуево	house	22.00	3	2222.00	month	active	2026-03-09 08:01:27.051473
146	12	Апартаменты у моря	Студия в первой линии от моря, отличный вариант для отдыха	ул. Курортный проспект, д. 110	Сочи	apartment	35.00	1	155000.00	month	active	2026-03-10 20:27:37.442124
133	4	Дом с участком	Коттедж 200м2 с участком 15 соток	ул. Полевая, д. 10	д. Давыдово	house	200.00	5	85000.00	month	active	2026-02-24 12:00:00
130	4	Офисное помещение	Офис в бизнес-центре	ул. Комсомольская, д. 1А	Ликино-Дулёво	commercial	66.00	2	45000.00	month	active	2026-02-20 09:00:00
128	4	Квартира в новостройке	ЖК "Северное сияние", сдан в 2025	ул. Строителей, д. 3, кв. 78	Москва	apartment	48.00	2	42000.00	month	active	2026-02-15 11:40:00
131	3	Квартира в центре	2-комнатная квартира с видом на парк	ул. Советская, д. 82, кв. 23	Куровское	apartment	52.00	2	32000.00	month	active	2026-02-22 14:15:00
132	3	Апартаменты в центре	Студия с евроремонтом	ул. Кирова, д. 5	Орехово-Зуево	apartment	34.00	1	25000.00	month	active	2026-02-23 10:00:00
138	4	Апартаменты с видом на море	Просторные апартаменты в центре Ялты, 5 минут до набережной, евроремонт, вся техника	ул. Набережная, д. 15, кв. 8	Ялта	apartment	75.50	2	85000.00	month	active	2026-03-10 20:27:37.442124
139	5	Дом у моря	Двухэтажный дом с собственной террасой и видом на Чёрное море	пос. Массандра, ул. Виноградная, д. 25	Ялта	house	120.00	3	150000.00	month	active	2026-03-10 20:27:37.442124
140	12	Студия в новостройке	Уютная студия в новом ЖК с закрытой территорией	ул. Киевская, д. 45	Ялта	apartment	32.00	1	45000.00	month	active	2026-03-10 20:27:37.442124
141	4	Квартира с видом на бухту	Шикарный вид на Севастопольскую бухту, центр города	ул. Ленина, д. 30, кв. 12	Севастополь	apartment	85.00	3	95000.00	month	active	2026-03-10 20:27:37.442124
142	5	Таунхаус в Камышовой бухте	Современный таунхаус в экологически чистом районе	ул. Камышовое шоссе, д. 7	Севастополь	house	95.00	3	110000.00	month	active	2026-03-10 20:27:37.442124
143	12	Коммерческое помещение	Помещение свободного назначения в центре города	пр. Нахимова, д. 12	Севастополь	commercial	60.00	2	70000.00	month	active	2026-03-10 20:27:37.442124
144	4	Квартира в центре Сочи	5 минут до моря, новый ремонт, вся мебель и техника	ул. Орджоникидзе, д. 20	Сочи	apartment	62.00	2	75000.00	month	active	2026-03-10 20:27:37.442124
145	5	Дом в Красной Поляне	Шале в горах, камин, отличный вид на горнолыжные трассы	Красная Поляна, ул. Горная, д. 5	Сочи	house	150.00	4	200000.00	month	active	2026-03-10 20:27:37.442124
147	4	Квартира с видом на море	Центр Геленджика, вид на бухту, новая мебель	ул. Революционная, д. 45	Геленджик	apartment	68.00	2	65000.00	month	active	2026-03-10 20:27:37.442124
150	4	Квартира в центре	Хорошая квартира в центре города, развитая инфраструктура	ул. Ленина, д. 85, кв. 34	Орехово-Зуево	apartment	54.00	2	28000.00	month	active	2026-03-10 20:27:37.442124
151	5	Новостройка	Квартира в новом доме с отделкой	ул. Стаханова, д. 12, кв. 78	Орехово-Зуево	apartment	42.00	1	25000.00	month	active	2026-03-10 20:27:37.442124
152	12	Дом с участком	Частный дом с большим участком	ул. Садовая, д. 25	Орехово-Зуево	house	95.00	3	45000.00	month	active	2026-03-10 20:27:37.442124
173	2	ytry	hrhrhhrt	hthth	thth	apartment	0.00	0	0.00	month	draft	2026-03-13 18:22:17.07505
129	2	Таунхаус	Двухуровневый таунхаус с террасой	ул. Спортивная, д. 10	Авсюнино	house	95.00	3	65000.00	month	rented	2026-02-18 15:50:00
149	12	Коттедж с бассейном	Элитный коттедж с закрытой территорией и бассейном	с. Кабардинка, ул. Морская, д. 7	Геленджик	house	200.00	5	250000.00	month	rented	2026-03-10 20:27:37.442124
153	4	Квартира улучшенной планировки	Просторная квартира в кирпичном доме	ул. Вокзальная, д. 8, кв. 15	Куровское	apartment	58.00	2	22000.00	month	active	2026-03-10 20:27:37.442124
154	5	Студия	Маленькая уютная студия	ул. Советская, д. 45	Куровское	apartment	28.00	1	15000.00	month	active	2026-03-10 20:27:37.442124
155	12	Дом в тихом районе	Дом с небольшим участком	ул. Заречная, д. 7	Куровское	house	70.00	2	35000.00	month	active	2026-03-10 20:27:37.442124
156	4	Квартира рядом с заводом	Удобная квартира для рабочих	ул. Ленина, д. 15, кв. 42	Ликино-Дулёво	apartment	45.00	2	18000.00	month	active	2026-03-10 20:27:37.442124
157	5	Двухкомнатная квартира	Светлая квартира с балконом	ул. Октябрьская, д. 7, кв. 56	Ликино-Дулёво	apartment	52.00	2	20000.00	month	active	2026-03-10 20:27:37.442124
158	12	Коммерческое помещение	Помещение под магазин или офис	ул. Кирова, д. 3	Ликино-Дулёво	commercial	40.00	1	25000.00	month	active	2026-03-10 20:27:37.442124
159	4	Квартира в центре Дрезны	Хороший вариант для семьи	ул. Комсомольская, д. 12, кв. 8	Дрезна	apartment	48.00	2	17000.00	month	active	2026-03-10 20:27:37.442124
160	5	Дом с огородом	Дом с земельным участком	ул. 1 Мая, д. 35	Дрезна	house	60.00	2	28000.00	month	active	2026-03-10 20:27:37.442124
161	12	Квартира	Уютная квартира со свежим ремонтом	ул. Московская, д. 5	Дрезна	apartment	35.00	1	14000.00	month	active	2026-03-10 20:27:37.442124
162	4	Дом в деревне	Дом для загородного отдыха	ул. Центральная, д. 18	Авсюнино	house	55.00	2	22000.00	month	active	2026-03-10 20:27:37.442124
163	5	Квартира	Квартира в двухэтажном доме	ул. Школьная, д. 3, кв. 5	Авсюнино	apartment	40.00	2	13000.00	month	active	2026-03-10 20:27:37.442124
165	18	Элитная квартира в центре Ялты	Премиум-класс, дизайнерский ремонт, панорамные окна	ул. Рузвельта, д. 5	Ялта	apartment	95.00	3	120000.00	month	active	2026-03-10 20:27:37.442124
166	18	Офис в Сочи	Помещение в деловом центре	ул. Конституции, д. 10	Сочи	commercial	85.00	3	90000.00	month	active	2026-03-10 20:27:37.442124
167	18	Квартира в Орехово-Зуево	Студия для молодой семьи	ул. Козлова, д. 20	Орехово-Зуево	apartment	30.00	1	20000.00	month	active	2026-03-10 20:27:37.442124
164	14	Дача	Дачный домик с участком	СНТ "Берёзка", уч. 25	Авсюнино	house	45.00	1	15000.00	month	active	2026-03-10 20:27:37.442124
\.


--
-- TOC entry 5032 (class 0 OID 32819)
-- Dependencies: 224
-- Data for Name: property_photos; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.property_photos (photo_id, property_id, url, is_main, sequence_number) FROM stdin;
15	5	/static/uploads/properties/5/3e36ac50326d4bdaa49f2eb7ff1ab749.jpg	f	3
16	133	/static/uploads/properties/133/68b92dcd416a44fe9ba7d8e1b71ddb73.png	t	1
17	133	/static/uploads/properties/133/7e0490f259fe40c2ba7f64e5971b2b93.png	f	2
18	133	/static/uploads/properties/133/fe74fa46ddff4b3490591ae9803e8c23.png	f	3
19	131	/static/uploads/properties/131/3b9f0a17120149ffadf620c9ed826248.jpg	t	1
20	131	/static/uploads/properties/131/a2250349056746ff8d592a6e814b2b0e.png	f	2
21	131	/static/uploads/properties/131/4cb390607697416aa65dffb5b804169d.jpg	f	3
24	132	/static/uploads/properties/132/2ce27461e6a44b518e8dd704d6d6556d.jpg	t	1
25	132	/static/uploads/properties/132/49d480a5036b41c19c689c2913920768.jpg	f	2
26	130	/static/uploads/properties/130/d04aaaecc04f40f793b09489fb7c9b2e.jpg	t	1
27	130	/static/uploads/properties/130/35437b8315714c9087c3c489faee34e5.jpg	f	2
22	129	/static/uploads/properties/129/56ca02d6aead4a07badd4affda43133e.png	t	1
3	2	/static/uploads/properties/2/photo2.png	t	1
4	3	/static/uploads/properties/3/photo3.png	t	1
5	3	/static/uploads/properties/3/photo4.png	f	2
6	4	/static/uploads/properties/4/photo4.png	t	1
7	5	/static/uploads/properties/5/photo5.png	t	1
8	5	/static/uploads/properties/5/photo3.png	f	2
9	6	/static/uploads/properties/6/photo6.png	t	1
33	137	/static/uploads/properties/137/d3342f97cbdb412bb5e1a55e2cc71b76.png	t	1
34	164	/static/uploads/properties/164/ce95ae6747504292973c6ef778ae0a29.jpg	t	1
35	149	/static/uploads/properties/149/600034e7c99f415aabd3c1eb84fe77d0.jpg	t	1
36	149	/static/uploads/properties/149/71280af538184d64bc1af727dcb30e25.jfif	f	2
39	146	/static/uploads/properties/146/982b82b82d8b4dc8bdec29ad7b10397b.jpg	t	1
40	161	/static/uploads/properties/161/3d8184bf18dd48e69453ad04ff3cba2f.jpg	t	1
41	140	/static/uploads/properties/140/a4d10838570148a99f3c94fc2d71bb3d.jpg	t	1
42	143	/static/uploads/properties/143/ff65695953eb4d4fa4e8394082979f71.jpg	t	1
43	143	/static/uploads/properties/143/ad2dee14b1f54012ae2448afadc9c0eb.jpg	f	2
44	143	/static/uploads/properties/143/9cd9341368f54e4bbb1849c56d92755f.jpg	f	3
45	143	/static/uploads/properties/143/964826345cc54d09b9e8261ee6e5d331.jpg	f	4
46	143	/static/uploads/properties/143/cc6c2e24ea9e410aa56a4e8843c18dfd.jpg	f	5
47	155	/static/uploads/properties/155/90d90eccae1f4d0397cb53edf18cb960.jpg	t	1
48	155	/static/uploads/properties/155/4e1a78a2eb28489598cbacc1440e136d.jpg	f	2
49	155	/static/uploads/properties/155/a647f67f1f6a4155b6b4e84c9d2a5aca.jpg	f	3
68	173	/static/uploads/properties/173/5acba3f12b3047349c94bb2e43384398.png	t	1
1	1	/static/uploads/properties/1/photo1.png	f	3
2	1	/static/uploads/properties/1/photo2.png	t	1
51	1	/static/uploads/properties/1/92a812ce3e75436f9aef4a06de2602c5.jpg	f	2
37	152	/static/uploads/properties/152/c9b546353a75416bb4c376e3ad343d2f.jpg	t	1
38	152	/static/uploads/properties/152/2c9c0a095ac34a728e8a07119894a7e9.jpg	f	2
69	173	/static/uploads/properties/173/d136589710b048c39854ab8ef32a2142.png	f	2
70	173	/static/uploads/properties/173/7622d730209b4157a3add6d5449c1d34.png	f	3
23	129	/static/uploads/properties/129/87f76a43730e4419b0e5aaf492809a0a.jpg	f	2
50	129	/static/uploads/properties/129/5d7d8f6c24394bcc9a3e3ff3131bc52e.jpg	f	3
\.


--
-- TOC entry 5028 (class 0 OID 32770)
-- Dependencies: 220
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (user_id, email, password_hash, avatar_url, full_name, user_type, contact_info, is_active, created_at) FROM stdin;
1	admin@rentease.ru	240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9	/static/uploads/avatars/1fe7541a1df541f4a6abadc71e67463e.jpg	Администратор Системы	admin	{"phone": "+7 (999) 123-45-67", "birth_date": "2000-01-02"}	t	2026-02-13 21:58:34.325669
12	qmett1@gmail.com	bdc1e3618db56b35a6c7d8c0375166fd7b11893c9bca67113b4ea963b454fb8e	/static/uploads/avatars/e5afd064062f46de89802f5ef3ca4bae.jpg	Соловьёва Юлия Сергеевна	agent	{"inn": "4324435667", "city": "Ликино-Дулево  (Московская область)", "phone": "+79066784781", "passport": "4621789012", "birth_date": "2007-01-02"}	t	2026-03-10 20:02:42.602234
11	myname@mail.ru	51bb9ba1a4744cf288c7ae72b5360e505ab9406e33b0e0871b5e969bc25b4fc5	/static/uploads/avatars/e4cb200e7e9e421c929c984cd2752e99.jpg	myname	tenant	{"phone": "+79256789011", "birth_date": "2000-01-02"}	t	2026-02-24 20:55:16.895943
9	vladislav.boev02@mail.ru	952957cd67e20c467107f126a4c760937c516fe5d373eae39b6ea39bc16ae273	/static/uploads/avatars/1f7bf80f63bf4694bb1f80d1e5faaaca.jpg	Боев Владислав Максимович	tenant	{"inn": "4245343436", "city": "Орехово-Зуево", "phone": "+79964959391", "passport": "1234567890", "birth_date": "2007-01-02"}	t	2026-02-23 13:16:20.738342
17	feoktistov.gleb@mail.ru	405ffaf7e22ebe8ba27999b01b3cf095e870255abdd3d64b5387f0f649c4d15a	\N	Феоктистов Глеб Юрьевич	tenant	{"city": "Москва", "phone": "+7 (903) 345-67-89"}	t	2026-03-10 20:22:23.818207
4	owner.elena@mail.ru	43a0d17178a9d26c9e0fe9a74b0b45e38d32f27aed887a008a54bf6e033bf7b9	\N	Елена Смирнова	owner	{"phone": "+7 (999) 456-78-90"}	t	2026-02-13 21:58:34.368669
7	tenant.maria@mail.ru	b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33	\N	Мария Васильева	tenant	{"phone": "+7 (999) 789-01-23"}	t	2026-02-13 21:58:34.368669
13	romanchuvaga@mail.ru	22187723de93e99653b064fd991a2b8e35179394044dc819bc1664196495a946	/static/uploads/avatars/e67a261db88e461ea08e0cce179dd922.jpg	Чувага Роман Думитрувич	tenant	{"inn": "4245343436", "city": "Давыдово", "phone": "+79673257035", "passport": "3354680123", "birth_date": "2007-08-11"}	t	2026-03-10 20:08:58.847439
2	agent.anna@rentease.ru	f44d1ac9bf0c69b083380b86dbdf3b73797150e3cca4820ac399f7917e607647	\N	Анна Петрова	agent	{"phone": "+7 (969) 234-56-78", "birth_date": "2001-01-02"}	t	2026-02-13 21:58:34.368669
16	mazanov.ilya@mail.ru	b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33	\N	Мазанов Илья Алексеевич	tenant	{"city": "Москва", "phone": "+7 (925) 234-56-78"}	t	2026-03-10 20:22:23.818207
3	agent.ivan@rentease.ru	f44d1ac9bf0c69b083380b86dbdf3b73797150e3cca4820ac399f7917e607647	\N	Иван Сидоров	agent	{"city": "Орехово-Зуево", "phone": "+7 (999) 345-67-89", "passport": "1234567890"}	t	2026-02-13 21:58:34.368669
5	owner.dmitry@mail.ru	43a0d17178a9d26c9e0fe9a74b0b45e38d32f27aed887a008a54bf6e033bf7b9	/static/uploads/avatars/d3881d4a1a76457eaf2280bd44657341.jpg	Дмитрий Иванов	owner	{"phone": "+7 (999) 567-89-01"}	t	2026-02-13 21:58:34.368669
18	trunin.danila@mail.ru	b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33	\N	Трунин Данила Сергеевич	tenant	{"city": "Москва", "phone": "+7 (915) 456-78-90"}	t	2026-03-10 20:22:23.818207
19	tkachenko.dmitry@mail.ru	b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33	\N	Ткаченко Дмитрий Евгеньевич	tenant	{"city": "Москва", "phone": "+7 (926) 567-89-01"}	t	2026-03-10 20:22:23.818207
15	kruchkova.oksana@mail.ru	b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33	\N	Крючкова Оксана Вячеславовна	tenant	{"city": "Москва", "phone": "+7 (916) 123-45-67"}	t	2026-03-10 20:22:23.818207
14	aquanomore@gmail.com	4d49ca0443be87f6eff65f63508ff8f27954eaa051df0fe1baa318179439b60c	/static/uploads/avatars/cc5b1d5043b042538ddb8ad6ae566afb.jpg	Марков Иван Александрович	owner	{"inn": "2556647474", "city": "Авсюнино", "phone": "+79267890023", "passport": "7818478395", "birth_date": "2007-05-17"}	f	2026-03-10 20:14:15.429596
6	tenant.alex@mail.ru	b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33	\N	Тестовый пользователь	tenant	{"phone": "+7 (999) 678-90-12"}	t	2026-02-13 21:58:34.368669
20	drozhzhina.sofia@rentease.ru	f44d1ac9bf0c69b083380b86dbdf3b73797150e3cca4820ac399f7917e607647	\N	Дрожжина София Юрьевна	agent	{"city": "Москва", "phone": "+7 (968) 678-90-12"}	t	2026-03-10 20:22:23.818207
21	taranenko@rentease.ru	3147bfca52087a3ec7fddaf5c41b61505257ae66a4df61ad6c40fdb424c622ea	/static/uploads/avatars/f730e34f54024682ac271e381da8a3e7.png	Тараненко Иван Сергеевич	tenant	{"inn": "2556647474", "passport": "5667778883"}	t	2026-03-15 18:27:54.989358
\.


--
-- TOC entry 5053 (class 0 OID 0)
-- Dependencies: 225
-- Name: applications_application_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.applications_application_id_seq', 395, true);


--
-- TOC entry 5054 (class 0 OID 0)
-- Dependencies: 231
-- Name: audit_logs_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.audit_logs_log_id_seq', 167, true);


--
-- TOC entry 5055 (class 0 OID 0)
-- Dependencies: 227
-- Name: contracts_contract_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.contracts_contract_id_seq', 97, true);


--
-- TOC entry 5056 (class 0 OID 0)
-- Dependencies: 229
-- Name: messages_message_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.messages_message_id_seq', 270, true);


--
-- TOC entry 5057 (class 0 OID 0)
-- Dependencies: 221
-- Name: properties_property_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.properties_property_id_seq', 173, true);


--
-- TOC entry 5058 (class 0 OID 0)
-- Dependencies: 223
-- Name: property_photos_photo_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.property_photos_photo_id_seq', 71, true);


--
-- TOC entry 5059 (class 0 OID 0)
-- Dependencies: 219
-- Name: users_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_user_id_seq', 21, true);


--
-- TOC entry 4835 (class 2606 OID 32851)
-- Name: applications applications_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT applications_pkey PRIMARY KEY (application_id);


--
-- TOC entry 4849 (class 2606 OID 32941)
-- Name: audit_logs audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (log_id);


--
-- TOC entry 4840 (class 2606 OID 32885)
-- Name: contracts contracts_application_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT contracts_application_id_key UNIQUE (application_id);


--
-- TOC entry 4842 (class 2606 OID 32883)
-- Name: contracts contracts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT contracts_pkey PRIMARY KEY (contract_id);


--
-- TOC entry 4847 (class 2606 OID 32918)
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (message_id);


--
-- TOC entry 4831 (class 2606 OID 32807)
-- Name: properties properties_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.properties
    ADD CONSTRAINT properties_pkey PRIMARY KEY (property_id);


--
-- TOC entry 4833 (class 2606 OID 32831)
-- Name: property_photos property_photos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.property_photos
    ADD CONSTRAINT property_photos_pkey PRIMARY KEY (photo_id);


--
-- TOC entry 4827 (class 2606 OID 32787)
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- TOC entry 4829 (class 2606 OID 32785)
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (user_id);


--
-- TOC entry 4836 (class 1259 OID 82023)
-- Name: idx_applications_property_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_applications_property_id ON public.applications USING btree (property_id);


--
-- TOC entry 4837 (class 1259 OID 82025)
-- Name: idx_applications_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_applications_status ON public.applications USING btree (status);


--
-- TOC entry 4838 (class 1259 OID 82024)
-- Name: idx_applications_tenant_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_applications_tenant_id ON public.applications USING btree (tenant_id);


--
-- TOC entry 4850 (class 1259 OID 82030)
-- Name: idx_audit_logs_created_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_audit_logs_created_at ON public.audit_logs USING btree (created_at);


--
-- TOC entry 4851 (class 1259 OID 82029)
-- Name: idx_audit_logs_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_audit_logs_user_id ON public.audit_logs USING btree (user_id);


--
-- TOC entry 4843 (class 1259 OID 82026)
-- Name: idx_contracts_application_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_contracts_application_id ON public.contracts USING btree (application_id);


--
-- TOC entry 4844 (class 1259 OID 82027)
-- Name: idx_messages_from_to; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_messages_from_to ON public.messages USING btree (from_user_id, to_user_id);


--
-- TOC entry 4845 (class 1259 OID 82028)
-- Name: idx_messages_is_read; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_messages_is_read ON public.messages USING btree (is_read);


--
-- TOC entry 4866 (class 2620 OID 98406)
-- Name: applications trg_application_status_change; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_application_status_change AFTER UPDATE OF status ON public.applications FOR EACH ROW WHEN (((old.status)::text IS DISTINCT FROM (new.status)::text)) EXECUTE FUNCTION public.notify_application_status_change();


--
-- TOC entry 4867 (class 2620 OID 90267)
-- Name: applications trg_applications_audit_delete; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_applications_audit_delete BEFORE DELETE ON public.applications FOR EACH ROW EXECUTE FUNCTION public.audit_log_delete();


--
-- TOC entry 4868 (class 2620 OID 90265)
-- Name: applications trg_applications_audit_insert; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_applications_audit_insert AFTER INSERT ON public.applications FOR EACH ROW EXECUTE FUNCTION public.audit_log_insert();


--
-- TOC entry 4869 (class 2620 OID 90266)
-- Name: applications trg_applications_audit_update; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_applications_audit_update AFTER UPDATE ON public.applications FOR EACH ROW EXECUTE FUNCTION public.audit_log_update();


--
-- TOC entry 4871 (class 2620 OID 98408)
-- Name: contracts trg_contract_cancel; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_contract_cancel AFTER UPDATE OF signing_status ON public.contracts FOR EACH ROW WHEN ((((new.signing_status)::text = 'cancelled'::text) AND ((old.signing_status)::text <> 'cancelled'::text))) EXECUTE FUNCTION public.notify_contract_cancellation();


--
-- TOC entry 4872 (class 2620 OID 98407)
-- Name: contracts trg_contract_signature; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_contract_signature AFTER UPDATE OF tenant_signed, owner_signed, signing_status ON public.contracts FOR EACH ROW EXECUTE FUNCTION public.notify_contract_signature();


--
-- TOC entry 4873 (class 2620 OID 90273)
-- Name: contracts trg_contracts_audit_delete; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_contracts_audit_delete BEFORE DELETE ON public.contracts FOR EACH ROW EXECUTE FUNCTION public.audit_log_delete();


--
-- TOC entry 4874 (class 2620 OID 90271)
-- Name: contracts trg_contracts_audit_insert; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_contracts_audit_insert AFTER INSERT ON public.contracts FOR EACH ROW EXECUTE FUNCTION public.audit_log_insert();


--
-- TOC entry 4875 (class 2620 OID 90272)
-- Name: contracts trg_contracts_audit_update; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_contracts_audit_update AFTER UPDATE ON public.contracts FOR EACH ROW EXECUTE FUNCTION public.audit_log_update();


--
-- TOC entry 4877 (class 2620 OID 90279)
-- Name: messages trg_messages_audit_delete; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_messages_audit_delete BEFORE DELETE ON public.messages FOR EACH ROW EXECUTE FUNCTION public.audit_log_delete();


--
-- TOC entry 4878 (class 2620 OID 90277)
-- Name: messages trg_messages_audit_insert; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_messages_audit_insert AFTER INSERT ON public.messages FOR EACH ROW EXECUTE FUNCTION public.audit_log_insert();


--
-- TOC entry 4879 (class 2620 OID 90278)
-- Name: messages trg_messages_audit_update; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_messages_audit_update AFTER UPDATE ON public.messages FOR EACH ROW EXECUTE FUNCTION public.audit_log_update();


--
-- TOC entry 4870 (class 2620 OID 98405)
-- Name: applications trg_new_application_notify; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_new_application_notify AFTER INSERT ON public.applications FOR EACH ROW EXECUTE FUNCTION public.notify_new_application();


--
-- TOC entry 4863 (class 2620 OID 90270)
-- Name: properties trg_properties_audit_delete; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_properties_audit_delete BEFORE DELETE ON public.properties FOR EACH ROW EXECUTE FUNCTION public.audit_log_delete();


--
-- TOC entry 4864 (class 2620 OID 90268)
-- Name: properties trg_properties_audit_insert; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_properties_audit_insert AFTER INSERT ON public.properties FOR EACH ROW EXECUTE FUNCTION public.audit_log_insert();


--
-- TOC entry 4865 (class 2620 OID 90269)
-- Name: properties trg_properties_audit_update; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_properties_audit_update AFTER UPDATE ON public.properties FOR EACH ROW EXECUTE FUNCTION public.audit_log_update();


--
-- TOC entry 4876 (class 2620 OID 82021)
-- Name: contracts trg_update_contract_status; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_update_contract_status BEFORE UPDATE OF tenant_signed, owner_signed ON public.contracts FOR EACH ROW EXECUTE FUNCTION public.update_contract_signing_status();


--
-- TOC entry 4860 (class 2620 OID 90276)
-- Name: users trg_users_audit_delete; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_users_audit_delete BEFORE DELETE ON public.users FOR EACH ROW EXECUTE FUNCTION public.audit_log_delete();


--
-- TOC entry 4861 (class 2620 OID 90274)
-- Name: users trg_users_audit_insert; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_users_audit_insert AFTER INSERT ON public.users FOR EACH ROW EXECUTE FUNCTION public.audit_log_insert();


--
-- TOC entry 4862 (class 2620 OID 90275)
-- Name: users trg_users_audit_update; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_users_audit_update AFTER UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.audit_log_update();


--
-- TOC entry 4854 (class 2606 OID 32852)
-- Name: applications applications_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT applications_property_id_fkey FOREIGN KEY (property_id) REFERENCES public.properties(property_id);


--
-- TOC entry 4855 (class 2606 OID 32857)
-- Name: applications applications_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT applications_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.users(user_id);


--
-- TOC entry 4859 (class 2606 OID 32942)
-- Name: audit_logs audit_logs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id);


--
-- TOC entry 4856 (class 2606 OID 32886)
-- Name: contracts contracts_application_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT contracts_application_id_fkey FOREIGN KEY (application_id) REFERENCES public.applications(application_id);


--
-- TOC entry 4857 (class 2606 OID 32919)
-- Name: messages messages_from_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_from_user_id_fkey FOREIGN KEY (from_user_id) REFERENCES public.users(user_id);


--
-- TOC entry 4858 (class 2606 OID 32924)
-- Name: messages messages_to_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_to_user_id_fkey FOREIGN KEY (to_user_id) REFERENCES public.users(user_id);


--
-- TOC entry 4852 (class 2606 OID 32808)
-- Name: properties properties_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.properties
    ADD CONSTRAINT properties_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- TOC entry 4853 (class 2606 OID 32832)
-- Name: property_photos property_photos_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.property_photos
    ADD CONSTRAINT property_photos_property_id_fkey FOREIGN KEY (property_id) REFERENCES public.properties(property_id) ON DELETE CASCADE;


-- Completed on 2026-03-15 22:15:28

--
-- PostgreSQL database dump complete
--

\unrestrict JXZ7QSFCu8N3sLbzH1nu2kq6ygnHedQIWHISQZ1JM8DhWy3VAFiKz4j5wJodi1U

