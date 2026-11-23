# AERO Mail & Studio

A full-stack starter for a branded mail workspace and a visual website builder. It is designed for deployment as a **Next.js Node web service on Render**, with **Supabase** for authentication/database/storage and **Resend** for outbound email and inbound email processing.

This is a usable first release, not a drop-in replacement for the complete Gmail/Zoho infrastructure. The app creates application-managed inboxes and routes mail through Resend. It does **not** create independent IMAP/POP mail servers or standalone mailbox passwords. A signed-in Supabase user can own multiple email addresses inside this workspace.

## Included

### Mail workspace
- Sign-up and sign-in using Supabase Auth.
- Add and verify email domains through the Resend Domains API.
- Display DNS records returned by Resend.
- Create addresses such as `hello@yourdomain.com` on verified domains.
- Send email through Resend, including CC, BCC and file attachments.
- Receive inbound messages through a signed Resend webhook.
- Retrieve inbound message bodies from Resend and store them in Supabase.
- Store inbound attachments in a private Supabase Storage bucket and provide authenticated, expiring download links.
- Inbox, Sent, All Mail, Starred, search, read/unread state and message view.

### Website studio
- Create websites and multiple pages.
- Drag sections from the block palette into the page canvas.
- Add Hero, Text, Image, Feature Cards, Button and Contact sections.
- Edit page titles, page URL slugs and SEO title/description fields.
- Edit section copy, buttons, image URLs and contact addresses.
- Reorder or delete sections, save, preview and publish.
- Enable/disable built-in plugin slots (SEO toolkit, Contact block, Gallery and Analytics slot).
- Connect a custom website domain using a DNS TXT ownership check.
- Serve published pages on `/p/{site-slug}` or a verified custom hostname.

The plugin toggles are controlled built-in extensions; this starter intentionally does not execute arbitrary third-party plugin code on the server.

---

# 1. Create and configure Supabase

1. Create a project at <https://supabase.com/>.
2. Open **SQL Editor → New query**.
3. Paste and run `supabase/schema.sql` in full.
4. Open **Project Settings → API** and copy:
   - Project URL
   - Publishable key (or legacy anon public key)
   - `service_role` key
5. In **Authentication → URL Configuration**, set your deployed app URL as the Site URL, for example `https://mail.aero.ist`.
6. Add the same host to Redirect URLs. During development add `http://localhost:3000/**`.
7. In **Authentication → Providers → Email**, enable email/password sign-in. Enable email confirmation for public sign-ups. Configure the Auth email templates/SMTP before launch so verification and password-reset emails are reliably delivered.

**Never expose `SUPABASE_SERVICE_ROLE_KEY` in browser code.** The project only uses it in the inbound webhook route.

# 2. Configure Resend

1. Create a Resend account at <https://resend.com/>.
2. Create an API key with the permissions needed for domain management, sending and receiving.
3. Copy the API key. The app will create a Resend domain record when a user adds a domain.
4. In the Resend dashboard, open **Webhooks → Add Webhook**.
5. Set the endpoint to:

   `https://mail.aero.ist/api/webhooks/resend`

6. Subscribe to the **`email.received`** event only (additional event handling can be added later).
7. Copy the webhook signing secret (`whsec_...`). This is `RESEND_WEBHOOK_SECRET`.
8. For each domain, configure all sending and receiving DNS records shown by Resend. The application displays the DNS records returned by the Resend Domains API. Resend's receiving MX setup may also be shown in its Receiving dashboard; add that record too when Resend requires a separate inbound MX configuration.

The webhook signature is verified before accepting an inbound message. The webhook payload contains metadata, so the application then calls the Resend Receiving API to retrieve the email body and attachment download information.

## Important MX warning

An MX record controls where email for a domain is delivered. If `aero.ist` already receives mail through another provider, replacing its MX record with Resend may stop that provider receiving new messages. For initial testing, use a dedicated email subdomain such as `mail.example.com` or `team.example.com`, and create addresses on that subdomain. Only move the root domain after planning the mail migration.

# 3. Configure environment variables

Copy `.env.example` to `.env.local` for local testing, or add the values in Render's Environment page.

```env
NEXT_PUBLIC_APP_URL=https://mail.aero.ist
NEXT_PUBLIC_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=YOUR_SUPABASE_PUBLISHABLE_OR_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY=YOUR_SUPABASE_SERVICE_ROLE_KEY
RESEND_API_KEY=re_your_actual_key
RESEND_WEBHOOK_SECRET=whsec_your_webhook_secret
RESEND_REGION=us-east-1
APP_HOSTNAMES=mail.aero.ist,your-service.onrender.com
```

`APP_HOSTNAMES` is a comma-separated list of hosts used by the app itself. Leave custom website domains out of this list so the host-routing middleware can resolve them to their published website.

# 4. Run locally

Use Node.js 22 or newer.

```bash
npm install
cp .env.example .env.local
# Edit .env.local with your real credentials
npm run dev
```

Open <http://localhost:3000>.

To test inbound email locally, expose your local app with a secure HTTPS tunnel and temporarily set the Resend webhook endpoint to:

`https://YOUR-TUNNEL/api/webhooks/resend`

# 5. Deploy to Render

1. Create a GitHub repository and upload the contents of this folder.
2. In Render, choose **New → Web Service** and connect the repository.
3. Select **Node** runtime. The included `render.yaml` selects the `starter` plan; review Render's current pricing and available plans before creating the service.
4. Build command: `npm install && npm run build`
5. Start command: `npm start`
6. Add all environment variables from section 3 in Render → Environment.
7. Deploy the service.
8. Add `mail.aero.ist` under Render → your service → Settings → Custom Domains, then follow Render's current DNS instructions at your DNS provider.
9. Set `NEXT_PUBLIC_APP_URL=https://mail.aero.ist` and ensure `APP_HOSTNAMES` includes `mail.aero.ist` and the Render service hostname; save/redeploy.
10. Update Supabase Auth Site URL and Redirect URLs to `https://mail.aero.ist`.
11. Register the public Resend webhook URL shown in section 2.

This app uses server routes, cookies, webhooks and host-based routing, so deploy it as a **Render Web Service**, not a static site. Render's official Next.js deployment guide: <https://render.com/docs/deploy-nextjs-app>.

# 6. Create your first email address

1. Sign in to your workspace.
2. Open **Domains & addresses**.
3. Enter the domain you control, such as `aero.ist`, and click **Add domain**.
4. Copy the DNS records shown in the dashboard into your domain registrar/DNS provider exactly. Do not invent or modify record values.
5. Add the inbound/receiving MX record from Resend's Receiving dashboard if it is shown separately.
6. Wait for DNS propagation and click **Verify DNS**. Verification status is reported by Resend.
7. Open **Mail centre → Add address**.
8. Choose an alias such as `j`, `hello` or `support`, select the verified domain, and create it.
9. Use **Compose email** to send. Send a test message from an external account to the new address to test inbound routing.

A mailbox address created in the app is an address that the app routes to a signed-in workspace user's inbox. It is not a separately provisioned IMAP account with a distinct mailbox password.

# 7. Publish a website and connect a custom domain

1. Open **Website studio → Create your first website**.
2. Drag a section from the left palette onto the canvas (or click the section).
3. Select a section and edit its fields in the right inspector.
4. Use the up/down controls to reorder sections. Add pages in the left panel.
5. Save changes, select Preview, and click Publish.
6. A published site is available at `https://mail.aero.ist/p/YOUR-SITE-SLUG`.
7. To connect an external website domain, enter it in **Website settings → Connect external domain** and save.
8. Add the displayed TXT record at `_aeromail-verification.YOUR-DOMAIN` and click Verify TXT record.
9. Add the external hostname to your Render service's Custom Domains list and configure the web A/CNAME/ALIAS records that Render instructs you to use. Do not assume the same DNS record works for every registrar or for an apex/root domain.
10. Once Render provisions HTTPS and the domain verification succeeds, the middleware routes visitors on that hostname to the published site.

The website domain connection is independent of email MX configuration. Connecting a website should not require changing email MX records.

---

# 8. Production launch checklist

Before accepting public customers, complete these items:

- Restrict sign-ups or add invite-only onboarding until abuse controls and billing are ready.
- Set a sending rate limit per user, mailbox and domain; add daily quotas and complaint/bounce suppression.
- Configure SPF, DKIM and DMARC correctly and monitor sender reputation.
- Add a proper spam/virus scanning and quarantine workflow for inbound attachments.
- Add account recovery, MFA, user support, audit logs and domain ownership review.
- Add monitoring for webhook failures and retry events; confirm the Resend webhook responds with 2xx after processing.
- Set storage retention, backups, deletion/export controls and a privacy policy.
- Add a queue/background worker for high-volume attachment processing and long-running tasks.
- Validate Render, Supabase and Resend usage limits and pricing for the expected volume.

## Current functional boundaries

- Sending and receiving depend on a verified Resend account, valid domain DNS and provider quotas.
- The app does not provide SMTP/IMAP/POP endpoints, calendar, contacts sync, Gmail-style spam filtering, push notifications, or full mail-server administration.
- Inbound HTML is stored but rendered as plain text in the inbox for safety.
- The first page builder supports a controlled set of blocks and built-in plugin slots. It is not yet a full WordPress plugin marketplace or a general-purpose arbitrary-code execution environment.
- Website custom-domain activation also requires adding each hostname to your Render service and configuring the DNS records Render gives you.

## Key reference documentation

- Resend inbound email and webhook flow: <https://resend.com/docs>
- Supabase server-side authentication: <https://supabase.com/docs/guides/auth/server-side>
- Render Next.js web service deployment: <https://render.com/docs/deploy-nextjs-app>
