# SendGrid Event Webhook

Receives SendGrid’s POSTed JSON array (or single object) and inserts one row per event into `public.sendgrid_events`.

## Deploy

From the repo root (with Supabase CLI linked to your project):

```bash
supabase functions deploy sendgrid-webhook --no-verify-jwt
```

`--no-verify-jwt` is required so SendGrid can call the URL without a Supabase user JWT. Protect the endpoint with an optional shared secret (see below).

## Configure SendGrid

1. **Dashboard → Settings → Mail Settings → Event Webhook**
2. **HTTP POST URL:**  
   `https://<PROJECT_REF>.supabase.co/functions/v1/sendgrid-webhook`
3. Select the event types you need (delivered, open, click, etc.).
4. Save.

## Optional: shared secret

In **Supabase Dashboard → Project Settings → Edge Functions → Secrets**, set:

| Name | Purpose |
|------|---------|
| `SENDGRID_WEBHOOK_SECRET` | If set, requests must send this value as `Authorization: Bearer <secret>` **or** `X-Webhook-Secret: <secret>`. |

SendGrid does not send this by default; use it if you put a reverse proxy in front that adds the header, or for manual testing. For SendGrid’s [signed event webhook](https://docs.sendgrid.com/for-developers/tracking-events/getting-started-event-webhook-security-features), verify signatures in a future version of this function.

## Database

Apply migration `20260324140000_sendgrid_events.sql` so `sendgrid_events` exists before first webhook traffic.

## Verify

```bash
curl -X POST "https://<PROJECT_REF>.supabase.co/functions/v1/sendgrid-webhook" \
  -H "Content-Type: application/json" \
  -d '[{"email":"test@example.com","event":"processed","timestamp":1710000000}]'
```

Then:

```sql
SELECT * FROM public.sendgrid_events ORDER BY id DESC LIMIT 5;
```
