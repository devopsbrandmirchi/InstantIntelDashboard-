import React from 'react';

class RouteErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false };
  }

  static getDerivedStateFromError() {
    return { hasError: true };
  }

  componentDidCatch(error, info) {
    console.error('Route render crash:', error, info);
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="page-content">
          <div className="max-w-2xl mx-auto mt-8 p-4 rounded-md border border-amber-200 bg-amber-50 text-amber-900">
            <h2 className="text-sm font-semibold mb-1">Something went wrong on this page.</h2>
            <p className="text-xs mb-3">
              This is usually caused by a temporary data/render error. Refresh the page to recover.
            </p>
            <button
              type="button"
              onClick={() => window.location.reload()}
              className="px-3 py-1.5 text-xs rounded-md bg-amber-600 text-white hover:bg-amber-700"
            >
              Reload page
            </button>
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}

export default RouteErrorBoundary;
