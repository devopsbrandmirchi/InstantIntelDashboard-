/**
 * Race a promise against a timeout so requests don't hang indefinitely.
 * @param {Promise} promise - The request promise (e.g. supabase.from(...).select())
 * @param {number} ms - Timeout in milliseconds
 * @param {string} message - Error message if timeout wins
 * @returns {Promise} - Resolves like the original promise; rejects on timeout
 */
export function withTimeout(promise, ms = 20000, message = 'Request timed out. Please refresh the page.') {
  return Promise.race([
    promise,
    new Promise((_, reject) =>
      setTimeout(() => reject(new Error(message)), ms)
    )
  ]);
}
