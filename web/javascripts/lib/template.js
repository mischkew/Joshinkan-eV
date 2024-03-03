/**
 * Find a template by id tag in the DOM and deep clone it's content. Returns
 * null if the template cannot be found.
 *
 * @param {string} templateId The id of the template element
 * @returns {HTMLElement}
 */
export function loadTemplate(templateId) {
  const template = document.getElementById(templateId);
  if (!template) return null;
  return template.content.cloneNode(true);
}
