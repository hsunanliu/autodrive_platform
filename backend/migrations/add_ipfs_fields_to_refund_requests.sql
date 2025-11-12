-- Database Migration: Add IPFS Evidence Fields to refund_requests
-- Created: 2025-10-26
-- Description: Adds IPFS-related fields to store refund evidence metadata

-- Add IPFS evidence columns
ALTER TABLE refund_requests
ADD COLUMN IF NOT EXISTS evidence_cid VARCHAR(100),
ADD COLUMN IF NOT EXISTS evidence_hash VARCHAR(64),
ADD COLUMN IF NOT EXISTS evidence_filename VARCHAR(255),
ADD COLUMN IF NOT EXISTS evidence_content_type VARCHAR(100);

-- Add comments for documentation
COMMENT ON COLUMN refund_requests.evidence_cid IS 'IPFS Content Identifier for refund evidence';
COMMENT ON COLUMN refund_requests.evidence_hash IS 'SHA256 hash of evidence file for integrity verification';
COMMENT ON COLUMN refund_requests.evidence_filename IS 'Original filename of uploaded evidence';
COMMENT ON COLUMN refund_requests.evidence_content_type IS 'MIME type of evidence file (e.g., image/jpeg, application/pdf)';

-- Create index for CID lookups (optional but recommended)
CREATE INDEX IF NOT EXISTS idx_refund_requests_evidence_cid
ON refund_requests(evidence_cid)
WHERE evidence_cid IS NOT NULL;

-- Verification query
SELECT
    column_name,
    data_type,
    character_maximum_length,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'refund_requests'
AND column_name LIKE 'evidence%'
ORDER BY ordinal_position;
