-- ============================================
-- 贴词吧 · 分类字段迁移 v3
-- 在 Supabase SQL Editor 里粘贴执行
-- https://supabase.com/dashboard/project/plnwkcdpzybbthuxfnmf/sql/
-- ============================================

-- 给 public_schemes 添加 category 字段
ALTER TABLE public_schemes ADD COLUMN IF NOT EXISTS category TEXT DEFAULT '其他提示词';

-- 给 shared_schemes 添加 category 字段（私有分享页显示用）
ALTER TABLE shared_schemes ADD COLUMN IF NOT EXISTS category TEXT;

-- 索引（探索页按分类筛选）
CREATE INDEX IF NOT EXISTS idx_ps_category ON public_schemes(category);

-- 给现有方案设置默认分类
UPDATE public_schemes SET category = '其他提示词' WHERE category IS NULL;
