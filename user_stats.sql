-- ============================================================
-- 贴词吧 · 用户使用统计云端同步（2026-08-24）
-- 执行位置：Supabase Dashboard → SQL Editor → 粘贴执行
-- 用途：登录用户的使用统计（卡片累计使用次数）跨设备同步
-- ============================================================

-- 1. 用户统计表：每个用户一行，stats 为 JSONB（key=标题|内容前50字，value={count,last}）
CREATE TABLE IF NOT EXISTS user_stats (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    stats JSONB NOT NULL DEFAULT '{}'::jsonb,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. 行级安全：只能读写自己的统计
ALTER TABLE user_stats ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_stats_select_own" ON user_stats;
CREATE POLICY "user_stats_select_own" ON user_stats
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "user_stats_insert_own" ON user_stats;
CREATE POLICY "user_stats_insert_own" ON user_stats
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "user_stats_update_own" ON user_stats;
CREATE POLICY "user_stats_update_own" ON user_stats
    FOR UPDATE USING (auth.uid() = user_id);

-- 3. 验证
SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename='user_stats';
