#!/bin/bash

echo "🔧 取消卡住的行程工具"
echo "================================"
echo ""

# 檢查是否提供了 trip_id
if [ -z "$1" ]; then
    echo "📋 查找所有進行中的行程..."
    echo ""
    docker-compose exec -T db psql -U autodrive -d autodrive_dev -c "
        SELECT trip_id, user_id, status, vehicle_id, 
               TO_CHAR(requested_at, 'YYYY-MM-DD HH24:MI:SS') as requested_at
        FROM trips 
        WHERE status IN ('requested', 'matched', 'accepted', 'picked_up', 'in_progress')
        ORDER BY trip_id DESC;
    "
    echo ""
    echo "使用方法："
    echo "  ./CANCEL_STUCK_TRIP.sh <trip_id>"
    echo ""
    echo "例如："
    echo "  ./CANCEL_STUCK_TRIP.sh 4"
    exit 0
fi

TRIP_ID=$1

echo "🔍 檢查行程 #$TRIP_ID..."
echo ""

# 檢查行程是否存在
TRIP_EXISTS=$(docker-compose exec -T db psql -U autodrive -d autodrive_dev -t -c "
    SELECT COUNT(*) FROM trips WHERE trip_id = $TRIP_ID;
" | tr -d ' ')

if [ "$TRIP_EXISTS" = "0" ]; then
    echo "❌ 行程 #$TRIP_ID 不存在"
    exit 1
fi

# 顯示行程信息
echo "📊 行程信息："
docker-compose exec -T db psql -U autodrive -d autodrive_dev -c "
    SELECT trip_id, user_id, status, vehicle_id, 
           pickup_address, dropoff_address,
           TO_CHAR(requested_at, 'YYYY-MM-DD HH24:MI:SS') as requested_at
    FROM trips 
    WHERE trip_id = $TRIP_ID;
"
echo ""

# 確認取消
read -p "確定要取消這個行程嗎？(y/N) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ 已取消操作"
    exit 0
fi

echo ""
echo "🔄 正在取消行程..."

# 更新行程狀態為 cancelled
docker-compose exec -T db psql -U autodrive -d autodrive_dev -c "
    UPDATE trips 
    SET status = 'cancelled',
        cancellation_reason = '管理員手動取消卡住的行程',
        cancelled_at = NOW()
    WHERE trip_id = $TRIP_ID;
"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ 行程 #$TRIP_ID 已成功取消"
    echo ""
    echo "📊 更新後的狀態："
    docker-compose exec -T db psql -U autodrive -d autodrive_dev -c "
        SELECT trip_id, status, cancellation_reason,
               TO_CHAR(cancelled_at, 'YYYY-MM-DD HH24:MI:SS') as cancelled_at
        FROM trips 
        WHERE trip_id = $TRIP_ID;
    "
else
    echo ""
    echo "❌ 取消失敗"
    exit 1
fi
