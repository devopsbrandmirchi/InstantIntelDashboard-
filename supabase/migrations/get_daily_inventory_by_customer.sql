-- ============================================================
-- Daily inventory count per customer for the current month.
-- Returns (day, customer_id, cnt) for charting day-to-day by customer.
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_daily_inventory_by_customer()
RETURNS TABLE(day date, customer_id bigint, cnt bigint)
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT
    (pull_date::date) AS day,
    inventorydata.customer_id,
    COUNT(*)::bigint AS cnt
  FROM public.inventorydata
  WHERE pull_date::date >= date_trunc('month', current_date)::date
    AND pull_date::date < (date_trunc('month', current_date) + interval '1 month')::date
    AND inventorydata.customer_id IS NOT NULL
  GROUP BY pull_date::date, inventorydata.customer_id
  ORDER BY day, customer_id;
$$;

COMMENT ON FUNCTION public.get_daily_inventory_by_customer() IS 'Returns daily inventory counts per customer for current month (dashboard chart).';

GRANT EXECUTE ON FUNCTION public.get_daily_inventory_by_customer() TO authenticated;
