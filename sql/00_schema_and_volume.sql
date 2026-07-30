-- Unity Catalog setup for the Medical Omnichannel Intelligence demo.
-- Run this first. Catalog `_sa701` is assumed to already exist.

CREATE SCHEMA IF NOT EXISTS _sa701.moe
  COMMENT 'Medical Omnichannel Engagement (MOE) demo — synthetic Medical Affairs data';

-- Volume holding source/unstructured documents (e.g. MSL field-note PDFs)
-- ingested by the pipeline. See data/source_documents/ in this repo.
CREATE VOLUME IF NOT EXISTS _sa701.moe.source_documents
  COMMENT 'Source documents (MSL field notes, etc.) for the MOE demo';
