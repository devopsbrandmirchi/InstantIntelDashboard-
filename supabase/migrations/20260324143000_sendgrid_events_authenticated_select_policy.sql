ALTER TABLE public.sendgrid_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS sendgrid_events_authenticated_select ON public.sendgrid_events;

CREATE POLICY sendgrid_events_authenticated_select
ON public.sendgrid_events
FOR SELECT
TO authenticated
USING (true);
