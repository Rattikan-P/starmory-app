-- Add terms_version to users table
-- Tracks which version of Terms & Privacy user has accepted

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS terms_version INTEGER DEFAULT 1;

-- Add index for faster queries
CREATE INDEX IF NOT EXISTS idx_users_terms_version ON public.users(terms_version);
