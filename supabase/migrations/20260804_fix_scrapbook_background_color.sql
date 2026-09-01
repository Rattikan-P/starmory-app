-- Flutter stores colors as unsigned 32-bit ARGB values. Values such as
-- 0xFFFFFFFF (4294967295) exceed PostgreSQL INTEGER's signed 32-bit range.
ALTER TABLE public.scrapbooks
    ALTER COLUMN background_color TYPE BIGINT
        USING background_color::BIGINT,
    ALTER COLUMN background_color SET DEFAULT 4294967295;
