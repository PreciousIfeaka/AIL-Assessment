# Zuri Home & Style: WhatsApp Order Automation

| | |
|---|---|
| **Assessment** | Angel Intelligence Limited, Lead Systems & Automation Engineer, Version 1.1 |
| **Candidate** | Precious Enuagwune |
| **Context chosen** | Retail and order enquiries |
| **Stack** | n8n (self-hosted), PostgreSQL, Telegram, Docker Compose |

This package contains a working, end-to-end prototype of a WhatsApp automation system for a fictional Lagos online retailer. Customers message the business on WhatsApp. The system answers routine questions at once (prices, stock, delivery, order status, payment details), guides new orders step by step, and hands everything else to the right staff member on Telegram, with a full audit log and a manager dashboard.

**WhatsApp itself is simulated** (the brief allows this). Messages arrive as HTTP requests in the exact format the WhatsApp Cloud API uses, and replies are written to a database table instead of being sent. Section 3 lists exactly what is real and what is simulated.

---

## 1. Reading order (10 minutes)

1. `01_Written_Submission.pdf`, Sections A and B: the problem and the architecture.
2. This README, Sections 3 and 4: what is real, and how a message flows.
3. `04_Demo_Video_Link.txt`: the 5 to 8 minute walkthrough.
4. To reproduce it yourself, follow Section 6 (setup) and Section 7 (tests). Setup takes about 20 to 30 minutes, and the full automated test run takes about 4 minutes.

---

## 2. What is where

```
CandidateName_AIL_Assessment/
├── README.md                      <- this file
├── 01_Written_Submission.pdf      <- Items A, B, E, F, G, H
├── 02_Prototype/
│   ├── docker-compose.yaml        <- n8n + PostgreSQL containers
│   ├── .env.example               <- settings template (placeholders only, no secrets)
│   ├── db/
│   │   ├── schema.sql             <- creates the 8 tables
│   │   ├── seed.sql               <- synthetic data: 20 products, 3 customers, 6 orders
│   │   ├── setup.sh               <- creates the tables and loads the seed data
│   │   ├── psql.sh, env.sh        <- small helpers used by the scripts
│   ├── workflows/                 <- n8n workflow exports (JSON), one file per workflow
│   ├── test_inputs/               <- synthetic WhatsApp payloads (JSON) used by the tests
│   └── tests/                     <- optional command-line test scripts (see 7.6)
├── 03_Test_Record.pdf             <- test table: input, expected result, actual result
└── 04_Demo_Video_Link.txt         <- link to the recorded demonstration
```

### The n8n workflows

| Workflow | Starts when | What it does |
|---|---|---|
| **WA-Inbound** | A message arrives (webhook POST) | The main handler: validates, de-duplicates, classifies and answers each message |
| **SW-Config** | Called by other workflows | All business rules in one place: keywords, hours, delivery fees, routing, message wording |
| **SW-Reply** | Called by other workflows | Writes each reply to the outbox and the audit log (the simulated WhatsApp send) |
| **SW-Escalate** | Called by other workflows | Chooses the right staff member, sets a 30-minute deadline, sends the Telegram alert |
| **Staff-Actions** | Staff action (webhook POST, token protected) | Lets staff claim and resolve escalated cases |
| **SLA-Watchdog** | Every 10 minutes | Reminds the manager about overdue cases (business hours only) |
| **Dashboard** | A browser opens the page (login required) | Shows volume, escalation rate, unresolved cases and response times |
| **Error-Handler** | Any workflow fails | Alerts the administrator on Telegram and logs the fault |
| **Test-Runner, Test-Send, Test-Staff-Action, Test-Helpers** | You click Execute | Testing only. Run the whole suite, send one message, claim/resolve a case, and show the data |

The three workflows starting with `SW-` are **sub-workflows**: reusable pieces that other workflows call.

### The database tables

| Table | Holds |
|---|---|
| `products` | The catalogue: name, price, stock, search keywords |
| `orders` | Orders and their status (seeded ones plus orders the bot creates) |
| `contacts` | The only table with phone numbers (fictional ones), needed to send replies |
| `messages` | Every inbound message, with its classified intent and confidence |
| `conversation_state` | Where each customer is in a multi-step conversation (for example, an order in progress) |
| `escalations` | Cases handed to staff: category, assignee, deadline, status |
| `outbox` | Every reply the system would send on WhatsApp |
| `audit_log` | A timestamped record of everything that happened |

---

## 3. What is real and what is simulated

| Component | Status | Detail |
|---|---|---|
| Inbound WhatsApp message | **Simulated** | An HTTP POST to the WA-Inbound webhook, in the WhatsApp Cloud API payload format. In production, Meta calls the same webhook. |
| Outgoing WhatsApp reply | **Simulated** | Written to the `outbox` table with status `simulated_sent`. In production this step becomes a call to Meta's Graph API. |
| Staff claim and resolve actions | **Simulated** | An HTTP request to Staff-Actions (use the Test-Staff-Action workflow). In production these are Telegram buttons. |
| Telegram staff alerts | **Working** | A real Telegram bot sends real messages. |
| Classification, order intake, escalation routing, SLA watchdog, dashboard, audit log, database, error handling | **Working** | All run for real. |
| Meta webhook verification handshake, HMAC signature check, live sending | **Not included** | Production steps, described in Sections F and H of the written submission. |

---

## 4. How the system works

### The life of one message

1. The message reaches the **WA-Inbound** webhook.
2. The payload is checked. The sender's phone number is turned into a keyed hash (HMAC-SHA256 with a secret "pepper"), and a masked version (like `23480****222`) is used in logs.
3. The message is stored. Each WhatsApp message ID can be stored only once, so a **duplicate** is stopped here and logged.
4. **Interrupts** are checked first: a request for a person ("agent"), refund or complaint words, or "cancel" are handled before anything else.
5. If the customer is in the middle of a conversation (for example, giving an address for an order), the message continues that flow. Otherwise the intent is chosen by **weighted keyword scoring**. Below a confidence of 0.6 the message goes to a human.
6. The matching handler runs, and **SW-Reply** records the reply and the audit entries.
7. Anything needing a person goes through **SW-Escalate**: it picks the staff member by category, sets a 30-minute deadline and sends a Telegram alert.
8. **SLA-Watchdog** reminds the manager about cases still open after their deadline.
9. The **Dashboard** reads all of this and shows it on one page.

### The six intents

| Intent | What the system does |
|---|---|
| `product_enquiry` | Looks up price and stock |
| `order_status` | Checks the order ID format (`ZH-12345`) and that it belongs to the sender, then replies with its status |
| `place_order` | Asks for product, quantity, address and name, confirms the total, then creates the order and alerts sales |
| `delivery_info` | Replies with delivery zones, fees and timelines |
| `payment_info` | Replies with bank details. A message saying the customer has paid goes to staff |
| `complaint_refund` | Always escalated to the manager as high priority |

Unrecognised or low-confidence messages, requests for a person, and images or voice notes also go to a human.

---

## 5. Requirements and versions

| Software | Version | Needed for |
|---|---|---|
| Docker Engine | Any recent version (v24+ recommended) | Running n8n and PostgreSQL |
| Docker Compose | v2 (the `docker compose` command) | Starting the containers |
| n8n | **2.46.2** (self-hosted; pinned in `docker-compose.yaml`) | The workflows |
| PostgreSQL | 16 recommended (13 or newer required) | The database |
| bash and `openssl` | Any recent version, on your own computer | `db/setup.sh` (it computes the phone hashes) |
| Telegram | A free account and a bot | Staff alerts |
| curl, jq | Optional | Only the command-line test scripts in 7.6 |

You will also need about 2 GB of free memory and port `5678` free. PostgreSQL is **not** exposed outside Docker, so port 5432 is not needed.

---

## 6. Setup, step by step

Run all commands from the `02_Prototype` folder.

### 6.1 Create your settings file

```bash
cp .env.example .env
```

Open `.env` and fill in the values. The file contains placeholders only. **Never commit the real `.env`.**

```
# --- n8n's own database (stores workflows and credentials) ---
DB_POSTGRESDB_DATABASE=n8n
DB_POSTGRESDB_USERNAME=<database user>
DB_POSTGRESDB_PASSWORD=<choose a password>
# (use the same variable names your docker-compose.yml expects)

# --- The Zuri data database (separate from n8n's own) ---
ZURI_DB_NAME=zuri

# --- Secrets: generate each with   openssl rand -hex 32 ---
PHONE_PEPPER=<random string>            # keys the phone-number hash. Do NOT change it later.
N8N_ENCRYPTION_KEY=<random string>      # protects saved credentials. Keep a copy.

# --- n8n behaviour ---
GENERIC_TIMEZONE=Africa/Lagos
TZ=Africa/Lagos
NODE_FUNCTION_ALLOW_BUILTIN=crypto
N8N_BLOCK_ENV_ACCESS_IN_NODE=false
EXECUTIONS_DATA_SAVE_ON_SUCCESS=all      # "all" lets you inspect runs while testing; use "none" in production
EXECUTIONS_DATA_PRUNE=true
EXECUTIONS_DATA_MAX_AGE=168              # hours: execution history is deleted after 7 days
```

All of these must reach the **n8n container** (through `env_file` or `environment` in `docker-compose.yml`). If you use n8n's separate Code-node runner container, `NODE_FUNCTION_ALLOW_BUILTIN` must reach that container too.

### 6.2 Start the containers

```bash
docker compose up -d
docker compose ps          # n8n and postgres should both show as running
```

Open http://localhost:5678 and create the n8n owner account when asked.

### 6.3 Create the database and load the synthetic data

```bash
docker compose exec postgres createdb -U <database user> zuri
chmod +x db/*.sh
./db/setup.sh --reset
```

`setup.sh` reads `.env` by itself. Success looks like this:

```
products / contacts / orders: 20 3 6
Done. Database 'zuri' is ready.
```

To start over at any time, run `./db/setup.sh --reset` again.

### 6.4 Create a Telegram bot

1. In Telegram, open **@BotFather**, send `/newbot` and follow the prompts. Copy the **bot token**.
2. Send any message to your new bot.
3. Open `https://api.telegram.org/bot<TOKEN>/getUpdates` in a browser. Find `"chat":{"id": ...}` and copy that number. This is your **chat ID**. For the demo, one chat ID can be used for every staff member.

### 6.5 Create four credentials in n8n

Open **Credentials** in n8n and create:

| Credential | Fields |
|---|---|
| **Telegram** | Access token = the bot token |
| **Postgres** | Host = `postgres` (the service name, **not** `localhost`), Port = `5432`, Database = `zuri`, User and Password from `.env`, SSL off |
| **Header Auth** (for Staff-Actions) | Name = `X-Staff-Token`, Value = any secret you choose |
| **Basic Auth** (for the Dashboard) | A username and password of your choice |

### 6.6 Import the workflows

In n8n choose **Workflows, then Import from file**, and import every file in `workflows/`. Import `SW-Config`, `SW-Reply` and `SW-Escalate` first.

**Imported workflows get new internal IDs, so three things must be redone by hand.** This is the step most likely to go wrong, so work through it slowly.

1. **Re-select each sub-workflow** in every *Execute Workflow* node:

   | Open this workflow | Re-select these in its Execute Workflow nodes |
   |---|---|
   | WA-Inbound | SW-Config, SW-Reply, SW-Escalate |
   | SW-Escalate | SW-Config, SW-Reply |
   | Staff-Actions | SW-Config |
   | SLA-Watchdog | SW-Config |

2. **Re-select credentials.** Any node showing a red warning needs its credential chosen (Postgres, Telegram, Header Auth or Basic Auth).
3. **Set the Error Workflow.** In each workflow's **Settings**, set *Error Workflow* to `Error-Handler`. Do this for every workflow except Error-Handler itself.

### 6.7 Fill in your own values

| Where | What to set |
|---|---|
| **SW-Config** (Code node) | In `staff`, replace the placeholder chat IDs (`111`, `222`, `333`) with your Telegram chat ID |
| **Error-Handler**, node *Notify Telegram* | Your Telegram chat ID |
| **Test-Runner**, node *Build Tests* | The `WA_URL` line at the top: the Production URL of WA-Inbound's *Receive* node |
| **Test-Send**, node *Send* | The same WA-Inbound URL |
| **Test-Staff-Action**, node *Send* | The Staff-Actions URL and the Header Auth credential |

To find a URL, open the workflow, click its webhook node, and copy the **Production URL**. It starts with `http://localhost:5678/webhook/`. Do not use the Test URL: it works only once, while the editor is listening.

### 6.8 Activate

Switch on the **Active** toggle (in some versions called **Publish**) for **WA-Inbound, Staff-Actions, SLA-Watchdog, Dashboard and Error-Handler**. Sub-workflows and Test workflows need no activation.

### 6.9 Smoke test

1. Open **Test-Send**. In the node *Message to send*, check that `phone` is `2348055556666` and `text` is `How much is the ceramic vase?`
2. Click **Execute workflow**. The *Send* node should return a 200 response.
3. Open **Test-Helpers**, right-click **Show replies sent** and choose **Execute step**. The newest row should be the price reply, `N15,000`, with status `simulated_sent`.

If this works, the whole chain (webhook, database, replies) is working.

---

## 7. Running the tests

All tests run **inside n8n**. No command line is needed.

### 7.1 The automated suite

1. Open the **Test-Runner** workflow.
2. Click **Execute workflow**. It takes about 4 minutes, so keep the tab open. It sends 36 messages one at a time and checks the result of 30 of them. The other 6 are setup steps. Expect about 7 Telegram alerts on your phone.
3. Open the **Test Report** node and switch its output to **Table** view.

**Warning:** Test-Runner first clears the messages, audit log, escalations, outbox and any orders created by tests. It keeps the products, contacts and the six seeded orders. Never run it against real data.

### 7.2 Reading the results

The first row of the table is a summary, for example `30 of 30 checks passed`. Each row below it shows:

| Column | Meaning |
|---|---|
| `test` and `name` | The test ID and what it checks |
| `result` | `PASS`, `FAIL` or `step` (a setup message that is not marked) |
| `sent` | The message that was sent |
| `expected` | What should happen, in words |
| `actual` | The reply, the conversation state and the newest escalation after the message was processed |
| `problems` | If the test failed, exactly what was wrong |

The *Download CSV* node produces the same table as a file, which is the basis of `03_Test_Record`.

### 7.3 Four manual checks

These involve Telegram, the clock or a browser, so they are not in the automated suite.

**M1. Telegram failure (a failure condition)**
1. Change the Telegram credential's token to `wrong` and save.
2. Run **Test-Send** with the text `I want a refund`.
3. In **Test-Helpers**, run **Show escalations**: the newest row has `notify_failed`-style status `failed` in `notify_status`. Run **Show audit log**: there is a `notify_failed` row.
4. Put the real token back.

**M2. Claim and resolve**
1. In **Test-Helpers**, run **Show escalations** and note the `id` of an `open` case.
2. In **Test-Staff-Action**, set `action` to `claim`, enter the `id`, and run it. Expect `ok: true`.
3. Run it again: expect a 409 (already claimed).
4. Set `action` to `resolve` and run it. Expect `ok: true`. **Show escalations** now shows `resolved`.

**M3. Reminder for an overdue case**
1. Create an open case: run **Test-Send** with the text `asdfgh`.
2. In **Test-Helpers**, run **Make oldest open case overdue**.
3. Open **SLA-Watchdog** and click **Execute workflow**. The manager gets one Telegram reminder.
4. Execute it again: nothing is sent, and `reminder_count` stays at 1.
5. Reminders are sent only in business hours (Monday to Saturday, 8am to 8pm WAT). Outside them, temporarily widen `hours` in SW-Config, and change it back afterwards.

**M4. Dashboard**
1. Open `http://localhost:5678/webhook/dashboard` (use the Production URL from the Dashboard's webhook node) and sign in with your Basic Auth login.
2. Check that Messages, Escalation rate and Unresolved cases have values, not `n/a`.
3. Compare "Unresolved cases" with the open and claimed rows in **Show escalations**.
4. After M2, "Human first response" shows a value.

### 7.4 Sending a single message

Open **Test-Send**, change `phone` and `text` in *Message to send*, and click **Execute workflow**. Every run uses a new message ID. (Repeating the same ID is deliberately ignored as a duplicate.)

The three seeded customers are:

| Phone | Customer | Owns orders |
|---|---|---|
| `2348011112222` | Ada Test | ZH-10001, ZH-10002 |
| `2348033334444` | Bola Sample | ZH-10003, ZH-10004 |
| `2348055556666` | Chidi Demo | ZH-10005, ZH-10006 |

### 7.5 Looking at the data

**Test-Helpers** has one node per view. Right-click a node and choose **Execute step**: *Show replies sent*, *Show conversation state*, *Show escalations*, *Show audit log*, *Show orders*.

### 7.6 Optional: command-line tests

The `tests/` folder has the same checks as shell scripts (`reset.sh`, `send.sh`, `run-tests.sh`). They need `curl`, `jq` and Docker access, and they are not required. The n8n route above is the supported one.

---

## 8. Test inputs and the test record

- **Test inputs:** `test_inputs/` holds the synthetic WhatsApp payloads (JSON) used by the tests. Every message, name, phone number and address is fictional.
- **Test record:** `03_Test_Record.pdf` shows each test with its input, expected result and actual result.

How the tests cover the brief:

| Brief requirement | Tests |
|---|---|
| Every intent | T01 (product enquiry), T12 (order status), T18a to T18g (place order), T08 (delivery info), T09 and T11 (payment info), T21 (complaint and refund) |
| Missing or invalid data handled | T07 (no product named), T14 (malformed order ID `ZH-12`), T18d (invalid address) |
| Human escalation | T21 (refund to manager, high priority), T20 (customer asks for a person), T19 (intake abandoned) |
| **Failure condition 1:** duplicate request | T23 |
| **Failure condition 2:** low-confidence classification | T22 |
| Extra failure condition: unavailable integration | M1 (Telegram down) |
| Order privacy | T13 (another customer cannot see the order) |
| Operational record | M2 to M4 (claim and resolve, reminders, dashboard) and the audit log |

---

## 9. Viewing the results

- **Dashboard:** `http://localhost:5678/webhook/dashboard`. It shows messages by intent, escalation rate, the share handled by the bot, unresolved cases with their age, SLA breaches, bot response time, human first-response time, and counts of failures (duplicates, low-confidence messages, failed alerts and workflow errors). It contains no phone numbers or message text.
- **Audit log:** run **Show audit log** in Test-Helpers. Each row has a timestamp, a request ID, an event name and a detail.
- **Execution history:** n8n's own **Executions** tab shows every workflow run, including any failure.

---

## 10. Changing the bot's behaviour

Business rules live in **SW-Config** (one Code node). Change a value, save, and run the tests.

| To change | Edit in SW-Config |
|---|---|
| Keywords and their weights for each intent | `intents` |
| Words that trigger "talk to a person", complaints, or cancel | `interrupts` |
| How sure the system must be before answering on its own | `threshold` (default 0.6) |
| Response target for escalations | `sla_minutes` (default 30) |
| Business hours | `hours` |
| Delivery zones and fees | `zones` |
| Which staff member handles which case type | `routing` |
| Staff names and Telegram chat IDs | `staff` |
| Reply wording (bank details, delivery text) | `messages` |

---

## 11. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| A webhook returns **404** | Workflow not active, or the Test URL was used | Activate it and use the **Production URL** |
| `db/setup.sh` says it cannot connect | Container not running, wrong user, or the `zuri` database does not exist | `docker compose ps`; check the user in `.env`; run the `createdb` command in 6.3 |
| Replies are not produced, and an execution shows a red node | A credential or sub-workflow link is missing | Open the red node and fix it. Re-check step 6.6 |
| *Sub-workflow not found* or an empty workflow dropdown | Workflow IDs changed on import | Re-select the sub-workflow in the Execute Workflow node |
| Code node error: *Module 'crypto' is disallowed* | `NODE_FUNCTION_ALLOW_BUILTIN=crypto` not set where the Code runs | Set it (also on the task-runner container, if any) and restart n8n |
| Code node error about env access | `N8N_BLOCK_ENV_ACCESS_IN_NODE=false` not set | Set it and restart n8n |
| Order-status tests fail for the seeded customers | `PHONE_PEPPER` in n8n differs from the one used by `setup.sh` | Use the same value in both, then run `./db/setup.sh --reset` |
| No Telegram alerts | Wrong token or chat ID, or you never messaged the bot | Check the credential and chat ID. Open **Show audit log** for `notify_failed` |
| Dashboard shows `n/a` | No data yet, or the Postgres credential points at the wrong database | Run Test-Runner. Check the credential's database is `zuri` |
| Successful runs do not appear in Executions | `EXECUTIONS_DATA_SAVE_ON_SUCCESS=none` | Set it to `all` while testing |

---

## 12. Security and data handling

- **All data is synthetic.** The customers, phone numbers, addresses, products and bank details are invented.
- **No secrets are included.** `.env.example` holds placeholders. Credentials live in n8n's encrypted credential store.
- **Phone numbers:** the operational tables store only an HMAC-SHA256 hash. Logs and alerts show a masked number. One `contacts` table keeps the (fictional) real number, because the system needs it to reply.
- **Access control:** the Dashboard uses Basic Auth and Staff-Actions requires a header token. PostgreSQL is not exposed outside the Docker network.
- **Data minimisation:** n8n execution data is pruned after 7 days. The written submission (Sections F and G) describes the 90-day retention policy.

---

## 13. Known limitations

These are deliberate first-version choices, covered in the written submission.

- **The simulated webhook accepts any POST.** Production needs Meta's verification handshake and HMAC signature validation.
- **Classification is keyword scoring in English.** A bare product name with no intent word (just `vase`) is low confidence and goes to a human. Pidgin, Yoruba and Hausa are not understood.
- **SQL is built in Code nodes with escaping** of customer text. Parameterised queries are planned for production.
- **The SLA is a simple 30-minute deadline.** Reminders are sent only in business hours, once per case.
- **Stock is not reserved.** The bot records the order, and staff confirm payment and dispatch.
- **Images and voice notes** are passed to staff, not interpreted.
- **The audit log is append-only by design**, not enforced by the database. A trigger is in the 30-day plan.
- **One server, no high availability.** Backups and the retention purge are runbook procedures, not automated workflows.

---

## 14. Tools, libraries and AI disclosure

### Tools and resources

| Tool | Used for | Notes |
|---|---|---|
| n8n 2.42.6 (self-hosted) | All workflows | Free community edition |
| PostgreSQL | The database | Open source |
| Docker and Docker Compose | Running n8n and PostgreSQL | |
| Telegram Bot API | Staff alerts | Free |
| openssl, bash, curl | Setup script and optional tests | |

No external code libraries are used. The Code nodes use JavaScript and Node's built-in `crypto` module only.

### AI assistant

I used **Claude (Anthropic)** as an AI assistant throughout this assessment, for:

- Discussing the design and reviewing my plan against the brief.
- Drafting the workflow logic, Code-node JavaScript, SQL, and the setup and test scripts.
- Reviewing and proofreading the written submission.

I am responsible for every technical decision in this submission, and I can explain, modify and debug every part of it.

---

## 15. Demonstration video

The link is in `04_Demo_Video_Link.txt`. The video (5 to 8 minutes) shows a successful path, an escalation to staff on Telegram, a failure path, and the operational record: the audit log and the dashboard.
