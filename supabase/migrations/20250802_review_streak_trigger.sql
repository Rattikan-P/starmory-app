-- Add review activity to streak tracking
-- Migration: 20250802_review_streak_trigger.sql
-- This adds a trigger on word_cards table to update user streak when they review cards

-- Drop the trigger if it exists
DROP TRIGGER IF EXISTS on_word_card_reviewed ON public.word_cards;

-- Create trigger on word_cards table
-- This fires every time a user reviews a word card (UPDATE operation)
-- The trigger uses the existing update_streak_after_activity() function
CREATE TRIGGER on_word_card_reviewed
  AFTER UPDATE OF last_review ON public.word_cards
  FOR EACH ROW
  WHEN (OLD.last_review IS DISTINCT FROM NEW.last_review)
  EXECUTE FUNCTION public.update_streak_after_activity();

-- Add comment for documentation
COMMENT ON TRIGGER on_word_card_reviewed ON public.word_cards IS
  'Automatically updates user streak when a word card is reviewed (last_review timestamp changes).
   Uses the same streak logic as vocabulary acquisition:
   - First activity of the day increments streak
   - Consecutive days within 48hr grace period increment streak
   - Every 7 consecutive days earns a shield
   - Shields protect streak when missing >48hrs';
