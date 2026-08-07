-- Add topic column to vocabularies table for category-based review filtering
-- Migration: 20250807_add_topic_to_vocabularies

-- Add topic column with default value 'other' for existing rows
ALTER TABLE vocabularies
ADD COLUMN topic TEXT NOT NULL DEFAULT 'other';

-- Add comment for documentation
COMMENT ON COLUMN vocabularies.topic IS 'Vocabulary topic category: food, people, nature, home, daily_life, clothing, hobbies, education, work, technology, health, entertainment, other';

-- Create index on topic for faster filtering (optional, but recommended for performance)
CREATE INDEX IF NOT EXISTS idx_vocabularies_topic ON vocabularies(topic);

-- Update existing rows based on their communicative_function (heuristic)
-- This is a simple migration strategy - for production, you might want to run AI categorization on existing data
UPDATE vocabularies
SET topic = CASE
  WHEN communicative_function ILIKE '%food%' OR communicative_function ILIKE '%eating%' THEN 'food'
  WHEN communicative_function ILIKE '%family%' OR communicative_function ILIKE '%people%' THEN 'people'
  WHEN communicative_function ILIKE '%nature%' OR communicative_function ILIKE '%weather%' THEN 'nature'
  WHEN communicative_function ILIKE '%home%' OR communicative_function ILIKE '%house%' THEN 'home'
  WHEN communicative_function ILIKE '%daily%' OR communicative_function ILIKE '%routine%' THEN 'daily_life'
  WHEN communicative_function ILIKE '%clothing%' OR communicative_function ILIKE '%wear%' THEN 'clothing'
  WHEN communicative_function ILIKE '%sport%' OR communicative_function ILIKE '%game%' THEN 'hobbies'
  WHEN communicative_function ILIKE '%study%' OR communicative_function ILIKE '%learn%' THEN 'education'
  WHEN communicative_function ILIKE '%work%' OR communicative_function ILIKE '%job%' THEN 'work'
  WHEN communicative_function ILIKE '%tech%' OR communicative_function ILIKE '%digital%' THEN 'technology'
  WHEN communicative_function ILIKE '%health%' OR communicative_function ILIKE '%body%' THEN 'health'
  WHEN communicative_function ILIKE '%movie%' OR communicative_function ILIKE '%music%' THEN 'entertainment'
  ELSE 'other'
END
WHERE topic = 'other'; -- Only update rows that still have the default value
