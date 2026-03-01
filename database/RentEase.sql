--
-- PostgreSQL database dump
--

\restrict IuLozB2xwoVxw2DZGMO8cHtlEG5mTwd5awaY2PH9l3TcodZSHjbOXweOGb80Xtr

-- Dumped from database version 18.1
-- Dumped by pg_dump version 18.1

-- Started on 2026-02-24 21:59:28

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
-- TOC entry 246 (class 1255 OID 49248)
-- Name: get_agent_application_status_stats(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_agent_application_status_stats(p_agent_id integer, p_days integer DEFAULT 90) RETURNS TABLE(status character varying, count bigint, percentage numeric)
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    v_total BIGINT;
BEGIN
    SELECT COUNT(*) INTO v_total
    FROM applications a
    JOIN properties p ON a.property_id = p.property_id
    WHERE p.agent_id = p_agent_id
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
    WHERE p.agent_id = p_agent_id
      AND a.created_at >= CURRENT_DATE - (p_days || ' days')::INTERVAL
    GROUP BY a.status
    ORDER BY a.status;
END;
$$;


ALTER FUNCTION public.get_agent_application_status_stats(p_agent_id integer, p_days integer) OWNER TO postgres;

--
-- TOC entry 244 (class 1255 OID 49246)
-- Name: get_agent_monthly_stats(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_agent_monthly_stats(p_agent_id integer, p_months integer DEFAULT 6) RETURNS TABLE(month text, deals_count bigint, total_profit numeric, applications_count bigint, approved_count bigint, rejected_count bigint)
    LANGUAGE plpgsql STABLE
    AS $$
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
        WHERE p.agent_id = p_agent_id
          AND COALESCE(c.created_at, a.created_at, NOW()) >= CURRENT_DATE - (p_months || ' months')::INTERVAL
        GROUP BY DATE_TRUNC('month', COALESCE(c.created_at, a.created_at, NOW()))
        ORDER BY month DESC
    )
    SELECT * FROM monthly_data;
END;
$$;


ALTER FUNCTION public.get_agent_monthly_stats(p_agent_id integer, p_months integer) OWNER TO postgres;

--
-- TOC entry 245 (class 1255 OID 49247)
-- Name: get_agent_performance_stats(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_agent_performance_stats(p_agent_id integer, p_months integer DEFAULT 6) RETURNS TABLE(total_profit numeric, avg_profit_per_property numeric, total_deals bigint, occupancy_rate numeric, processed_applications bigint, avg_response_hours numeric, conversion_rate numeric)
    LANGUAGE plpgsql STABLE
    AS $$
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
    SELECT 
        COALESCE(SUM(c.total_amount), 0),
        COUNT(DISTINCT c.contract_id)
    INTO v_total_profit, v_total_deals
    FROM properties p
    LEFT JOIN applications a ON p.property_id = a.property_id
    LEFT JOIN contracts c ON a.application_id = c.application_id
    WHERE p.agent_id = p_agent_id
      AND c.signing_status = 'signed'
      AND c.created_at >= CURRENT_DATE - (p_months || ' months')::INTERVAL;

    SELECT COUNT(*) INTO v_properties_count
    FROM properties
    WHERE agent_id = p_agent_id;

    SELECT COUNT(*) INTO v_active_properties
    FROM properties
    WHERE agent_id = p_agent_id AND status = 'active';

    SELECT COUNT(*) INTO v_processed_apps
    FROM applications a
    JOIN properties p ON a.property_id = p.property_id
    WHERE p.agent_id = p_agent_id
      AND a.status IN ('approved', 'rejected')
      AND a.responded_at IS NOT NULL
      AND a.created_at >= CURRENT_DATE - (p_months || ' months')::INTERVAL;

    SELECT COUNT(*) INTO v_total_applications
    FROM applications a
    JOIN properties p ON a.property_id = p.property_id
    WHERE p.agent_id = p_agent_id
      AND a.created_at >= CURRENT_DATE - (p_months || ' months')::INTERVAL;

    SELECT COALESCE(AVG(EXTRACT(EPOCH FROM (a.responded_at - a.created_at)) / 3600), 0)
    INTO v_avg_response
    FROM applications a
    JOIN properties p ON a.property_id = p.property_id
    WHERE p.agent_id = p_agent_id
      AND a.responded_at IS NOT NULL
      AND a.created_at >= CURRENT_DATE - (p_months || ' months')::INTERVAL;

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
$$;


ALTER FUNCTION public.get_agent_performance_stats(p_agent_id integer, p_months integer) OWNER TO postgres;

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
    agent_id integer,
    message text,
    desired_date date,
    duration_days integer,
    answer text,
    status character varying(20) DEFAULT 'pending'::character varying,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT applications_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'approved'::character varying, 'rejected'::character varying, 'completed'::character varying])::text[])))
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
-- TOC entry 5012 (class 0 OID 0)
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
-- TOC entry 5013 (class 0 OID 0)
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
    property_id integer NOT NULL,
    tenant_id integer NOT NULL,
    owner_id integer NOT NULL,
    contract_type character varying(10),
    start_date date NOT NULL,
    end_date date,
    total_amount numeric(12,2) NOT NULL,
    signing_status character varying(10) DEFAULT 'draft'::character varying,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT contracts_contract_type_check CHECK (((contract_type)::text = ANY ((ARRAY['lease'::character varying, 'sale'::character varying])::text[]))),
    CONSTRAINT contracts_signing_status_check CHECK (((signing_status)::text = ANY ((ARRAY['draft'::character varying, 'pending'::character varying, 'signed'::character varying])::text[])))
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
-- TOC entry 5014 (class 0 OID 0)
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
-- TOC entry 5015 (class 0 OID 0)
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
    agent_id integer,
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
-- TOC entry 5016 (class 0 OID 0)
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
-- TOC entry 5017 (class 0 OID 0)
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
-- TOC entry 5018 (class 0 OID 0)
-- Dependencies: 219
-- Name: users_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_user_id_seq OWNED BY public.users.user_id;


--
-- TOC entry 4797 (class 2604 OID 32841)
-- Name: applications application_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.applications ALTER COLUMN application_id SET DEFAULT nextval('public.applications_application_id_seq'::regclass);


--
-- TOC entry 4806 (class 2604 OID 32933)
-- Name: audit_logs log_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_logs ALTER COLUMN log_id SET DEFAULT nextval('public.audit_logs_log_id_seq'::regclass);


--
-- TOC entry 4800 (class 2604 OID 32871)
-- Name: contracts contract_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contracts ALTER COLUMN contract_id SET DEFAULT nextval('public.contracts_contract_id_seq'::regclass);


--
-- TOC entry 4803 (class 2604 OID 32910)
-- Name: messages message_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages ALTER COLUMN message_id SET DEFAULT nextval('public.messages_message_id_seq'::regclass);


--
-- TOC entry 4792 (class 2604 OID 32792)
-- Name: properties property_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.properties ALTER COLUMN property_id SET DEFAULT nextval('public.properties_property_id_seq'::regclass);


--
-- TOC entry 4795 (class 2604 OID 32822)
-- Name: property_photos photo_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.property_photos ALTER COLUMN photo_id SET DEFAULT nextval('public.property_photos_photo_id_seq'::regclass);


--
-- TOC entry 4788 (class 2604 OID 32773)
-- Name: users user_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN user_id SET DEFAULT nextval('public.users_user_id_seq'::regclass);


--
-- TOC entry 5000 (class 0 OID 32838)
-- Dependencies: 226
-- Data for Name: applications; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.applications (application_id, property_id, tenant_id, agent_id, message, desired_date, duration_days, answer, status, created_at) FROM stdin;
1	1	6	2	Интересует квартира, хотел бы посмотреть в выходные	2024-06-15	365	\N	pending	2026-02-13 21:58:34.485672
2	2	7	2	Очень понравилась квартира, готов заключить договор	2024-06-10	180	Принято, жду вас в пятницу	approved	2026-02-13 21:58:34.48767
3	3	6	3	Дороговато, есть возможность торга?	2024-06-20	30	Цена фиксированная	rejected	2026-02-13 21:58:34.488671
124	1	6	2	Здравствуйте! Хотел бы посмотреть квартиру в ближайшие выходные	2026-03-01	365	\N	pending	2026-02-20 10:30:00
125	3	6	2	Интересует помещение для магазина, возможен ли долгосрочный договор?	2026-03-05	730	Да, возможен. Жду вас на просмотр в среду	approved	2026-02-21 14:15:00
126	5	6	3	Хотим снять дом на лето для семьи с детьми	2026-06-01	120	Дом уже сдан на этот период	rejected	2026-02-15 09:45:00
127	129	6	3	Интересует таунхаус для постоянного проживания	2026-03-10	365	\N	pending	2026-02-23 16:20:00
128	2	7	2	Студия очень понравилась, готова заключить договор	2026-03-01	365	Приходите в пятницу в 15:00	approved	2026-02-18 12:30:00
129	128	7	2	Квартира в новостройке - мечта! Когда можно посмотреть?	2026-03-02	180	\N	pending	2026-02-22 11:10:00
130	4	7	3	Квартира на Невском - отличный вариант, но дороговато	2026-03-15	365	Цена фиксированная	rejected	2026-02-19 13:45:00
131	131	7	2	Интересует квартира в Куровском	2026-03-05	365	Жду вас в субботу в 14:00	approved	2026-02-21 10:00:00
132	128	9	2	Квартира в новостройке - супер! Можно посмотреть в выходные?	2026-03-03	180	\N	pending	2026-02-23 18:30:00
133	130	9	2	Офис в Ликино-Дулёво для небольшой компании	2026-03-01	365	Приходите во вторник после 18:00	approved	2026-02-22 15:40:00
134	129	9	3	Таунхаус интересует для семьи	2026-04-01	730	\N	pending	2026-02-24 09:15:00
135	132	9	2	Апартаменты в Орехово-Зуево	2026-03-10	365	Можем обсудить	approved	2026-02-20 11:25:00
136	1	6	2	Повторно интересуюсь квартирой на Тверской	2026-03-15	365	Квартира ещё свободна	approved	2026-02-17 08:50:00
137	3	7	3	А дом у озера на лето ещё свободен?	2026-06-15	90	Уже сдан	rejected	2026-02-16 14:30:00
138	5	9	2	Рассматриваю коммерческое помещение в Новосибирске	2026-04-01	365	\N	pending	2026-02-24 12:10:00
\.


--
-- TOC entry 5006 (class 0 OID 32930)
-- Dependencies: 232
-- Data for Name: audit_logs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.audit_logs (log_id, user_id, action, entity_type, entity_id, details, created_at) FROM stdin;
\.


--
-- TOC entry 5002 (class 0 OID 32868)
-- Dependencies: 228
-- Data for Name: contracts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.contracts (contract_id, application_id, property_id, tenant_id, owner_id, contract_type, start_date, end_date, total_amount, signing_status, created_at) FROM stdin;
1	128	2	7	4	lease	2026-03-01	2027-02-28	420000.00	signed	2026-02-19 15:45:00
2	133	130	9	4	lease	2026-03-01	2027-02-28	540000.00	signed	2026-02-23 17:10:00
3	131	131	7	5	lease	2026-03-05	2027-03-04	384000.00	draft	2026-02-22 11:20:00
4	136	1	6	4	lease	2026-03-15	2027-03-14	540000.00	draft	2026-02-18 09:55:00
\.


--
-- TOC entry 5004 (class 0 OID 32907)
-- Dependencies: 230
-- Data for Name: messages; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.messages (message_id, from_user_id, to_user_id, content, is_read, created_at) FROM stdin;
1	6	2	Здравствуйте! Хотел бы посмотреть квартиру на Тверской	t	2026-02-20 10:35:00
2	2	6	Добрый день! Квартира свободна. Можем показать в субботу в 14:00	t	2026-02-20 11:20:00
3	6	2	Отлично! Буду в субботу	t	2026-02-20 12:05:00
4	7	2	Добрый день! Очень понравилась студия	t	2026-02-18 13:15:00
5	2	7	Здравствуйте! Рада, что понравилось. Когда удобно посмотреть?	t	2026-02-18 14:30:00
6	7	2	Могу завтра после 18:00	t	2026-02-18 15:45:00
7	2	7	Договорились, жду в 18:30	t	2026-02-18 16:20:00
8	9	2	Здравствуйте! Квартира в новостройке ещё свободна?	f	2026-02-23 18:35:00
9	9	2	Добрый вечер! Интересует офис в Ликино-Дулёво	t	2026-02-22 16:10:00
10	2	9	Здравствуйте! Да, офис свободен. Можем показать завтра	t	2026-02-22 17:25:00
11	9	2	Отлично, во сколько?	t	2026-02-22 18:00:00
12	2	9	В 19:00 вас устроит?	f	2026-02-22 18:30:00
\.


--
-- TOC entry 4996 (class 0 OID 32789)
-- Dependencies: 222
-- Data for Name: properties; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.properties (property_id, owner_id, agent_id, title, description, address, city, property_type, area, rooms, price, interval_pay, status, created_at) FROM stdin;
1	4	2	Уютная квартира в центре	Просторная квартира с видом на набережную, отличный ремонт, вся техника новая	ул. Тверская, д. 10, кв. 45	Москва	apartment	65.50	2	45000.00	month	active	2026-02-13 21:58:34.38867
2	4	2	Студия в новостройке	Современная студия с дизайнерским ремонтом, есть всё для комфортного проживания	ул. Ленина, д. 15	Москва	apartment	32.00	1	35000.00	month	active	2026-02-13 21:58:34.38867
3	5	3	Загородный дом у озера	Двухэтажный дом с участком, камин, сауна, отличное место для отдыха	пос. Репино, ул. Лесная, д. 5	Ленинградская область	house	150.00	4	120000.00	month	active	2026-02-13 21:58:34.41967
6	5	3	Квартира у метро	Уютная квартира в 5 минутах от метро, хороший ремонт, есть мебель	ул. Гагарина, д. 7	Екатеринбург	apartment	55.00	2	38000.00	month	active	2026-02-13 21:58:34.420669
4	5	3	Квартира на Невском	Квартира в историческом центре, высокие потолки, лепнина, паркет	Невский пр., д. 25, кв. 12	Санкт-Петербург	apartment	95.00	3	75000.00	week	active	2026-02-13 21:58:34.41967
5	4	2	Коммерческое помещение	Помещение свободного назначения на первом этаже жилого дома	пр. Мира, д. 32	Новосибирск	house	85.00	2	60000.00	month	active	2026-02-13 21:58:34.420669
128	4	2	Квартира в новостройке	ЖК "Северное сияние", сдан в 2025	ул. Строителей, д. 3, кв. 78	Москва	apartment	48.00	2	42000.00	month	active	2026-02-15 11:40:00
131	5	3	Квартира в центре	2-комнатная квартира с видом на парк	ул. Советская, д. 82, кв. 23	Куровское	apartment	52.00	2	32000.00	month	active	2026-02-22 14:15:00
132	5	2	Апартаменты в центре	Студия с евроремонтом	ул. Кирова, д. 5	Орехово-Зуево	apartment	34.00	1	25000.00	month	active	2026-02-23 10:00:00
129	5	3	Таунхаус	Двухуровневый таунхаус с террасой	ул. Спортивная, д. 10	Авсюнино	house	95.00	3	65000.00	month	active	2026-02-18 15:50:00
133	4	3	Дом с участком	Коттедж 200м2 с участком 15 соток	ул. Полевая, д. 10	д. Давыдово	house	200.00	5	85000.00	month	active	2026-02-24 12:00:00
130	4	2	Офисное помещение	Офис в бизнес-центре	ул. Комсомольская, д. 1А	Ликино-Дулёво	commercial	65.00	2	45000.00	month	active	2026-02-20 09:00:00
\.


--
-- TOC entry 4998 (class 0 OID 32819)
-- Dependencies: 224
-- Data for Name: property_photos; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.property_photos (photo_id, property_id, url, is_main, sequence_number) FROM stdin;
1	1	/static/photo1.png	t	1
2	1	/static/photo2.png	f	2
3	2	/static/photo2.png	t	1
4	3	/static/photo3.png	t	1
5	3	/static/photo4.png	f	2
6	4	/static/photo4.png	t	1
7	5	/static/photo5.png	t	1
8	5	/static/photo3.png	f	2
9	6	/static/photo6.png	t	1
15	5	/static/uploads/properties/5/3e36ac50326d4bdaa49f2eb7ff1ab749.jpg	f	3
16	133	/static/uploads/properties/133/68b92dcd416a44fe9ba7d8e1b71ddb73.png	t	1
17	133	/static/uploads/properties/133/7e0490f259fe40c2ba7f64e5971b2b93.png	f	2
18	133	/static/uploads/properties/133/fe74fa46ddff4b3490591ae9803e8c23.png	f	3
19	131	/static/uploads/properties/131/3b9f0a17120149ffadf620c9ed826248.jpg	t	1
20	131	/static/uploads/properties/131/a2250349056746ff8d592a6e814b2b0e.png	f	2
21	131	/static/uploads/properties/131/4cb390607697416aa65dffb5b804169d.jpg	f	3
22	129	/static/uploads/properties/129/56ca02d6aead4a07badd4affda43133e.png	t	1
23	129	/static/uploads/properties/129/87f76a43730e4419b0e5aaf492809a0a.jpg	f	2
24	132	/static/uploads/properties/132/2ce27461e6a44b518e8dd704d6d6556d.jpg	t	1
25	132	/static/uploads/properties/132/49d480a5036b41c19c689c2913920768.jpg	f	2
26	130	/static/uploads/properties/130/d04aaaecc04f40f793b09489fb7c9b2e.jpg	t	1
27	130	/static/uploads/properties/130/35437b8315714c9087c3c489faee34e5.jpg	f	2
\.


--
-- TOC entry 4994 (class 0 OID 32770)
-- Dependencies: 220
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (user_id, email, password_hash, avatar_url, full_name, user_type, contact_info, is_active, created_at) FROM stdin;
1	admin@rentease.ru	240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9	\N	Администратор Системы	admin	{"phone": "+7 (999) 123-45-67"}	t	2026-02-13 21:58:34.325669
2	agent.anna@rentease.ru	f44d1ac9bf0c69b083380b86dbdf3b73797150e3cca4820ac399f7917e607647	\N	Анна Петрова	agent	{"phone": "+7 (999) 234-56-78"}	t	2026-02-13 21:58:34.368669
4	owner.elena@mail.ru	43a0d17178a9d26c9e0fe9a74b0b45e38d32f27aed887a008a54bf6e033bf7b9	\N	Елена Смирнова	owner	{"phone": "+7 (999) 456-78-90"}	t	2026-02-13 21:58:34.368669
6	tenant.alex@mail.ru	b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33	\N	Алексей Кузнецов	tenant	{"phone": "+7 (999) 678-90-12"}	t	2026-02-13 21:58:34.368669
7	tenant.maria@mail.ru	b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33	\N	Мария Васильева	tenant	{"phone": "+7 (999) 789-01-23"}	t	2026-02-13 21:58:34.368669
9	vladislav.boev02@mail.ru	ef0d80812c1ef74190520c2a6b953e3a9989ad026610aea75a16b1139d036eb6	/static/uploads/avatars/1f7bf80f63bf4694bb1f80d1e5faaaca.jpg	Боев Владислав Максимович	tenant	{"inn": "4245343436", "city": "Орехово-Зуево", "phone": "+79964959390", "passport": "1234567890", "birth_date": "2007-01-02"}	t	2026-02-23 13:16:20.738342
11	myname@mail.ru	51bb9ba1a4744cf288c7ae72b5360e505ab9406e33b0e0871b5e969bc25b4fc5	/static/uploads/avatars/e4cb200e7e9e421c929c984cd2752e99.jpg	myname	tenant	{"phone": "+79256789011", "birth_date": "2000-01-02"}	t	2026-02-24 20:55:16.895943
5	owner.dmitry@mail.ru	43a0d17178a9d26c9e0fe9a74b0b45e38d32f27aed887a008a54bf6e033bf7b9	/static/uploads/avatars/d3881d4a1a76457eaf2280bd44657341.jpg	Дмитрий Иванов	owner	{"phone": "+7 (999) 567-89-01"}	t	2026-02-13 21:58:34.368669
3	agent.ivan@rentease.ru	f44d1ac9bf0c69b083380b86dbdf3b73797150e3cca4820ac399f7917e607647	\N	Иван Сидоров	agent	{"city": "Орехово-Зуево", "phone": "+7 (999) 345-67-89", "passport": "1234567890"}	t	2026-02-13 21:58:34.368669
\.


--
-- TOC entry 5019 (class 0 OID 0)
-- Dependencies: 225
-- Name: applications_application_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.applications_application_id_seq', 138, true);


--
-- TOC entry 5020 (class 0 OID 0)
-- Dependencies: 231
-- Name: audit_logs_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.audit_logs_log_id_seq', 1, false);


--
-- TOC entry 5021 (class 0 OID 0)
-- Dependencies: 227
-- Name: contracts_contract_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.contracts_contract_id_seq', 4, true);


--
-- TOC entry 5022 (class 0 OID 0)
-- Dependencies: 229
-- Name: messages_message_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.messages_message_id_seq', 12, true);


--
-- TOC entry 5023 (class 0 OID 0)
-- Dependencies: 221
-- Name: properties_property_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.properties_property_id_seq', 133, true);


--
-- TOC entry 5024 (class 0 OID 0)
-- Dependencies: 223
-- Name: property_photos_photo_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.property_photos_photo_id_seq', 27, true);


--
-- TOC entry 5025 (class 0 OID 0)
-- Dependencies: 219
-- Name: users_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_user_id_seq', 11, true);


--
-- TOC entry 4824 (class 2606 OID 32851)
-- Name: applications applications_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT applications_pkey PRIMARY KEY (application_id);


--
-- TOC entry 4832 (class 2606 OID 32941)
-- Name: audit_logs audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (log_id);


--
-- TOC entry 4826 (class 2606 OID 32885)
-- Name: contracts contracts_application_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT contracts_application_id_key UNIQUE (application_id);


--
-- TOC entry 4828 (class 2606 OID 32883)
-- Name: contracts contracts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT contracts_pkey PRIMARY KEY (contract_id);


--
-- TOC entry 4830 (class 2606 OID 32918)
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (message_id);


--
-- TOC entry 4820 (class 2606 OID 32807)
-- Name: properties properties_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.properties
    ADD CONSTRAINT properties_pkey PRIMARY KEY (property_id);


--
-- TOC entry 4822 (class 2606 OID 32831)
-- Name: property_photos property_photos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.property_photos
    ADD CONSTRAINT property_photos_pkey PRIMARY KEY (photo_id);


--
-- TOC entry 4816 (class 2606 OID 32787)
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- TOC entry 4818 (class 2606 OID 32785)
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (user_id);


--
-- TOC entry 4836 (class 2606 OID 32862)
-- Name: applications applications_agent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT applications_agent_id_fkey FOREIGN KEY (agent_id) REFERENCES public.users(user_id);


--
-- TOC entry 4837 (class 2606 OID 32852)
-- Name: applications applications_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT applications_property_id_fkey FOREIGN KEY (property_id) REFERENCES public.properties(property_id);


--
-- TOC entry 4838 (class 2606 OID 32857)
-- Name: applications applications_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT applications_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.users(user_id);


--
-- TOC entry 4845 (class 2606 OID 32942)
-- Name: audit_logs audit_logs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id);


--
-- TOC entry 4839 (class 2606 OID 32886)
-- Name: contracts contracts_application_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT contracts_application_id_fkey FOREIGN KEY (application_id) REFERENCES public.applications(application_id);


--
-- TOC entry 4840 (class 2606 OID 32901)
-- Name: contracts contracts_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT contracts_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.users(user_id);


--
-- TOC entry 4841 (class 2606 OID 32891)
-- Name: contracts contracts_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT contracts_property_id_fkey FOREIGN KEY (property_id) REFERENCES public.properties(property_id);


--
-- TOC entry 4842 (class 2606 OID 32896)
-- Name: contracts contracts_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT contracts_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.users(user_id);


--
-- TOC entry 4843 (class 2606 OID 32919)
-- Name: messages messages_from_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_from_user_id_fkey FOREIGN KEY (from_user_id) REFERENCES public.users(user_id);


--
-- TOC entry 4844 (class 2606 OID 32924)
-- Name: messages messages_to_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_to_user_id_fkey FOREIGN KEY (to_user_id) REFERENCES public.users(user_id);


--
-- TOC entry 4833 (class 2606 OID 32813)
-- Name: properties properties_agent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.properties
    ADD CONSTRAINT properties_agent_id_fkey FOREIGN KEY (agent_id) REFERENCES public.users(user_id) ON DELETE SET NULL;


--
-- TOC entry 4834 (class 2606 OID 32808)
-- Name: properties properties_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.properties
    ADD CONSTRAINT properties_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- TOC entry 4835 (class 2606 OID 32832)
-- Name: property_photos property_photos_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.property_photos
    ADD CONSTRAINT property_photos_property_id_fkey FOREIGN KEY (property_id) REFERENCES public.properties(property_id) ON DELETE CASCADE;


-- Completed on 2026-02-24 21:59:29

--
-- PostgreSQL database dump complete
--

\unrestrict IuLozB2xwoVxw2DZGMO8cHtlEG5mTwd5awaY2PH9l3TcodZSHjbOXweOGb80Xtr

