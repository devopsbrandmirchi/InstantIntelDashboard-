import React from 'react';
import { Link } from 'react-router-dom';

const AdminAccessDenied = () => {
  return (
    <div className="min-h-screen flex items-center justify-center bg-slate-50 px-4">
      <div className="w-full max-w-md rounded-xl border border-amber-200 bg-amber-50 p-6 shadow-sm">
        <div className="flex items-center gap-2 text-amber-800 mb-3">
          <i className="fas fa-shield-alt" aria-hidden="true" />
          <h1 className="text-base font-semibold">Access denied (admin only)</h1>
        </div>
        <p className="text-sm text-amber-900 mb-4">
          You do not have permission to open this page. Contact an administrator if you need access.
        </p>
        <Link
          to="/dashboard"
          className="inline-flex items-center gap-2 px-3 py-2 text-sm rounded-md bg-slate-700 text-white hover:bg-slate-800"
        >
          <i className="fas fa-arrow-left" aria-hidden="true" />
          Back to Dashboard
        </Link>
      </div>
    </div>
  );
};

export default AdminAccessDenied;
