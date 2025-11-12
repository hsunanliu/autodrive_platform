// dashboard/src/components/IPFSFileUpload.jsx
import React, { useState, useRef } from 'react';
import { Upload, X, FileText, Image, File, CheckCircle, AlertCircle } from 'lucide-react';
import './IPFSFileUpload.css';

/**
 * IPFS File Upload Component
 *
 * Features:
 * - Drag & drop support
 * - File preview (images)
 * - Size validation (max 10MB)
 * - Type validation (images, PDF, text)
 * - Upload progress
 * - IPFS CID display
 */
const IPFSFileUpload = ({
  onFileSelect,
  onUploadSuccess,
  onUploadError,
  maxSize = 10 * 1024 * 1024, // 10MB
  acceptedTypes = ['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'application/pdf', 'text/plain'],
  purpose = 'refund_evidence',
  relatedId = null,
  autoUpload = false,
}) => {
  const [selectedFile, setSelectedFile] = useState(null);
  const [preview, setPreview] = useState(null);
  const [uploading, setUploading] = useState(false);
  const [uploadResult, setUploadResult] = useState(null);
  const [error, setError] = useState(null);
  const [dragActive, setDragActive] = useState(false);
  const fileInputRef = useRef(null);

  // Get file icon based on type
  const getFileIcon = (type) => {
    if (type.startsWith('image/')) return <Image className="file-icon image" />;
    if (type === 'application/pdf') return <FileText className="file-icon pdf" />;
    return <File className="file-icon" />;
  };

  // Format file size
  const formatFileSize = (bytes) => {
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(2) + ' KB';
    return (bytes / (1024 * 1024)).toFixed(2) + ' MB';
  };

  // Validate file
  const validateFile = (file) => {
    if (!file) {
      setError('請選擇文件');
      return false;
    }

    if (file.size > maxSize) {
      setError(`文件過大，最大允許 ${formatFileSize(maxSize)}`);
      return false;
    }

    if (!acceptedTypes.includes(file.type)) {
      setError(`不支援的文件類型: ${file.type}`);
      return false;
    }

    setError(null);
    return true;
  };

  // Handle file selection
  const handleFileSelect = (file) => {
    if (!validateFile(file)) return;

    setSelectedFile(file);
    setUploadResult(null);

    // Create preview for images
    if (file.type.startsWith('image/')) {
      const reader = new FileReader();
      reader.onloadend = () => {
        setPreview(reader.result);
      };
      reader.readAsDataURL(file);
    } else {
      setPreview(null);
    }

    // Notify parent component
    if (onFileSelect) {
      onFileSelect(file);
    }

    // Auto upload if enabled
    if (autoUpload) {
      uploadFile(file);
    }
  };

  // Handle file input change
  const handleInputChange = (e) => {
    if (e.target.files && e.target.files[0]) {
      handleFileSelect(e.target.files[0]);
    }
  };

  // Handle drag events
  const handleDrag = (e) => {
    e.preventDefault();
    e.stopPropagation();
    if (e.type === 'dragenter' || e.type === 'dragover') {
      setDragActive(true);
    } else if (e.type === 'dragleave') {
      setDragActive(false);
    }
  };

  // Handle drop
  const handleDrop = (e) => {
    e.preventDefault();
    e.stopPropagation();
    setDragActive(false);

    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      handleFileSelect(e.dataTransfer.files[0]);
    }
  };

  // Upload file to IPFS
  const uploadFile = async (file = selectedFile) => {
    if (!file) {
      setError('請先選擇文件');
      return;
    }

    setUploading(true);
    setError(null);

    try {
      const formData = new FormData();
      formData.append('file', file);
      formData.append('purpose', purpose);
      if (relatedId) {
        formData.append('related_id', relatedId);
      }

      const token = localStorage.getItem('token');
      const response = await fetch(`${import.meta.env.VITE_API_URL}/api/v1/ipfs/upload`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
        },
        body: formData,
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.detail || '上傳失敗');
      }

      const result = await response.json();
      setUploadResult(result);

      if (onUploadSuccess) {
        onUploadSuccess(result);
      }
    } catch (err) {
      setError(err.message);
      if (onUploadError) {
        onUploadError(err);
      }
    } finally {
      setUploading(false);
    }
  };

  // Clear selection
  const clearSelection = () => {
    setSelectedFile(null);
    setPreview(null);
    setUploadResult(null);
    setError(null);
    if (fileInputRef.current) {
      fileInputRef.current.value = '';
    }
  };

  return (
    <div className="ipfs-file-upload">
      {/* Upload Area */}
      {!selectedFile && !uploadResult && (
        <div
          className={`upload-area ${dragActive ? 'drag-active' : ''}`}
          onDragEnter={handleDrag}
          onDragLeave={handleDrag}
          onDragOver={handleDrag}
          onDrop={handleDrop}
          onClick={() => fileInputRef.current?.click()}
        >
          <Upload className="upload-icon" />
          <p className="upload-text">拖放文件到此處，或點擊選擇文件</p>
          <p className="upload-hint">
            支援：JPG, PNG, GIF, WebP, PDF, TXT（最大 {formatFileSize(maxSize)}）
          </p>
          <input
            ref={fileInputRef}
            type="file"
            accept={acceptedTypes.join(',')}
            onChange={handleInputChange}
            style={{ display: 'none' }}
          />
        </div>
      )}

      {/* Selected File Preview */}
      {selectedFile && !uploadResult && (
        <div className="file-preview">
          <div className="file-info">
            {preview ? (
              <img src={preview} alt="預覽" className="file-preview-image" />
            ) : (
              getFileIcon(selectedFile.type)
            )}
            <div className="file-details">
              <p className="file-name">{selectedFile.name}</p>
              <p className="file-size">{formatFileSize(selectedFile.size)}</p>
            </div>
            <button
              className="btn-clear"
              onClick={clearSelection}
              disabled={uploading}
            >
              <X size={20} />
            </button>
          </div>

          {!autoUpload && (
            <button
              className="btn-upload"
              onClick={() => uploadFile()}
              disabled={uploading}
            >
              {uploading ? '上傳中...' : '上傳到 IPFS'}
            </button>
          )}

          {uploading && (
            <div className="upload-progress">
              <div className="progress-bar">
                <div className="progress-fill"></div>
              </div>
              <p>正在上傳到 IPFS...</p>
            </div>
          )}
        </div>
      )}

      {/* Upload Result */}
      {uploadResult && uploadResult.success && (
        <div className="upload-result success">
          <CheckCircle className="result-icon" />
          <div className="result-info">
            <h4>上傳成功</h4>
            <p className="cid-label">IPFS CID:</p>
            <code className="cid-value">{uploadResult.cid}</code>
            <p className="file-name">{uploadResult.filename}</p>
            <p className="file-size">{formatFileSize(uploadResult.size)}</p>
            {uploadResult.ipfs_url && (
              <a
                href={uploadResult.ipfs_url}
                target="_blank"
                rel="noopener noreferrer"
                className="view-link"
              >
                在 IPFS 上查看
              </a>
            )}
          </div>
          <button className="btn-clear" onClick={clearSelection}>
            <X size={20} />
          </button>
        </div>
      )}

      {/* Error Display */}
      {error && (
        <div className="upload-error">
          <AlertCircle className="error-icon" />
          <p>{error}</p>
        </div>
      )}
    </div>
  );
};

export default IPFSFileUpload;
