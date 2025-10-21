#!/bin/bash

echo "🐛 錯誤報告生成器"
echo "================================"
echo ""

REPORT_FILE="logs/error_report_$(date +%Y%m%d_%H%M%S).txt"

echo "生成錯誤報告: $REPORT_FILE"
echo ""

{
    echo "=== 錯誤報告 ==="
    echo "時間: $(date)"
    echo ""
    
    echo "=== Flutter 日誌（最後 100 行）==="
    if [ -f logs/flutter_debug.log ]; then
        tail -100 logs/flutter_debug.log
    else
        echo "未找到 logs/flutter_debug.log"
    fi
    echo ""
    
    echo "=== 後端日誌（最後 50 行）==="
    docker-compose logs --tail=50 backend
    echo ""
    
    echo "=== 數據庫狀態 ==="
    docker-compose exec -T db psql -U autodrive -d autodrive_dev -c "SELECT COUNT(*) as trip_count FROM trips;"
    echo ""
    
    echo "=== 後端健康狀態 ==="
    curl -s http://localhost:8000/health
    echo ""
    
} > "$REPORT_FILE"

echo "✅ 報告已生成: $REPORT_FILE"
echo ""
echo "你可以："
echo "1. 查看報告: cat $REPORT_FILE"
echo "2. 或直接把文件內容貼給我"
