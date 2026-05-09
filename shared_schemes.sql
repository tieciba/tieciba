-- ============================================
-- 贴词吧 · 方案分享功能 · Supabase 建表 SQL
-- 在 Supabase SQL Editor 里粘贴执行
-- ============================================

-- 1. 分享表
CREATE TABLE IF NOT EXISTS shared_schemes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    short_id VARCHAR(8) UNIQUE NOT NULL,
    owner_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    title VARCHAR(100) NOT NULL,
    description TEXT DEFAULT '',
    card_count INTEGER NOT NULL,
    scheme_data JSONB NOT NULL,
    owner_email TEXT DEFAULT '',
    views INTEGER DEFAULT 0,
    imports INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 2. 索引
CREATE INDEX IF NOT EXISTS idx_shared_short_id ON shared_schemes(short_id);
CREATE INDEX IF NOT EXISTS idx_shared_owner_id ON shared_schemes(owner_id);

-- 3. RLS 安全策略：公开读 / 所有者写
ALTER TABLE shared_schemes ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Public can read shared schemes') THEN
        CREATE POLICY "Public can read shared schemes" ON shared_schemes FOR SELECT USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Owner can insert schemes') THEN
        CREATE POLICY "Owner can insert schemes" ON shared_schemes FOR INSERT WITH CHECK (auth.uid() = owner_id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Owner can delete schemes') THEN
        CREATE POLICY "Owner can delete schemes" ON shared_schemes FOR DELETE USING (auth.uid() = owner_id);
    END IF;
END $$;

-- 4. 确保 profiles 表有 display_name 列（用户显示名）
ALTER TABLE IF EXISTS profiles ADD COLUMN IF NOT EXISTS display_name TEXT DEFAULT '';
