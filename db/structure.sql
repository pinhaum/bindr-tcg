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
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: unaccent; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public;


--
-- Name: EXTENSION unaccent; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION unaccent IS 'text search dictionary that removes accents';


--
-- Name: immutable_unaccent(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.immutable_unaccent(text) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
    AS $_$ SELECT public.unaccent('public.unaccent'::regdictionary, $1) $_$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: card_variants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.card_variants (
    id bigint NOT NULL,
    card_id bigint NOT NULL,
    set_id bigint NOT NULL,
    variant_code text NOT NULL,
    rarity text,
    art_kind text DEFAULT 'base'::text NOT NULL,
    image_url text,
    image_url_large text,
    illustrator text,
    last_seen_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT card_variants_art_kind_check CHECK ((art_kind = ANY (ARRAY['base'::text, 'alternate_art'::text, 'parallel'::text, 'manga'::text, 'promo'::text, 'other'::text])))
);


--
-- Name: card_variants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.card_variants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: card_variants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.card_variants_id_seq OWNED BY public.card_variants.id;


--
-- Name: cards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cards (
    id bigint NOT NULL,
    set_id bigint NOT NULL,
    card_number text NOT NULL,
    name text NOT NULL,
    card_type text NOT NULL,
    colors text[] DEFAULT '{}'::text[] NOT NULL,
    cost integer,
    life integer,
    power integer,
    counter integer,
    attributes_list text[] DEFAULT '{}'::text[] NOT NULL,
    traits text[] DEFAULT '{}'::text[] NOT NULL,
    block_icon integer,
    effect_text text,
    trigger_text text,
    last_seen_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT cards_card_type_check CHECK ((card_type = ANY (ARRAY['leader'::text, 'character'::text, 'event'::text, 'stage'::text])))
);


--
-- Name: cards_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.cards_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cards_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.cards_id_seq OWNED BY public.cards.id;


--
-- Name: import_runs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.import_runs (
    id bigint NOT NULL,
    source text NOT NULL,
    source_revision text NOT NULL,
    status text DEFAULT 'running'::text NOT NULL,
    started_at timestamp(6) without time zone NOT NULL,
    finished_at timestamp(6) without time zone,
    created_count integer DEFAULT 0 NOT NULL,
    updated_count integer DEFAULT 0 NOT NULL,
    failed_count integer DEFAULT 0 NOT NULL,
    error_log jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT import_runs_status_check CHECK ((status = ANY (ARRAY['running'::text, 'succeeded'::text, 'failed'::text])))
);


--
-- Name: import_runs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.import_runs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: import_runs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.import_runs_id_seq OWNED BY public.import_runs.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: sets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sets (
    id bigint NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    kind text DEFAULT 'other'::text NOT NULL,
    released_on date,
    base_set_size integer,
    total_set_size integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT sets_kind_check CHECK ((kind = ANY (ARRAY['booster'::text, 'starter'::text, 'extra_booster'::text, 'premium_booster'::text, 'promo'::text, 'other'::text])))
);


--
-- Name: sets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sets_id_seq OWNED BY public.sets.id;


--
-- Name: card_variants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.card_variants ALTER COLUMN id SET DEFAULT nextval('public.card_variants_id_seq'::regclass);


--
-- Name: cards id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cards ALTER COLUMN id SET DEFAULT nextval('public.cards_id_seq'::regclass);


--
-- Name: import_runs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_runs ALTER COLUMN id SET DEFAULT nextval('public.import_runs_id_seq'::regclass);


--
-- Name: sets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sets ALTER COLUMN id SET DEFAULT nextval('public.sets_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: card_variants card_variants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.card_variants
    ADD CONSTRAINT card_variants_pkey PRIMARY KEY (id);


--
-- Name: cards cards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cards
    ADD CONSTRAINT cards_pkey PRIMARY KEY (id);


--
-- Name: import_runs import_runs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_runs
    ADD CONSTRAINT import_runs_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: sets sets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sets
    ADD CONSTRAINT sets_pkey PRIMARY KEY (id);


--
-- Name: index_card_variants_on_card_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_card_variants_on_card_id ON public.card_variants USING btree (card_id);


--
-- Name: index_card_variants_on_card_id_and_variant_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_card_variants_on_card_id_and_variant_code ON public.card_variants USING btree (card_id, variant_code);


--
-- Name: index_card_variants_on_set_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_card_variants_on_set_id ON public.card_variants USING btree (set_id);


--
-- Name: index_card_variants_on_set_id_and_rarity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_card_variants_on_set_id_and_rarity ON public.card_variants USING btree (set_id, rarity);


--
-- Name: index_cards_on_attributes_list; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cards_on_attributes_list ON public.cards USING gin (attributes_list);


--
-- Name: index_cards_on_card_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_cards_on_card_number ON public.cards USING btree (card_number);


--
-- Name: index_cards_on_card_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cards_on_card_type ON public.cards USING btree (card_type);


--
-- Name: index_cards_on_colors; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cards_on_colors ON public.cards USING gin (colors);


--
-- Name: index_cards_on_cost; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cards_on_cost ON public.cards USING btree (cost);


--
-- Name: index_cards_on_counter; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cards_on_counter ON public.cards USING btree (counter);


--
-- Name: index_cards_on_effect_text_tsvector; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cards_on_effect_text_tsvector ON public.cards USING gin (to_tsvector('english'::regconfig, COALESCE(effect_text, ''::text)));


--
-- Name: index_cards_on_power; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cards_on_power ON public.cards USING btree (power);


--
-- Name: index_cards_on_set_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cards_on_set_id ON public.cards USING btree (set_id);


--
-- Name: index_cards_on_traits; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cards_on_traits ON public.cards USING gin (traits);


--
-- Name: index_cards_on_unaccent_name_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cards_on_unaccent_name_trgm ON public.cards USING gin (public.immutable_unaccent(name) public.gin_trgm_ops);


--
-- Name: index_sets_on_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sets_on_code ON public.sets USING btree (code);


--
-- Name: cards fk_rails_08603a186b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cards
    ADD CONSTRAINT fk_rails_08603a186b FOREIGN KEY (set_id) REFERENCES public.sets(id) ON DELETE RESTRICT;


--
-- Name: card_variants fk_rails_2d977c7759; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.card_variants
    ADD CONSTRAINT fk_rails_2d977c7759 FOREIGN KEY (card_id) REFERENCES public.cards(id) ON DELETE RESTRICT;


--
-- Name: card_variants fk_rails_9ad566cc75; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.card_variants
    ADD CONSTRAINT fk_rails_9ad566cc75 FOREIGN KEY (set_id) REFERENCES public.sets(id) ON DELETE RESTRICT;


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260919120100'),
('20260919120000');

