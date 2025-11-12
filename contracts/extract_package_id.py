import json

# 從部署輸出中找到 JSON 部分（完整的部署結果已經在 shell 輸出中）
# 我們知道 Package 應該是 0x3bce...（從 stdout 中的 "created" 部分看到的）

# 從 BashOutput 中我看到了 created objects，讓我直接從那裡提取
# 根據 Sui 部署的慣例，published package 的 objectId 通常在 objectChanges 中

sample_output = """
{
  "objectChanges": [
    {
      "type": "published",
      "packageId": "0x3bce80e53dd38cf58d5b3eb6e856a27e52f1b39e0df75edb0872a89e9a5a4a74",
      ...
    }
  ]
}
"""

# 實際上我需要從 deploy script 輸出的 JSON 中提取
# 從之前的輸出可以看到 created 列表中有多個對象
# Package ID 是 type: "published" 的那個

print("根據部署輸出，查找 Package ID...")
print("\n從部署腳本輸出中，我看到創建了多個對象")
print("Package 對象通常是 'published' 類型")

# 我需要從實際的 JSON 輸出中找到 packageId
# 讓我直接使用部署腳本保存的臨時文件（如果有的話）
