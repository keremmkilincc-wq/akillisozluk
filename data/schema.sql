-- ============================================================================
--  AKILLI TÜRKÇE SÖZLÜK — VERİTABANI ŞEMASI
--  Faz 0 : veri üretim hattı
--
--  İki ayrı veritabanı mantığı:
--    dict.db  → SALT OKUNUR, uygulamayla birlikte gelir
--    user.db  → YAZILABİLİR, kullanıcı verisi
--
--  Bu dosya dict.db içindeki şemayı tanımlar.
-- ============================================================================

PRAGMA foreign_keys = ON;

-- ---------------------------------------------------------------------------
-- WORDS — kelimenin kimliği
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS words (
  id                INTEGER PRIMARY KEY,

  -- Yazım ve arama
  word              TEXT    NOT NULL,              -- doğru yazım: "rüzgâr"
  normalized_word   TEXT    NOT NULL,              -- arama için katlanmış
  search_folded     TEXT    NOT NULL,              -- diyakritik katlanmış

  -- Kimlik ve etimoloji
  origin            TEXT,                          -- "Arapça", "Öz Türkçe"
  origin_period     TEXT,                          -- "15. yy", "Öz Türkçe"
  is_pure_turkish   INTEGER NOT NULL DEFAULT 0,    -- 0/1
  phonetics         TEXT,                          -- fonetik okunuş

  -- Ölçüm
  usage_frequency   REAL    NOT NULL DEFAULT 0.0,  -- 0..1 günlük kullanım sıklığı
  confidence        REAL    NOT NULL DEFAULT 1.0,  -- 0..1 veri güvenilirliği
  source_note       TEXT,                          -- "AI+editör", "Zemberek 2.3"

  -- Sınav etiketleri (Faz 5) — boşsa hiçbir sınava girmez
  exam_tags         TEXT    NOT NULL DEFAULT '',   -- "yks,kpss,ales,yds" (virgüllü)

  -- İçerik bayrakları
  has_audio         INTEGER NOT NULL DEFAULT 0,
  is_controversial  INTEGER NOT NULL DEFAULT 0    -- küçük çocuk içeriği vb.
);

CREATE INDEX IF NOT EXISTS idx_words_word        ON words(word);
CREATE INDEX IF NOT EXISTS idx_words_normalized ON words(normalized_word);
CREATE INDEX IF NOT EXISTS idx_words_folded      ON words(search_folded);
CREATE INDEX IF NOT EXISTS idx_words_pure        ON words(is_pure_turkish);

-- ---------------------------------------------------------------------------
-- MEANINGS — anlam katmanları
--
--   meaning_order : aynı kelimenin anlam sırası (1 = birincil anlam)
--   sense_label   : TDK'nın ayrımı esas alınarak
--                     'gercek'  — temel anlam
--                     'mecaz'   — deyimsel/yorumsal anlam
--                     'terim'   — bilimsel/mesleksel terim
--                     'argo'    — günlük konuşma dili
--   confidence    : AI uydurursa düşer → uygulama "doğrulanmadı" rozeti gösterir
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS meanings (
  id                INTEGER PRIMARY KEY,
  word_id           INTEGER NOT NULL REFERENCES words(id) ON DELETE CASCADE,
  meaning_order     INTEGER NOT NULL,

  word_type         TEXT    NOT NULL,              -- "isim", "fiil", "sıfat", "zarf", "zamir"
  sense_label       TEXT    NOT NULL DEFAULT 'gercek',
  definition        TEXT    NOT NULL,

  -- Örnek cümleler
  example_classic   TEXT,                          -- klasik edebiyattan
  example_author    TEXT,                          -- YALNIZCA DOĞRULANMIŞSA
  example_modern    TEXT,                          -- günlük dilden
  example_note      TEXT,                          -- neden alıntı yok?

  confidence        REAL    NOT NULL DEFAULT 1.0,

  UNIQUE(word_id, meaning_order)
);

CREATE INDEX IF NOT EXISTS idx_meanings_word ON meanings(word_id);

-- ---------------------------------------------------------------------------
-- RELATIONS — kelimeler arası ilişkiler
--   relation_type: synonym | antonym | derivative | related | idiom | proverb
--   note         : "nadir kullanım" gibi ihtiyat notu
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS relations (
  id                INTEGER PRIMARY KEY,
  word_id           INTEGER NOT NULL REFERENCES words(id) ON DELETE CASCADE,
  related_word      TEXT    NOT NULL,              -- metin olarak tutulur,
                                                  -- kelime yoksa da ilişki kaybolmaz
  relation_type     TEXT    NOT NULL,
  note              TEXT,
  confidence        REAL    NOT NULL DEFAULT 1.0,

  UNIQUE(word_id, related_word, relation_type)
);

CREATE INDEX IF NOT EXISTS idx_relations_word   ON relations(word_id);
CREATE INDEX IF NOT EXISTS idx_relations_type   ON relations(relation_type);
CREATE INDEX IF NOT EXISTS idx_relations_related ON relations(related_word);

-- ---------------------------------------------------------------------------
-- MORPHOLOGY — Zemberek ile önceden hesaplanmış kök/ek analizi
--
--   root      : "kitap"
--   suffixes  : ["lar", "ımız", "dan"]  → JSON dizisi
--   surface   : "kitaplarımızdan"
--   scan_code : Zemberek'ten gelen özgün kod (teşhis için)
--
--   Hesaplama masaüstünde BİR KEZ yapılır, uygulama çevrimdışı okur.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS morphology (
  id                INTEGER PRIMARY KEY,
  word_id           INTEGER NOT NULL REFERENCES words(id) ON DELETE CASCADE,
  surface           TEXT    NOT NULL,
  root              TEXT    NOT NULL,
  suffixes          TEXT    NOT NULL DEFAULT '[]', -- JSON
  explanation       TEXT,                          -- "çoğul + 1. kişi eki + ayrılma hâli"
  note              TEXT,                          -- yazım uyarısı, ihtiyat notu
  scan_code         TEXT,

  UNIQUE(word_id, surface)
);

CREATE INDEX IF NOT EXISTS idx_morph_root    ON morphology(root);
CREATE INDEX IF NOT EXISTS idx_morph_surface ON morphology(surface);

-- ---------------------------------------------------------------------------
-- IDIOMS_PROVERBS — deyim ve atasözü
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS idioms_proverbs (
  id                INTEGER PRIMARY KEY,
  text              TEXT    NOT NULL,
  kind              TEXT    NOT NULL,              -- 'deyim' | 'atasozu'
  meaning           TEXT    NOT NULL,
  related_word      TEXT,                          -- öncelikli kelimeye bağla
  example           TEXT,
  confidence        REAL    NOT NULL DEFAULT 1.0
);

CREATE INDEX IF NOT EXISTS idx_ip_related ON idioms_proverbs(related_word);
CREATE INDEX IF NOT EXISTS idx_ip_kind    ON idioms_proverbs(kind);

-- ---------------------------------------------------------------------------
-- YAZIM UYARILARI — Modül 6'nın kalbi (Faz 5)
--
--   "kitap → kitabe" gibi ek düşürme hataları. Tamamen özgün ve
--   kurallara dayalı olduğu için en değerli içeriklerden biri.
--
--   rule_type:
--     'suffix_sound'  → yumuşama: kitap → kitabe
--     'hard_consonant'→ sertleşme: ağaç → ağacın
--     'spelling'      → yazım karışıklığı: milyar/milyar
--     'vowel_drop'    → ünlü düşmesi
--     'consonant_drop'→ ünsüz düşmesi
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS writing_rules (
  id                INTEGER PRIMARY KEY,
  base_word         TEXT    NOT NULL,              -- "kitap"
  wrong_form        TEXT    NOT NULL,              -- "kitabe" (yaygın hata)
  correct_form      TEXT    NOT NULL,              -- "kitabı"
  rule_type         TEXT    NOT NULL,
  rule_explanation  TEXT    NOT NULL,              -- yumuşama çeşitleri
  exam_tags         TEXT    NOT NULL DEFAULT '',
  confidence        REAL    NOT NULL DEFAULT 1.0,

  UNIQUE(base_word, wrong_form)
);

CREATE INDEX IF NOT EXISTS idx_writing_base ON writing_rules(base_word);

-- ---------------------------------------------------------------------------
-- TERSİ SÖZLÜK TABLOLARI (Faz 2, Katman A — çevrimdışı)
--
--   Tanım gömme vektörleri. 100k × 384 boyut (float16) ≈ 75 MB.
--   Kullanıcı cümlesi embed edilir → BM25 ile 100 aday → kosinüs sıralama.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS definition_vectors (
  id                INTEGER PRIMARY KEY,
  meaning_id        INTEGER NOT NULL REFERENCES meanings(id) ON DELETE CASCADE,
  vector            BLOB    NOT NULL,              -- float16 dizisi
  dim               INTEGER NOT NULL,
  model             TEXT    NOT NULL              -- "minilm-tr-v1"
);

CREATE INDEX IF NOT EXISTS idx_dv_meaning ON definition_vectors(meaning_id);

-- Tersi sözlük için BM25 sözcüksel indeks (vektör öncesi hızlı aday üretimi)
CREATE VIRTUAL TABLE IF NOT EXISTS definitions_fts USING fts5(
  definition,
  example_modern,
  content='meanings',
  content_rowid='id',
  tokenize='unicode61 remove_diacritics 2'
);

-- ---------------------------------------------------------------------------
-- GÜNLÜK KELİME (Modül 5)
--   date ile tohumlanır → herkes aynı kelimeyi alır, çevrimdışı da tutarlı.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS daily_words (
  date              TEXT    PRIMARY KEY,           -- "2026-10-16"
  word_id           INTEGER NOT NULL REFERENCES words(id),
  puzzle_letters    TEXT                            -- bulmaca için hazır harfler
);

-- ---------------------------------------------------------------------------
-- İSTATİSTİK / BÜTÜNLÜK KONTROLÜ (veri hattı doğrulaması)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dataset_meta (
  key              TEXT PRIMARY KEY,
  value            TEXT NOT NULL
);

INSERT OR REPLACE INTO dataset_meta(key, value) VALUES
  ('schema_version',   '1'),
  ('created_at',       datetime('now')),
  ('dataset_version',  '0.1.0-tad'),
  ('word_count',       '0'),
  ('license',          'CC BY 4.0 — bkz. LICENSE');