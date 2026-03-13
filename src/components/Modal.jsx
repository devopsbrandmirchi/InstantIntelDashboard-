import React, { useEffect } from 'react';

const Modal = ({ isOpen, onClose, title, children, size }) => {
  useEffect(() => {
    const handleEscape = (e) => {
      if (e.key === 'Escape') onClose();
    };
    if (isOpen) {
      document.addEventListener('keydown', handleEscape);
      document.body.style.overflow = 'hidden';
    }
    return () => {
      document.removeEventListener('keydown', handleEscape);
      document.body.style.overflow = '';
    };
  }, [isOpen, onClose]);

  if (!isOpen) return null;

  const maxWidthClass = size === 'lg' ? 'max-w-3xl' : 'max-w-md';

  return (
    <div
      className="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50 flex items-start justify-center p-4 sm:pt-10 sm:pb-10"
      onClick={(e) => e.target === e.currentTarget && onClose()}
    >
      <div
        className={`relative mx-auto p-4 sm:p-5 border w-full ${maxWidthClass} shadow-lg rounded-md bg-white my-4 sm:my-0 max-h-[calc(100vh-2rem)] overflow-y-auto`}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex justify-between items-center mb-4">
          <h3 className="text-base font-semibold text-gray-800">{title}</h3>
          <button
            type="button"
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600 p-1"
            aria-label="Close"
          >
            <i className="fas fa-times"></i>
          </button>
        </div>
        {children}
      </div>
    </div>
  );
};

export default Modal;
