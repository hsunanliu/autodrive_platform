-- 003_add_rating_content_blob.sql
-- 為評價加入 Walrus blob 錨定：完整評論內容存 Walrus，鏈上只留 blob_id + rating_hash。

ALTER TABLE vehicle_ratings
    ADD COLUMN IF NOT EXISTS content_blob_id VARCHAR(120);

COMMENT ON COLUMN vehicle_ratings.content_blob_id IS
    '評論完整內容在 Walrus 的 blob_id（鏈上以此 + rating_hash 錨定，讀取時比對 hash）';
