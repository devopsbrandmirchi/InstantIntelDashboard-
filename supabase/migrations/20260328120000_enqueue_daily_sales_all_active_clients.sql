-- Align enqueue_daily_sales_processing client filter with run_sales_daily_count:
-- some DBs store is_active as smallint (0/1); plain "is_active = TRUE" can exclude valid actives.
-- ============================================================

CREATE OR REPLACE FUNCTION public.enqueue_daily_sales_processing()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_run_date  date := CURRENT_DATE;
  v_count     integer;
BEGIN
  PERFORM pg_catalog.set_config('statement_timeout', '60000', true);

  DELETE FROM sales_processing_queue WHERE run_date = v_run_date;

  TRUNCATE TABLE saleprocessedvins;

  INSERT INTO sales_processing_queue (run_date, customer_id, customer_name, status)
  SELECT v_run_date, c.id::integer, c.full_name, 'pending'
  FROM   clients c
  WHERE  (
           CASE
             WHEN c.is_active IS TRUE  THEN 1
             WHEN c.is_active IS FALSE THEN 0
             ELSE COALESCE(c.is_active::integer, 0)
           END
         ) = 1
  ORDER  BY c.id;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

COMMENT ON FUNCTION public.enqueue_daily_sales_processing() IS
  'Enqueues one pending job per active client (is_active true or legacy 1). Truncates saleprocessedvins.';

-- Edge Function path: same active-client predicate as enqueue
CREATE OR REPLACE FUNCTION public.run_daily_sales_processing()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_client          RECORD;
  v_inserted        integer;
  v_start           timestamptz;
  v_elapsed         numeric(10,2);
  v_run_date        date    := CURRENT_DATE;
  v_truncate_log_id bigint;
  v_dealer_log_id   bigint;
  v_error_msg       text;
BEGIN
  PERFORM pg_catalog.set_config('statement_timeout', '0', true);
  PERFORM pg_catalog.set_config('lock_timeout', '0', true);

  INSERT INTO sales_processing_log (run_date, customer_id, customer_name, status, notes)
  VALUES (v_run_date, NULL, 'SYSTEM', 'running', 'Starting daily sales processing')
  RETURNING id INTO v_truncate_log_id;

  TRUNCATE TABLE saleprocessedvins;

  UPDATE sales_processing_log
  SET    status = 'success', ended_at = now(),
         elapsed_seconds = EXTRACT(EPOCH FROM (now() - started_at)),
         notes = 'Truncate complete'
  WHERE  id = v_truncate_log_id;

  FOR v_client IN
    SELECT c.id::integer AS id, c.full_name
    FROM   clients c
    WHERE  (
             CASE
               WHEN c.is_active IS TRUE  THEN 1
               WHEN c.is_active IS FALSE THEN 0
               ELSE COALESCE(c.is_active::integer, 0)
             END
           ) = 1
    ORDER  BY c.id
  LOOP
    v_start     := clock_timestamp();
    v_error_msg := NULL;

    INSERT INTO sales_processing_log (run_date, customer_id, customer_name, status)
    VALUES (v_run_date, v_client.id, v_client.full_name, 'running')
    RETURNING id INTO v_dealer_log_id;

    BEGIN
      v_inserted := process_dealer_sales(v_client.id, v_run_date);
      v_elapsed  := EXTRACT(EPOCH FROM (clock_timestamp() - v_start));

      UPDATE sales_processing_log
      SET    status = 'success', ended_at = clock_timestamp(),
             rows_inserted = v_inserted, elapsed_seconds = v_elapsed
      WHERE  id = v_dealer_log_id;

    EXCEPTION WHEN OTHERS THEN
      v_elapsed   := EXTRACT(EPOCH FROM (clock_timestamp() - v_start));
      v_error_msg := SQLERRM;

      UPDATE sales_processing_log
      SET    status = 'error', ended_at = clock_timestamp(),
             rows_inserted = 0, elapsed_seconds = v_elapsed,
             error_message = v_error_msg
      WHERE  id = v_dealer_log_id;
    END;

  END LOOP;
END;
$$;
