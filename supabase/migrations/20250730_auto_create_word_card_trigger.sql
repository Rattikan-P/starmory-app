-- Auto-create word_card when vocabulary is inserted
-- This ensures every vocabulary has a corresponding card for review system

-- Function to create word_card when vocabulary is inserted
CREATE OR REPLACE FUNCTION public.create_word_card_on_vocabulary_insert()
RETURNS TRIGGER AS $$
BEGIN
  -- Insert word_card for the new vocabulary
  INSERT INTO public.word_cards (
    user_id,
    vocabulary_id,
    state,
    due_date,
    created_at,
    updated_at
  )
  VALUES (
    NEW.user_id,
    NEW.id,
    'new',
    NOW(),
    NOW(),
    NOW()
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if exists
DROP TRIGGER IF EXISTS trigger_create_word_card_on_vocabulary_insert ON public.vocabularies;

-- Create trigger to auto-create word_card on vocabulary insert
CREATE TRIGGER trigger_create_word_card_on_vocabulary_insert
  AFTER INSERT ON public.vocabularies
  FOR EACH ROW
  EXECUTE FUNCTION public.create_word_card_on_vocabulary_insert();

-- Handle existing vocabularies without word_cards
-- This one-time migration creates cards for vocabularies that were inserted before the trigger
INSERT INTO public.word_cards (
  user_id,
  vocabulary_id,
  state,
  due_date,
  created_at,
  updated_at
)
SELECT
  v.user_id,
  v.id,
  'new',
  NOW(),
  v.created_at,
  NOW()
FROM public.vocabularies v
WHERE NOT EXISTS (
  SELECT 1 FROM public.word_cards wc
  WHERE wc.vocabulary_id = v.id
  AND wc.user_id = v.user_id
)
ON CONFLICT (user_id, vocabulary_id) DO NOTHING;

-- Grant execute permission on the function
GRANT EXECUTE ON FUNCTION public.create_word_card_on_vocabulary_insert() TO authenticated;
