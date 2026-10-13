DROP TABLE IF EXISTS outbox, audit_log, escalations, conversation_state,
                     messages, orders, contacts, products CASCADE;

CREATE TABLE products (
  sku        TEXT PRIMARY KEY,
  name       TEXT NOT NULL,
  price_ngn  INTEGER NOT NULL CHECK (price_ngn >= 0),
  stock      INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0),
  keywords   TEXT
);

CREATE TABLE contacts (            -- the only table holding phone numbers (fake ones here)
  phone_hash TEXT PRIMARY KEY,
  wa_phone   TEXT NOT NULL,
  first_seen TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_seen  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE orders (              -- no FK to contacts: the 90-day contact purge must not be blocked
  order_id      TEXT PRIMARY KEY,
  phone_hash    TEXT NOT NULL,
  status        TEXT NOT NULL CHECK (status IN
                  ('awaiting_payment','paid_confirmed','processing','dispatched','delivered','cancelled')),
  items_json    TEXT NOT NULL,     -- JSON kept as TEXT so existing JSON.parse code keeps working
  total_ngn     INTEGER NOT NULL CHECK (total_ngn >= 0),
  delivery_zone TEXT,
  address       TEXT,
  customer_name TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE messages (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  wa_message_id TEXT NOT NULL UNIQUE,      -- the duplicate check relies on this
  phone_hash    TEXT NOT NULL,
  msg_type      TEXT,
  text          TEXT,
  received_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  intent        TEXT,
  confidence    REAL,
  handled_by    TEXT,                      -- bot | escalated
  responded_at  TIMESTAMPTZ
);

CREATE TABLE conversation_state (
  phone_hash     TEXT PRIMARY KEY,
  intent         TEXT NOT NULL,            -- place_order | order_status | payment_info
  step           TEXT NOT NULL,            -- item | qty | address | name | confirm | await_id
  collected_json TEXT NOT NULL DEFAULT '{}',
  attempts       INTEGER NOT NULL DEFAULT 0,
  expires_at     TIMESTAMPTZ NOT NULL
);

CREATE TABLE escalations (
  id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  message_id        BIGINT REFERENCES messages(id) ON DELETE SET NULL,
  phone_hash        TEXT NOT NULL,
  category          TEXT NOT NULL,
  reason            TEXT,
  priority          TEXT NOT NULL DEFAULT 'normal' CHECK (priority IN ('normal','high')),
  assigned_to       TEXT,
  status            TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','claimed','resolved')),
  notify_status     TEXT NOT NULL DEFAULT 'pending' CHECK (notify_status IN ('pending','sent','failed')),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  sla_due_at        TIMESTAMPTZ,
  claimed_by        TEXT,
  claimed_at        TIMESTAMPTZ,
  first_response_at TIMESTAMPTZ,
  resolved_at       TIMESTAMPTZ,
  last_reminded_at  TIMESTAMPTZ,
  reminder_count    INTEGER NOT NULL DEFAULT 0,
  context_json      TEXT
);

CREATE TABLE audit_log (
  id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  ts           TIMESTAMPTZ NOT NULL DEFAULT now(),
  request_id   TEXT,
  phone_masked TEXT,
  event        TEXT NOT NULL,
  detail       TEXT
);

CREATE TABLE outbox (
  id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  phone_hash TEXT,
  request_id TEXT,
  text       TEXT,
  channel    TEXT DEFAULT 'whatsapp',
  mode       TEXT,
  status     TEXT,                         -- simulated_sent | failed
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  sent_at    TIMESTAMPTZ,
  error      TEXT
);

CREATE INDEX idx_messages_phone ON messages(phone_hash, id);
CREATE INDEX idx_messages_recv  ON messages(received_at);
CREATE INDEX idx_orders_phone   ON orders(phone_hash);
CREATE INDEX idx_state_expires  ON conversation_state(expires_at);
CREATE INDEX idx_esc_open       ON escalations(status, sla_due_at);
CREATE INDEX idx_audit_event    ON audit_log(event, ts);
CREATE INDEX idx_audit_request  ON audit_log(request_id);