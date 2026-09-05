(() => {
  'use strict';
  const KEY = 'commercial_voucher_company_profile_v1';
  const DEFAULTS = {
    companyName: 'Your Company',
    companyLegalName: '',
    registrationNo: '',
    tagline: 'Voucher Platform',
    phone: '',
    website: '',
    logoUrl: ''
  };

  function load() {
    try {
      const saved = JSON.parse(localStorage.getItem(KEY) || '{}');
      return { ...DEFAULTS, ...saved };
    } catch (_) {
      return { ...DEFAULTS };
    }
  }

  function save(profile) {
    const next = { ...DEFAULTS, ...(profile || {}) };
    next.companyName = String(next.companyName || '').trim() || DEFAULTS.companyName;
    localStorage.setItem(KEY, JSON.stringify(next));
    apply(next);
    window.dispatchEvent(new CustomEvent('commercial-company-profile-changed', { detail: next }));
    return next;
  }

  function replaceText(root, from, to) {
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
    const nodes = [];
    while (walker.nextNode()) nodes.push(walker.currentNode);
    nodes.forEach(node => {
      if (node.nodeValue && node.nodeValue.includes(from)) node.nodeValue = node.nodeValue.split(from).join(to);
    });
  }

  function apply(profile = load()) {
    const name = profile.companyName || DEFAULTS.companyName;
    const legal = profile.companyLegalName || '';
    const tagline = profile.tagline || DEFAULTS.tagline;

    document.documentElement.dataset.commercialCompany = name;
    document.querySelectorAll('[data-company-name]').forEach(el => { el.textContent = name; });
    document.querySelectorAll('[data-company-legal-name]').forEach(el => { el.textContent = legal || name; });
    document.querySelectorAll('[data-company-tagline]').forEach(el => { el.textContent = tagline; });

    replaceText(document.body || document.documentElement, 'YOUR COMPANY', name.toUpperCase());
    replaceText(document.body || document.documentElement, 'Your Company', name);
    replaceText(document.body || document.documentElement, 'Commercial Voucher Admin', `${name} Admin`);
    replaceText(document.body || document.documentElement, 'Commercial Voucher', `${name} Voucher`);

    if (document.title.includes('Your Company')) document.title = document.title.replaceAll('Your Company', name);
    if (document.title.includes('Commercial Voucher')) document.title = document.title.replace('Commercial Voucher', `${name} Voucher`);

    document.querySelectorAll('[data-company-logo]').forEach(img => {
      if (profile.logoUrl) {
        img.src = profile.logoUrl;
        img.hidden = false;
      } else {
        img.hidden = true;
      }
    });
  }

  window.CommercialCompanyProfile = { KEY, DEFAULTS, load, save, apply, reset: () => { localStorage.removeItem(KEY); apply(DEFAULTS); } };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', () => apply());
  else apply();
})();