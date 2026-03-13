-- Функция 1: Ежемесячная статистика (исправленная)
CREATE OR REPLACE FUNCTION get_agent_monthly_stats(
    p_agent_id INTEGER,
    p_months INTEGER DEFAULT 6
)
RETURNS TABLE(
    month TEXT,
    deals_count BIGINT,
    total_profit NUMERIC,
    applications_count BIGINT,
    approved_count BIGINT,
    rejected_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    WITH monthly_data AS (
        SELECT 
            TO_CHAR(DATE_TRUNC('month', COALESCE(c.created_at, a.created_at, NOW())), 'YYYY-MM') as month,
            COUNT(DISTINCT c.contract_id) as deals,
            COALESCE(SUM(c.total_amount), 0) as profit,
            COUNT(DISTINCT a.application_id) as apps,
            COUNT(DISTINCT CASE WHEN a.status = 'approved' THEN a.application_id END) as approved,
            COUNT(DISTINCT CASE WHEN a.status = 'rejected' THEN a.application_id END) as rejected
        FROM properties p
        LEFT JOIN applications a ON p.property_id = a.property_id
        LEFT JOIN contracts c ON a.application_id = c.application_id
        WHERE p.owner_id = p_agent_id  -- ← заменили agent_id на owner_id
          AND COALESCE(c.created_at, a.created_at, NOW()) >= CURRENT_DATE - (p_months || ' months')::INTERVAL
        GROUP BY DATE_TRUNC('month', COALESCE(c.created_at, a.created_at, NOW()))
        ORDER BY month DESC
    )
    SELECT * FROM monthly_data;
END;
$$ LANGUAGE plpgsql STABLE;

-- Функция 2: Статистика производительности (исправленная)
CREATE OR REPLACE FUNCTION get_agent_performance_stats(
    p_agent_id INTEGER,
    p_months INTEGER DEFAULT 6
)
RETURNS TABLE(
    total_profit NUMERIC,
    avg_profit_per_property NUMERIC,
    total_deals BIGINT,
    occupancy_rate NUMERIC,
    processed_applications BIGINT,
    avg_response_hours NUMERIC,
    conversion_rate NUMERIC
) AS $$
DECLARE
    v_total_profit NUMERIC;
    v_total_deals BIGINT;
    v_properties_count BIGINT;
    v_active_properties BIGINT;
    v_total_applications BIGINT;
    v_processed_apps BIGINT;
    v_avg_response NUMERIC;
    v_conversion NUMERIC;
BEGIN
    -- Сделки и прибыль
    SELECT 
        COALESCE(SUM(c.total_amount), 0),
        COUNT(DISTINCT c.contract_id)
    INTO v_total_profit, v_total_deals
    FROM properties p
    LEFT JOIN applications a ON p.property_id = a.property_id
    LEFT JOIN contracts c ON a.application_id = c.application_id
    WHERE p.owner_id = p_agent_id  -- ← заменили agent_id
      AND c.signing_status = 'signed'
      AND c.created_at >= CURRENT_DATE - (p_months || ' months')::INTERVAL;

    -- Количество объектов
    SELECT COUNT(*) INTO v_properties_count
    FROM properties
    WHERE owner_id = p_agent_id;  -- ← заменили

    -- Активные объекты
    SELECT COUNT(*) INTO v_active_properties
    FROM properties
    WHERE owner_id = p_agent_id AND status = 'active';  -- ← заменили

    -- Обработанные заявки
    SELECT COUNT(*) INTO v_processed_apps
    FROM applications a
    JOIN properties p ON a.property_id = p.property_id
    WHERE p.owner_id = p_agent_id  -- ← заменили
      AND a.status IN ('approved', 'rejected')
      AND a.responded_at IS NOT NULL
      AND a.created_at >= CURRENT_DATE - (p_months || ' months')::INTERVAL;

    -- Все заявки
    SELECT COUNT(*) INTO v_total_applications
    FROM applications a
    JOIN properties p ON a.property_id = p.property_id
    WHERE p.owner_id = p_agent_id  -- ← заменили
      AND a.created_at >= CURRENT_DATE - (p_months || ' months')::INTERVAL;

    -- Среднее время ответа
    SELECT COALESCE(AVG(EXTRACT(EPOCH FROM (a.responded_at - a.created_at)) / 3600), 0)
    INTO v_avg_response
    FROM applications a
    JOIN properties p ON a.property_id = p.property_id
    WHERE p.owner_id = p_agent_id  -- ← заменили
      AND a.responded_at IS NOT NULL
      AND a.created_at >= CURRENT_DATE - (p_months || ' months')::INTERVAL;

    -- Конверсия
    IF v_total_applications > 0 THEN
        v_conversion := (v_total_deals::NUMERIC / v_total_applications * 100);
    ELSE
        v_conversion := 0;
    END IF;

    RETURN QUERY
    SELECT 
        COALESCE(v_total_profit, 0) as total_profit,
        CASE 
            WHEN v_properties_count > 0 THEN v_total_profit / v_properties_count
            ELSE 0
        END as avg_profit_per_property,
        COALESCE(v_total_deals, 0) as total_deals,
        CASE 
            WHEN v_properties_count > 0 THEN 
                ((v_properties_count - v_active_properties) * 100.0 / v_properties_count)
            ELSE 0
        END as occupancy_rate,
        COALESCE(v_processed_apps, 0) as processed_applications,
        COALESCE(v_avg_response, 0) as avg_response_hours,
        COALESCE(v_conversion, 0) as conversion_rate;
END;
$$ LANGUAGE plpgsql STABLE;

-- Функция 3: Статистика по статусам заявок (исправленная)
CREATE OR REPLACE FUNCTION get_agent_application_status_stats(
    p_agent_id INTEGER,
    p_days INTEGER DEFAULT 90
)
RETURNS TABLE(
    status VARCHAR,
    count BIGINT,
    percentage NUMERIC
) AS $$
DECLARE
    v_total BIGINT;
BEGIN
    SELECT COUNT(*) INTO v_total
    FROM applications a
    JOIN properties p ON a.property_id = p.property_id
    WHERE p.owner_id = p_agent_id  -- ← заменили
      AND a.created_at >= CURRENT_DATE - (p_days || ' days')::INTERVAL;

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
    WHERE p.owner_id = p_agent_id  -- ← заменили
      AND a.created_at >= CURRENT_DATE - (p_days || ' days')::INTERVAL
    GROUP BY a.status
    ORDER BY a.status;
END;
$$ LANGUAGE plpgsql STABLE;