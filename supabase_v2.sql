-- ============================================
-- 贴词吧 · 公开分享 & 糍粑摊 · 建表 SQL v2
-- 在 Supabase SQL Editor 里粘贴执行
-- https://supabase.com/dashboard/project/plnwkcdpzybbthuxfnmf/sql/
-- ============================================

-- 1A. 用户公开资料表
CREATE TABLE IF NOT EXISTS user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT UNIQUE,
    bio TEXT DEFAULT '',
    avatar_url TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- 1B. 公开分享方案表
CREATE TABLE IF NOT EXISTS public_schemes (
    id BIGSERIAL PRIMARY KEY,
    owner_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    description TEXT DEFAULT '',
    card_count INT DEFAULT 0,
    scheme_data JSONB NOT NULL,
    images TEXT[] DEFAULT '{}',
    view_count INT DEFAULT 0,
    like_count INT DEFAULT 0,
    comment_count INT DEFAULT 0,
    favorite_count INT DEFAULT 0,
    share_count INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public_schemes ENABLE ROW LEVEL SECURITY;

-- 1C. 评论区
CREATE TABLE IF NOT EXISTS comments (
    id BIGSERIAL PRIMARY KEY,
    scheme_id BIGINT REFERENCES public_schemes(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;

-- 1D. 点赞记录
CREATE TABLE IF NOT EXISTS likes (
    id BIGSERIAL PRIMARY KEY,
    scheme_id BIGINT REFERENCES public_schemes(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(scheme_id, user_id)
);
ALTER TABLE likes ENABLE ROW LEVEL SECURITY;

-- 1E. 收藏记录
CREATE TABLE IF NOT EXISTS favorites (
    id BIGSERIAL PRIMARY KEY,
    scheme_id BIGINT REFERENCES public_schemes(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(scheme_id, user_id)
);
ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;

-- 1F. 积分流水
CREATE TABLE IF NOT EXISTS user_points (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    points INT NOT NULL,
    reason TEXT NOT NULL,
    target_id BIGINT REFERENCES public_schemes(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE user_points ENABLE ROW LEVEL SECURITY;

-- 1G. 积分汇总（方便查询排名）
CREATE TABLE IF NOT EXISTS user_point_totals (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    total_points INT DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE user_point_totals ENABLE ROW LEVEL SECURITY;

-- ============= 索引 =============
CREATE INDEX IF NOT EXISTS idx_ps_owner ON public_schemes(owner_id);
CREATE INDEX IF NOT EXISTS idx_ps_created ON public_schemes(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ps_likes ON public_schemes(like_count DESC);
CREATE INDEX IF NOT EXISTS idx_ps_views ON public_schemes(view_count DESC);
CREATE INDEX IF NOT EXISTS idx_comments_scheme ON comments(scheme_id);
CREATE INDEX IF NOT EXISTS idx_likes_scheme ON likes(scheme_id);
CREATE INDEX IF NOT EXISTS idx_favorites_user ON favorites(user_id);
CREATE INDEX IF NOT EXISTS idx_favorites_scheme ON favorites(scheme_id);
CREATE INDEX IF NOT EXISTS idx_up_user ON user_points(user_id);
CREATE INDEX IF NOT EXISTS idx_upt_points ON user_point_totals(total_points DESC);
CREATE INDEX IF NOT EXISTS idx_shared_ispublic ON shared_schemes(short_id);

-- ============= RLS 策略 =============

DO $$
BEGIN
    -- user_profiles: 公开读 / 仅本人写
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Public read profiles') THEN
        CREATE POLICY "Public read profiles" ON user_profiles FOR SELECT USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'User upsert own profile') THEN
        CREATE POLICY "User upsert own profile" ON user_profiles
            FOR INSERT WITH CHECK (auth.uid() = id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'User update own profile') THEN
        CREATE POLICY "User update own profile" ON user_profiles
            FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);
    END IF;

    -- public_schemes: 公开读 / 仅本人写删
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Public read schemes') THEN
        CREATE POLICY "Public read schemes" ON public_schemes FOR SELECT USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Owner insert schemes') THEN
        CREATE POLICY "Owner insert schemes" ON public_schemes FOR INSERT WITH CHECK (auth.uid() = owner_id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Owner update own schemes') THEN
        CREATE POLICY "Owner update own schemes" ON public_schemes FOR UPDATE USING (auth.uid() = owner_id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Owner delete own schemes') THEN
        CREATE POLICY "Owner delete own schemes" ON public_schemes FOR DELETE USING (auth.uid() = owner_id);
    END IF;

    -- comments: 公开读 / 本人写删
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Public read comments') THEN
        CREATE POLICY "Public read comments" ON comments FOR SELECT USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'User insert comments') THEN
        CREATE POLICY "User insert comments" ON comments FOR INSERT WITH CHECK (auth.uid() = user_id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'User delete own comments') THEN
        CREATE POLICY "User delete own comments" ON comments FOR DELETE USING (auth.uid() = user_id);
    END IF;

    -- likes: 公开读 / 本人写删
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Public read likes') THEN
        CREATE POLICY "Public read likes" ON likes FOR SELECT USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'User manage own likes') THEN
        CREATE POLICY "User manage own likes" ON likes FOR INSERT WITH CHECK (auth.uid() = user_id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'User delete own likes') THEN
        CREATE POLICY "User delete own likes" ON likes FOR DELETE USING (auth.uid() = user_id);
    END IF;

    -- favorites: 公开读 / 本人写删
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Public read favorites') THEN
        CREATE POLICY "Public read favorites" ON favorites FOR SELECT USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'User manage own favorites') THEN
        CREATE POLICY "User manage own favorites" ON favorites FOR INSERT WITH CHECK (auth.uid() = user_id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'User delete own favorites') THEN
        CREATE POLICY "User delete own favorites" ON favorites FOR DELETE USING (auth.uid() = user_id);
    END IF;

    -- user_points: 前端不能写入（由点赞/评论/分享操作触发写入）
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'User read own points') THEN
        CREATE POLICY "User read own points" ON user_points FOR SELECT USING (auth.uid() = user_id);
    END IF;

    -- user_point_totals: 公开读 / 不能写（由积分流水触发更新）
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Public read point totals') THEN
        CREATE POLICY "Public read point totals" ON user_point_totals FOR SELECT USING (true);
    END IF;
END $$;

-- ============= 触发器：点赞自动加积分 =============
CREATE OR REPLACE FUNCTION on_like_add_points()
RETURNS TRIGGER AS $$
DECLARE
    scheme_user UUID;
BEGIN
    SELECT owner_id INTO scheme_user FROM public_schemes WHERE id = NEW.scheme_id;
    IF scheme_user IS NOT NULL AND scheme_user != NEW.user_id THEN
        INSERT INTO user_points (user_id, points, reason, target_id)
        VALUES (scheme_user, 1, 'like_received', NEW.scheme_id);
        INSERT INTO user_point_totals (user_id, total_points)
        VALUES (scheme_user, 1)
        ON CONFLICT (user_id) DO UPDATE SET total_points = user_point_totals.total_points + 1, updated_at = NOW();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_like_points ON likes;
CREATE TRIGGER trg_like_points AFTER INSERT ON likes FOR EACH ROW EXECUTE FUNCTION on_like_add_points();

-- ============= 触发器：评论自动加积分 =============
CREATE OR REPLACE FUNCTION on_comment_add_points()
RETURNS TRIGGER AS $$
DECLARE
    scheme_user UUID;
BEGIN
    SELECT owner_id INTO scheme_user FROM public_schemes WHERE id = NEW.scheme_id;
    IF scheme_user IS NOT NULL AND scheme_user != NEW.user_id THEN
        INSERT INTO user_points (user_id, points, reason, target_id)
        VALUES (scheme_user, 1, 'comment_received', NEW.scheme_id);
        INSERT INTO user_point_totals (user_id, total_points)
        VALUES (scheme_user, 1)
        ON CONFLICT (user_id) DO UPDATE SET total_points = user_point_totals.total_points + 1, updated_at = NOW();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_comment_points ON comments;
CREATE TRIGGER trg_comment_points AFTER INSERT ON comments FOR EACH ROW EXECUTE FUNCTION on_comment_add_points();

-- ============= 计数器更新触发器 =============
CREATE OR REPLACE FUNCTION update_scheme_like_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public_schemes SET like_count = like_count + 1 WHERE id = NEW.scheme_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public_schemes SET like_count = GREATEST(like_count - 1, 0) WHERE id = OLD.scheme_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_like_count ON likes;
CREATE TRIGGER trg_like_count AFTER INSERT OR DELETE ON likes FOR EACH ROW EXECUTE FUNCTION update_scheme_like_count();

CREATE OR REPLACE FUNCTION update_scheme_comment_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public_schemes SET comment_count = comment_count + 1 WHERE id = NEW.scheme_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public_schemes SET comment_count = GREATEST(comment_count - 1, 0) WHERE id = OLD.scheme_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_comment_count ON comments;
CREATE TRIGGER trg_comment_count AFTER INSERT OR DELETE ON comments FOR EACH ROW EXECUTE FUNCTION update_scheme_comment_count();

CREATE OR REPLACE FUNCTION update_scheme_fav_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public_schemes SET favorite_count = favorite_count + 1 WHERE id = NEW.scheme_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public_schemes SET favorite_count = GREATEST(favorite_count - 1, 0) WHERE id = OLD.scheme_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_fav_count ON favorites;
CREATE TRIGGER trg_fav_count AFTER INSERT OR DELETE ON favorites FOR EACH ROW EXECUTE FUNCTION update_scheme_fav_count();

-- ============= Storage Bucket（手动在 Supabase 控制台创建） =============
-- 1. 进入 Storage 页面 → New Bucket → 名称: scheme-images
-- 2. 勾选 "Public bucket"
-- 3. 文件大小限制: 1MB
-- 4. 允许的 MIME 类型: image/jpeg, image/png, image/webp
-- 5. 或在 SQL 里执行（如果支持）：
--    INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
--    VALUES ('scheme-images', 'scheme-images', true, 1048576, '{image/jpeg,image/png,image/webp}')
--    ON CONFLICT DO NOTHING;

-- ============= 完成 =============
-- 执行完以上 SQL 后，去 Storage 手动创建 scheme-images bucket（公开访问）
