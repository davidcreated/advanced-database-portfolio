-- OjaHub Marketplace: helpers for running several real sessions from one script
-- dblink opens named connections (buyer_a, buyer_b, ...). Each is its own PostgreSQL backend with its
-- own transaction, so the scripts can interleave them step by step in a fixed, repeatable order.

CREATE EXTENSION IF NOT EXISTS dblink WITH SCHEMA public;

DROP SCHEMA IF EXISTS txdemo CASCADE;
CREATE SCHEMA txdemo;

CREATE TABLE txdemo.sessions (
    name     text PRIMARY KEY,
    pid      int  NOT NULL,
    pending  text
);

-- All demo orders are stamped 31 October 2026 18:00, after the generated data ends, so they are easy to clean up
CREATE FUNCTION txdemo.reset() RETURNS text
LANGUAGE plpgsql SET search_path = ojahub AS $$
BEGIN
    DELETE FROM payments  WHERE order_id IN (SELECT order_id FROM orders WHERE ordered_at >= timestamptz '2026-10-31');
    DELETE FROM shipments WHERE order_id IN (SELECT order_id FROM orders WHERE ordered_at >= timestamptz '2026-10-31');
    DELETE FROM orders    WHERE ordered_at >= timestamptz '2026-10-31';
    UPDATE products SET stock_qty = CASE product_id WHEN 2 THEN 12 WHEN 9 THEN 10 WHEN 13 THEN 18 WHEN 14 THEN 1 END
    WHERE product_id IN (2, 9, 13, 14);
    UPDATE products SET is_active = true WHERE product_id IN (90354, 92355);
    RETURN 'reset: demo orders removed, Galaxy A15 = 12, Leather Bag = 10, Pot Set = 18, Standing Fan = 1';
END;
$$;

-- Places an order with one item at the current list price. Stock is deliberately left to the caller.
CREATE FUNCTION txdemo.place_order(p_customer int, p_product int, p_qty int) RETURNS int
LANGUAGE sql SET search_path = ojahub AS $$
    WITH o AS (
        INSERT INTO orders (customer_id, shipping_address_id, order_status, ordered_at)
        SELECT p_customer, address_id, 'pending', timestamptz '2026-10-31 18:00'
        FROM addresses WHERE customer_id = p_customer AND is_default
        RETURNING order_id
    ), i AS (
        INSERT INTO order_items (order_id, product_id, quantity, unit_price)
        SELECT o.order_id, p_product, p_qty, p.unit_price FROM o, products p WHERE p.product_id = p_product
    )
    SELECT order_id FROM o
$$;

CREATE FUNCTION txdemo.wrap(statement text) RETURNS text
LANGUAGE sql IMMUTABLE AS $$
    SELECT CASE WHEN statement ~* '^\s*select'
                THEN 'SELECT coalesce(string_agg(row_to_json(t)::text, '' ''), ''(no rows)'') FROM (' || statement || ') t'
                ELSE statement END
$$;

CREATE FUNCTION txdemo.open(name text) RETURNS text
LANGUAGE plpgsql SET search_path = public, txdemo AS $$
DECLARE
    backend int;
BEGIN
    IF name = ANY (dblink_get_connections()) THEN
        PERFORM dblink_disconnect(name);
    END IF;
    PERFORM dblink_connect(name, format('dbname=%s application_name=%s', current_database(), name));
    PERFORM dblink_exec(name, 'SET search_path TO ojahub');
    SELECT pid INTO backend FROM dblink(name, 'SELECT pg_backend_pid()') AS t(pid int);
    INSERT INTO txdemo.sessions VALUES (name, backend, NULL)
    ON CONFLICT ON CONSTRAINT sessions_pkey DO UPDATE SET pid = EXCLUDED.pid, pending = NULL;
    RETURN format('[%s] connected as backend %s', name, backend);
END;
$$;

-- Runs one statement in a session and waits for it
CREATE FUNCTION txdemo.step(name text, statement text) RETURNS text
LANGUAGE plpgsql SET search_path = public, txdemo AS $$
DECLARE
    outcome text;
BEGIN
    BEGIN
        IF statement ~* '^\s*select' THEN
            SELECT v INTO outcome FROM dblink(name, txdemo.wrap(statement)) AS t(v text);
        ELSE
            outcome := dblink_exec(name, statement);
        END IF;
    EXCEPTION WHEN OTHERS THEN
        outcome := format('ERROR %s: %s', SQLSTATE, SQLERRM);
    END;
    RETURN format('[%s] %s  =>  %s', name, statement, outcome);
END;
$$;

-- Sends a statement without waiting, for steps that are expected to block on a lock
CREATE FUNCTION txdemo.send(name text, statement text) RETURNS text
LANGUAGE plpgsql SET search_path = public, txdemo AS $$
BEGIN
    PERFORM dblink_send_query(name, txdemo.wrap(statement));
    UPDATE txdemo.sessions s SET pending = statement WHERE s.name = send.name;
    RETURN format('[%s] %s  =>  sent', name, statement);
END;
$$;

-- Shows whether a session is stuck waiting for a lock, and which session holds it
CREATE FUNCTION txdemo.waiting(name text) RETURNS text
LANGUAGE plpgsql SET search_path = public, txdemo AS $$
DECLARE
    a       record;
    holders text;
BEGIN
    PERFORM pg_sleep(0.3);
    SELECT act.wait_event_type, act.wait_event, pg_blocking_pids(act.pid) AS blockers INTO a
    FROM pg_stat_activity act JOIN txdemo.sessions s ON s.pid = act.pid
    WHERE s.name = waiting.name;
    IF a.wait_event_type IS DISTINCT FROM 'Lock' THEN
        RETURN format('[%s] is not waiting', name);
    END IF;
    SELECT string_agg(s.name, ', ') INTO holders FROM txdemo.sessions s WHERE s.pid = ANY (a.blockers);
    RETURN format('[%s] is WAITING for a lock (%s: %s), held by %s', name, a.wait_event_type, a.wait_event, holders);
END;
$$;

-- Collects the result of a statement sent earlier, blocking until it finishes
CREATE FUNCTION txdemo.collect(name text) RETURNS text
LANGUAGE plpgsql SET search_path = public, txdemo AS $$
DECLARE
    outcome   text;
    statement text;
BEGIN
    SELECT s.pending INTO statement FROM txdemo.sessions s WHERE s.name = collect.name;
    BEGIN
        SELECT v INTO outcome FROM dblink_get_result(name) AS t(v text);
    EXCEPTION WHEN OTHERS THEN
        outcome := format('ERROR %s: %s', SQLSTATE, SQLERRM);
    END;
    BEGIN
        PERFORM * FROM dblink_get_result(name, false) AS t(v text);
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;
    UPDATE txdemo.sessions s SET pending = NULL WHERE s.name = collect.name;
    RETURN format('[%s] %s  =>  finished: %s', name, statement, outcome);
END;
$$;

CREATE FUNCTION txdemo.close_all() RETURNS text
LANGUAGE plpgsql SET search_path = public, txdemo AS $$
DECLARE
    c text;
BEGIN
    FOREACH c IN ARRAY coalesce(dblink_get_connections(), '{}') LOOP
        PERFORM dblink_disconnect(c);
    END LOOP;
    DELETE FROM txdemo.sessions;
    RETURN 'all sessions closed';
END;
$$;
