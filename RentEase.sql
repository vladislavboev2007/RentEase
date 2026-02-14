--
-- PostgreSQL database dump
--

\restrict TCsWAAEvM1zRp2xv2fk37S2eaokIFcBA4qpl6EGVgHXaswGs7XGTivFmzYg8Ciz

-- Dumped from database version 18.1
-- Dumped by pg_dump version 18.1

-- Started on 2026-02-13 22:06:35

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
-- TOC entry 5009 (class 0 OID 0)
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
-- TOC entry 5010 (class 0 OID 0)
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
-- TOC entry 5011 (class 0 OID 0)
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
-- TOC entry 5012 (class 0 OID 0)
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
-- TOC entry 5013 (class 0 OID 0)
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
-- TOC entry 5014 (class 0 OID 0)
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
-- TOC entry 5015 (class 0 OID 0)
-- Dependencies: 219
-- Name: users_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_user_id_seq OWNED BY public.users.user_id;


--
-- TOC entry 4794 (class 2604 OID 32841)
-- Name: applications application_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.applications ALTER COLUMN application_id SET DEFAULT nextval('public.applications_application_id_seq'::regclass);


--
-- TOC entry 4803 (class 2604 OID 32933)
-- Name: audit_logs log_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_logs ALTER COLUMN log_id SET DEFAULT nextval('public.audit_logs_log_id_seq'::regclass);


--
-- TOC entry 4797 (class 2604 OID 32871)
-- Name: contracts contract_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contracts ALTER COLUMN contract_id SET DEFAULT nextval('public.contracts_contract_id_seq'::regclass);


--
-- TOC entry 4800 (class 2604 OID 32910)
-- Name: messages message_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages ALTER COLUMN message_id SET DEFAULT nextval('public.messages_message_id_seq'::regclass);


--
-- TOC entry 4789 (class 2604 OID 32792)
-- Name: properties property_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.properties ALTER COLUMN property_id SET DEFAULT nextval('public.properties_property_id_seq'::regclass);


--
-- TOC entry 4792 (class 2604 OID 32822)
-- Name: property_photos photo_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.property_photos ALTER COLUMN photo_id SET DEFAULT nextval('public.property_photos_photo_id_seq'::regclass);


--
-- TOC entry 4785 (class 2604 OID 32773)
-- Name: users user_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN user_id SET DEFAULT nextval('public.users_user_id_seq'::regclass);


--
-- TOC entry 4997 (class 0 OID 32838)
-- Dependencies: 226
-- Data for Name: applications; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.applications (application_id, property_id, tenant_id, agent_id, message, desired_date, duration_days, answer, status, created_at) FROM stdin;
1	1	6	2	Интересует квартира, хотел бы посмотреть в выходные	2024-06-15	365	\N	pending	2026-02-13 21:58:34.485672
2	2	7	2	Очень понравилась квартира, готов заключить договор	2024-06-10	180	Принято, жду вас в пятницу	approved	2026-02-13 21:58:34.48767
3	3	6	3	Дороговато, есть возможность торга?	2024-06-20	30	Цена фиксированная	rejected	2026-02-13 21:58:34.488671
\.


--
-- TOC entry 5003 (class 0 OID 32930)
-- Dependencies: 232
-- Data for Name: audit_logs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.audit_logs (log_id, user_id, action, entity_type, entity_id, details, created_at) FROM stdin;
\.


--
-- TOC entry 4999 (class 0 OID 32868)
-- Dependencies: 228
-- Data for Name: contracts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.contracts (contract_id, application_id, property_id, tenant_id, owner_id, contract_type, start_date, end_date, total_amount, signing_status, created_at) FROM stdin;
\.


--
-- TOC entry 5001 (class 0 OID 32907)
-- Dependencies: 230
-- Data for Name: messages; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.messages (message_id, from_user_id, to_user_id, content, is_read, created_at) FROM stdin;
\.


--
-- TOC entry 4993 (class 0 OID 32789)
-- Dependencies: 222
-- Data for Name: properties; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.properties (property_id, owner_id, agent_id, title, description, address, city, property_type, area, rooms, price, interval_pay, status, created_at) FROM stdin;
1	4	2	Уютная квартира в центре	Просторная квартира с видом на набережную, отличный ремонт, вся техника новая	ул. Тверская, д. 10, кв. 45	Москва	apartment	65.50	2	45000.00	month	active	2026-02-13 21:58:34.38867
2	4	2	Студия в новостройке	Современная студия с дизайнерским ремонтом, есть всё для комфортного проживания	ул. Ленина, д. 15	Москва	apartment	32.00	1	35000.00	month	active	2026-02-13 21:58:34.38867
3	5	3	Загородный дом у озера	Двухэтажный дом с участком, камин, сауна, отличное место для отдыха	пос. Репино, ул. Лесная, д. 5	Ленинградская область	house	150.00	4	120000.00	month	active	2026-02-13 21:58:34.41967
4	5	3	Квартира на Невском	Квартира в историческом центре, высокие потолки, лепнина, паркет	Невский пр., д. 25, кв. 12	Санкт-Петербург	apartment	95.00	3	75000.00	month	active	2026-02-13 21:58:34.41967
5	4	2	Коммерческое помещение	Помещение свободного назначения на первом этаже жилого дома	пр. Мира, д. 30	Новосибирск	commercial	85.00	2	60000.00	month	active	2026-02-13 21:58:34.420669
6	5	3	Квартира у метро	Уютная квартира в 5 минутах от метро, хороший ремонт, есть мебель	ул. Гагарина, д. 7	Екатеринбург	apartment	55.00	2	38000.00	month	active	2026-02-13 21:58:34.420669
\.


--
-- TOC entry 4995 (class 0 OID 32819)
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
\.


--
-- TOC entry 4991 (class 0 OID 32770)
-- Dependencies: 220
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (user_id, email, password_hash, avatar_url, full_name, user_type, contact_info, is_active, created_at) FROM stdin;
1	admin@rentease.ru	240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9	\N	Администратор Системы	admin	{"phone": "+7 (999) 123-45-67"}	t	2026-02-13 21:58:34.325669
2	agent.anna@rentease.ru	f44d1ac9bf0c69b083380b86dbdf3b73797150e3cca4820ac399f7917e607647	\N	Анна Петрова	agent	{"phone": "+7 (999) 234-56-78"}	t	2026-02-13 21:58:34.368669
3	agent.ivan@rentease.ru	f44d1ac9bf0c69b083380b86dbdf3b73797150e3cca4820ac399f7917e607647	\N	Иван Сидоров	agent	{"phone": "+7 (999) 345-67-89"}	t	2026-02-13 21:58:34.368669
4	owner.elena@mail.ru	43a0d17178a9d26c9e0fe9a74b0b45e38d32f27aed887a008a54bf6e033bf7b9	\N	Елена Смирнова	owner	{"phone": "+7 (999) 456-78-90"}	t	2026-02-13 21:58:34.368669
5	owner.dmitry@mail.ru	43a0d17178a9d26c9e0fe9a74b0b45e38d32f27aed887a008a54bf6e033bf7b9	\N	Дмитрий Иванов	owner	{"phone": "+7 (999) 567-89-01"}	t	2026-02-13 21:58:34.368669
6	tenant.alex@mail.ru	b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33	\N	Алексей Кузнецов	tenant	{"phone": "+7 (999) 678-90-12"}	t	2026-02-13 21:58:34.368669
7	tenant.maria@mail.ru	b4f08230cddd4c1bc52a876e12db534f8b40eedb08ba78a5501d1cdf8eb8cb33	\N	Мария Васильева	tenant	{"phone": "+7 (999) 789-01-23"}	t	2026-02-13 21:58:34.368669
\.


--
-- TOC entry 5016 (class 0 OID 0)
-- Dependencies: 225
-- Name: applications_application_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.applications_application_id_seq', 3, true);


--
-- TOC entry 5017 (class 0 OID 0)
-- Dependencies: 231
-- Name: audit_logs_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.audit_logs_log_id_seq', 1, false);


--
-- TOC entry 5018 (class 0 OID 0)
-- Dependencies: 227
-- Name: contracts_contract_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.contracts_contract_id_seq', 1, false);


--
-- TOC entry 5019 (class 0 OID 0)
-- Dependencies: 229
-- Name: messages_message_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.messages_message_id_seq', 1, false);


--
-- TOC entry 5020 (class 0 OID 0)
-- Dependencies: 221
-- Name: properties_property_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.properties_property_id_seq', 6, true);


--
-- TOC entry 5021 (class 0 OID 0)
-- Dependencies: 223
-- Name: property_photos_photo_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.property_photos_photo_id_seq', 9, true);


--
-- TOC entry 5022 (class 0 OID 0)
-- Dependencies: 219
-- Name: users_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_user_id_seq', 7, true);


--
-- TOC entry 4821 (class 2606 OID 32851)
-- Name: applications applications_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT applications_pkey PRIMARY KEY (application_id);


--
-- TOC entry 4829 (class 2606 OID 32941)
-- Name: audit_logs audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (log_id);


--
-- TOC entry 4823 (class 2606 OID 32885)
-- Name: contracts contracts_application_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT contracts_application_id_key UNIQUE (application_id);


--
-- TOC entry 4825 (class 2606 OID 32883)
-- Name: contracts contracts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT contracts_pkey PRIMARY KEY (contract_id);


--
-- TOC entry 4827 (class 2606 OID 32918)
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (message_id);


--
-- TOC entry 4817 (class 2606 OID 32807)
-- Name: properties properties_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.properties
    ADD CONSTRAINT properties_pkey PRIMARY KEY (property_id);


--
-- TOC entry 4819 (class 2606 OID 32831)
-- Name: property_photos property_photos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.property_photos
    ADD CONSTRAINT property_photos_pkey PRIMARY KEY (photo_id);


--
-- TOC entry 4813 (class 2606 OID 32787)
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- TOC entry 4815 (class 2606 OID 32785)
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (user_id);


--
-- TOC entry 4833 (class 2606 OID 32862)
-- Name: applications applications_agent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT applications_agent_id_fkey FOREIGN KEY (agent_id) REFERENCES public.users(user_id);


--
-- TOC entry 4834 (class 2606 OID 32852)
-- Name: applications applications_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT applications_property_id_fkey FOREIGN KEY (property_id) REFERENCES public.properties(property_id);


--
-- TOC entry 4835 (class 2606 OID 32857)
-- Name: applications applications_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT applications_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.users(user_id);


--
-- TOC entry 4842 (class 2606 OID 32942)
-- Name: audit_logs audit_logs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id);


--
-- TOC entry 4836 (class 2606 OID 32886)
-- Name: contracts contracts_application_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT contracts_application_id_fkey FOREIGN KEY (application_id) REFERENCES public.applications(application_id);


--
-- TOC entry 4837 (class 2606 OID 32901)
-- Name: contracts contracts_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT contracts_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.users(user_id);


--
-- TOC entry 4838 (class 2606 OID 32891)
-- Name: contracts contracts_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT contracts_property_id_fkey FOREIGN KEY (property_id) REFERENCES public.properties(property_id);


--
-- TOC entry 4839 (class 2606 OID 32896)
-- Name: contracts contracts_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT contracts_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.users(user_id);


--
-- TOC entry 4840 (class 2606 OID 32919)
-- Name: messages messages_from_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_from_user_id_fkey FOREIGN KEY (from_user_id) REFERENCES public.users(user_id);


--
-- TOC entry 4841 (class 2606 OID 32924)
-- Name: messages messages_to_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_to_user_id_fkey FOREIGN KEY (to_user_id) REFERENCES public.users(user_id);


--
-- TOC entry 4830 (class 2606 OID 32813)
-- Name: properties properties_agent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.properties
    ADD CONSTRAINT properties_agent_id_fkey FOREIGN KEY (agent_id) REFERENCES public.users(user_id) ON DELETE SET NULL;


--
-- TOC entry 4831 (class 2606 OID 32808)
-- Name: properties properties_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.properties
    ADD CONSTRAINT properties_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- TOC entry 4832 (class 2606 OID 32832)
-- Name: property_photos property_photos_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.property_photos
    ADD CONSTRAINT property_photos_property_id_fkey FOREIGN KEY (property_id) REFERENCES public.properties(property_id) ON DELETE CASCADE;


-- Completed on 2026-02-13 22:06:35

--
-- PostgreSQL database dump complete
--

\unrestrict TCsWAAEvM1zRp2xv2fk37S2eaokIFcBA4qpl6EGVgHXaswGs7XGTivFmzYg8Ciz

