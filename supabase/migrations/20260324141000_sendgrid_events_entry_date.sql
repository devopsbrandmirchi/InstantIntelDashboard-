ALTER TABLE public.sendgrid_events
ADD COLUMN IF NOT EXISTS entry_date date NOT NULL DEFAULT CURRENT_DATE;

CREATE INDEX IF NOT EXISTS sendgrid_events_entry_date_idx
ON public.sendgrid_events (entry_date);
