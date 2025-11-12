-- Migration: Add fcm_token column to users table
-- Date: 2025-11-12
-- Purpose: Store Firebase Cloud Messaging tokens for push notifications

-- Add fcm_token column to users table
ALTER TABLE users
ADD COLUMN fcm_token VARCHAR(255)
COMMENT 'Firebase Cloud Messaging Token（用於推送通知）';

-- Create index for faster lookups when sending notifications
CREATE INDEX idx_users_fcm_token ON users(fcm_token);

-- Verification query
SELECT COUNT(*) as users_with_fcm_token FROM users WHERE fcm_token IS NOT NULL;
