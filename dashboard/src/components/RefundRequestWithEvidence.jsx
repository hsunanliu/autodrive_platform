// dashboard/src/components/RefundRequestWithEvidence.jsx
import React, { useState } from 'react';
import IPFSFileUpload from './IPFSFileUpload';
import './RefundRequestWithEvidence.css';

/**
 * Refund Request Form with IPFS Evidence Upload
 *
 * Integrates IPFS file upload with refund request creation
 */
const RefundRequestWithEvidence = ({ tripId, onSuccess, onCancel }) => {
  const [reason, setReason] = useState('');
  const [refundAmount, setRefundAmount] = useState('');
  const [evidenceFile, setEvidenceFile] = useState(null);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState(null);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError(null);

    // Validation
    if (!reason || reason.length < 10) {
      setError('退款原因至少需要 10 個字');
      return;
    }

    if (!refundAmount || parseFloat(refundAmount) <= 0) {
      setError('請輸入有效的退款金額');
      return;
    }

    setUploading(true);

    try {
      // Prepare form data
      const formData = new FormData();
      formData.append('trip_id', tripId);
      formData.append('reason', reason);
      formData.append('refund_amount_sui', refundAmount);

      // Add evidence file if selected
      if (evidenceFile) {
        formData.append('evidence_file', evidenceFile);
      }

      // Submit refund request
      const token = localStorage.getItem('token');
      const response = await fetch(`${import.meta.env.VITE_API_URL}/api/v1/refunds/create`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
        },
        body: formData,
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.detail || '提交失敗');
      }

      const result = await response.json();

      if (result.success) {
        if (onSuccess) {
          onSuccess(result.data);
        }
      } else {
        throw new Error(result.error || '提交失敗');
      }
    } catch (err) {
      setError(err.message);
    } finally {
      setUploading(false);
    }
  };

  return (
    <div className="refund-request-form">
      <h3>申請退款</h3>

      <form onSubmit={handleSubmit}>
        {/* Trip ID */}
        <div className="form-group">
          <label>行程 ID</label>
          <input
            type="text"
            value={tripId}
            disabled
            className="form-input disabled"
          />
        </div>

        {/* Refund Amount */}
        <div className="form-group">
          <label htmlFor="refundAmount">
            退款金額 (SUI) <span className="required">*</span>
          </label>
          <input
            id="refundAmount"
            type="number"
            step="0.01"
            min="0"
            value={refundAmount}
            onChange={(e) => setRefundAmount(e.target.value)}
            placeholder="輸入退款金額"
            required
            className="form-input"
          />
        </div>

        {/* Reason */}
        <div className="form-group">
          <label htmlFor="reason">
            退款原因 <span className="required">*</span>
          </label>
          <textarea
            id="reason"
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            placeholder="請詳細說明退款原因（至少 10 個字）"
            rows={4}
            minLength={10}
            required
            className="form-textarea"
          />
          <p className="field-hint">{reason.length} / 至少 10 個字</p>
        </div>

        {/* Evidence Upload */}
        <div className="form-group">
          <label>
            退款證據（選填）
          </label>
          <p className="field-description">
            上傳圖片、PDF 或文字文件作為退款證據。文件將安全存儲在 IPFS 網絡中。
          </p>
          <IPFSFileUpload
            onFileSelect={(file) => setEvidenceFile(file)}
            purpose="refund_evidence"
            relatedId={tripId}
            autoUpload={false}
          />
        </div>

        {/* Error Display */}
        {error && (
          <div className="form-error">
            {error}
          </div>
        )}

        {/* Actions */}
        <div className="form-actions">
          <button
            type="button"
            onClick={onCancel}
            className="btn-cancel"
            disabled={uploading}
          >
            取消
          </button>
          <button
            type="submit"
            className="btn-submit"
            disabled={uploading}
          >
            {uploading ? '提交中...' : '提交退款申請'}
          </button>
        </div>
      </form>
    </div>
  );
};

export default RefundRequestWithEvidence;
