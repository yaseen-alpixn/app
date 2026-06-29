/**
 * Strips HTML tags and trims whitespace to prevent code injection.
 * @param {string} text 
 * @returns {string}
 */
const sanitizeText = (text) => {
  if (typeof text !== 'string') return '';
  return text
    .replace(/<[^>]*>/g, '') // Simple regex to strip HTML tags
    .trim();
};

module.exports = { sanitizeText };
