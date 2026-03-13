-- ============================================================
-- Daily sales count and total value for the current month.
-- Uses saleprocessedvins.final_sold_date and parses price for value.
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_daily_sales_current_month()
RETURNS TABLE(day date, cnt bigint, total_value numeric)
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT
    final_sold_date::date AS day,
    COUNT(*)::bigint AS cnt,
    COALESCE(SUM(
      COALESCE(
        (NULLIF(REGEXP_REPLACE(COALESCE(TRIM(price), '0'), '[^0-9.]', '', 'g'), '')::numeric),
        0
      )
    ), 0)::numeric AS total_value
  FROM public.saleprocessedvins
  WHERE final_sold_date IS NOT NULL
    AND final_sold_date::date >= date_trunc('month', current_date)::date
    AND final_sold_date::date < (date_trunc('month', current_date) + interval '1 month')::date
  GROUP BY final_sold_date::date
  ORDER BY day;
$$;

COMMENT ON FUNCTION public.get_daily_sales_current_month() IS 'Returns daily sales count and total value for current month (dashboard sales chart).';

GRANT EXECUTE ON FUNCTION public.get_daily_sales_current_month() TO authenticated;
