// 直接在 Dashboard 登入頁面的 Console 執行這段代碼
// 會自動獲取 token 並跳轉到 Dashboard

(async function() {
    console.log('🚀 開始自動登入...');

    try {
        // Step 1: 清除舊的 token
        console.log('📦 清除舊資料...');
        localStorage.clear();

        // Step 2: 登入
        console.log('🔐 登入中...');
        const response = await fetch('http://localhost:8000/api/v1/admin/auth/login', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                email: 'admin@autodrive.com',
                password: 'admin123'
            })
        });

        console.log('📡 Response status:', response.status);

        if (!response.ok) {
            const errorText = await response.text();
            console.error('❌ 登入失敗:', errorText);
            throw new Error(`HTTP ${response.status}: ${errorText}`);
        }

        const data = await response.json();
        console.log('✅ 登入成功!');
        console.log('👤 管理員:', data.admin);

        // Step 3: 保存 token
        console.log('💾 保存 token...');
        localStorage.setItem('adminToken', data.token);
        localStorage.setItem('adminData', JSON.stringify(data.admin));

        console.log('🎉 完成! 正在跳轉到 Dashboard...');

        // Step 4: 跳轉
        setTimeout(() => {
            window.location.href = '/dashboard';
        }, 500);

    } catch (error) {
        console.error('❌ 錯誤:', error);
        console.error('📋 錯誤詳情:', error.message);

        // 顯示友善的錯誤訊息
        alert(`❌ 登入失敗！\n\n錯誤: ${error.message}\n\n請確認:\n1. 後端服務正在運行\n2. 網路連線正常\n3. 帳號密碼正確`);
    }
})();
