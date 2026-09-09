/// SQLite schema v1. Mirror of docs/04_LEDGER_RULES.md §4 — keep them in sync.
///
/// R1 is enforced here by triggers: `transactions` cannot be deleted, and the
/// only permitted UPDATE is setting `reversed_by_id` once (NULL -> value)
/// without touching any other column.
class Schema {
  static const int version = 1;

  static const List<String> createStatements = [
    '''
CREATE TABLE shops (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  logo_path TEXT,
  address TEXT,
  phone TEXT,
  extra_line TEXT,
  created_at INTEGER NOT NULL
)''',
    '''
CREATE TABLE users (
  id TEXT PRIMARY KEY,
  shop_id TEXT NOT NULL REFERENCES shops(id),
  name TEXT NOT NULL,
  photo_path TEXT,
  role TEXT NOT NULL CHECK(role IN ('owner','worker')),
  pin_hash TEXT,
  pin_salt TEXT,
  perms_json TEXT NOT NULL DEFAULT '{}',
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at INTEGER NOT NULL
)''',
    '''
CREATE TABLE currencies (
  code TEXT PRIMARY KEY,
  name_ar TEXT NOT NULL,
  symbol TEXT NOT NULL,
  minor_units INTEGER NOT NULL CHECK(minor_units IN (0,2)),
  is_active INTEGER NOT NULL DEFAULT 0,
  is_primary INTEGER NOT NULL DEFAULT 0,
  sort INTEGER NOT NULL DEFAULT 0
)''',
    '''
CREATE TABLE fx_rates (
  id TEXT PRIMARY KEY,
  from_code TEXT NOT NULL,
  to_code TEXT NOT NULL,
  rate_num INTEGER NOT NULL,
  rate_den INTEGER NOT NULL,
  set_at INTEGER NOT NULL,
  set_by TEXT
)''',
    '''
CREATE TABLE customers (
  id TEXT PRIMARY KEY,
  shop_id TEXT NOT NULL REFERENCES shops(id),
  name TEXT NOT NULL,
  phone TEXT,
  photo_path TEXT,
  voice_name_path TEXT,
  family_group_id TEXT,
  credit_limit_minor INTEGER,
  credit_limit_currency TEXT,
  note TEXT,
  is_archived INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  updated_by TEXT,
  last_activity_at INTEGER
)''',
    '''
CREATE TABLE transactions (
  id TEXT PRIMARY KEY,
  shop_id TEXT NOT NULL,
  customer_id TEXT NOT NULL REFERENCES customers(id),
  type TEXT NOT NULL CHECK(type IN ('debit','credit','adjust_down','adjust_up','opening')),
  amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
  currency_code TEXT NOT NULL REFERENCES currencies(code),
  occurred_at INTEGER NOT NULL,
  recorded_at INTEGER NOT NULL,
  recorded_by TEXT NOT NULL,
  note_text TEXT,
  note_voice_path TEXT,
  receipt_photo_path TEXT,
  due_date INTEGER,
  reverses_id TEXT REFERENCES transactions(id),
  reversed_by_id TEXT,
  reversal_reason TEXT,
  customer_name_snap TEXT NOT NULL,
  user_name_snap TEXT NOT NULL,
  fx_rate_snap TEXT,
  over_limit INTEGER NOT NULL DEFAULT 0,
  in_locked_period INTEGER NOT NULL DEFAULT 0,
  device_id TEXT NOT NULL,
  local_seq INTEGER NOT NULL,
  UNIQUE(device_id, local_seq)
)''',
    'CREATE INDEX idx_tx_customer_time ON transactions(customer_id, occurred_at DESC, recorded_at DESC)',
    'CREATE INDEX idx_tx_time ON transactions(occurred_at DESC)',
    'CREATE INDEX idx_tx_user ON transactions(recorded_by, occurred_at DESC)',
    'CREATE INDEX idx_cust_active_name ON customers(shop_id, is_archived, name)',
    'CREATE INDEX idx_cust_activity ON customers(shop_id, is_archived, last_activity_at DESC)',
    '''
CREATE TRIGGER trg_tx_no_delete BEFORE DELETE ON transactions
BEGIN
  SELECT RAISE(ABORT, 'transactions are append-only');
END''',
    '''
CREATE TRIGGER trg_tx_no_update BEFORE UPDATE ON transactions
WHEN NOT (
  OLD.reversed_by_id IS NULL AND NEW.reversed_by_id IS NOT NULL
  AND NEW.id = OLD.id
  AND NEW.shop_id = OLD.shop_id
  AND NEW.customer_id = OLD.customer_id
  AND NEW.type = OLD.type
  AND NEW.amount_minor = OLD.amount_minor
  AND NEW.currency_code = OLD.currency_code
  AND NEW.occurred_at = OLD.occurred_at
  AND NEW.recorded_at = OLD.recorded_at
  AND NEW.recorded_by = OLD.recorded_by
  AND NEW.device_id = OLD.device_id
  AND NEW.local_seq = OLD.local_seq
  AND IFNULL(NEW.reverses_id,'') = IFNULL(OLD.reverses_id,'')
)
BEGIN
  SELECT RAISE(ABORT, 'transactions are immutable');
END''',
    '''
CREATE TABLE balances_cache (
  customer_id TEXT NOT NULL,
  currency_code TEXT NOT NULL,
  balance_minor INTEGER NOT NULL,
  tx_count INTEGER NOT NULL,
  last_tx_at INTEGER,
  computed_at INTEGER NOT NULL,
  PRIMARY KEY(customer_id, currency_code)
)''',
    '''
CREATE TABLE reminders (
  id TEXT PRIMARY KEY,
  customer_id TEXT NOT NULL,
  channel TEXT NOT NULL CHECK(channel IN ('wa','sms','print')),
  balance_snap_minor INTEGER NOT NULL,
  currency_code TEXT NOT NULL,
  sent_at INTEGER NOT NULL,
  sent_by TEXT NOT NULL,
  template_id TEXT
)''',
    '''
CREATE TABLE audit_log (
  id TEXT PRIMARY KEY,
  entity TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  action TEXT NOT NULL,
  actor_id TEXT,
  at INTEGER NOT NULL,
  before_json TEXT,
  after_json TEXT,
  device_id TEXT NOT NULL
)''',
    '''
CREATE TABLE doc_templates (
  id TEXT PRIMARY KEY,
  name_ar TEXT NOT NULL,
  kind TEXT NOT NULL CHECK(kind IN ('statement','statement_detailed','receipt','claim','overdue_report','debt_ack')),
  layout_json TEXT NOT NULL,
  is_default INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL
)''',
    'CREATE TABLE settings (key TEXT PRIMARY KEY, value_json TEXT NOT NULL)',
    '''
CREATE TABLE sync_state (
  device_id TEXT PRIMARY KEY,
  device_name TEXT,
  last_export_seq INTEGER NOT NULL DEFAULT 0,
  last_import_at INTEGER,
  drive_file_id TEXT,
  is_frozen INTEGER NOT NULL DEFAULT 0
)''',
    'CREATE TABLE schema_meta (version INTEGER NOT NULL)',
  ];

  /// Seed rows: the four supported currencies (YER active + primary by default).
  static const List<String> seedStatements = [
    "INSERT INTO currencies(code,name_ar,symbol,minor_units,is_active,is_primary,sort) VALUES ('YER','ريال يمني','ر.ي',0,1,1,0)",
    "INSERT INTO currencies(code,name_ar,symbol,minor_units,is_active,is_primary,sort) VALUES ('YER_OLD','ريال يمني (قديم)','ر.ي ق',0,0,0,1)",
    "INSERT INTO currencies(code,name_ar,symbol,minor_units,is_active,is_primary,sort) VALUES ('SAR','ريال سعودي','ر.س',2,0,0,2)",
    "INSERT INTO currencies(code,name_ar,symbol,minor_units,is_active,is_primary,sort) VALUES ('USD','دولار أمريكي','\$',2,0,0,3)",
  ];
}
