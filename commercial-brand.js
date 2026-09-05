(() => {
  'use strict';
  const KEY = 'commercial_voucher_company_profile_v1';
  const SUPABASE_URL = 'https://hukihbcyyqhanaqrizvm.supabase.co';
  const SUPABASE_ANON_KEY = 'sb_publishable_kpPFeGYpedq2auo01Zo50A_aiSjdeVh';
  const DEFAULTS = {
    companyName: 'Your Company',
    companyLegalName: '',
    registrationNo: '',
    tagline: 'Voucher Platform',
    phone: '',
    website: '',
    logoUrl: ''
  };

  function fromRow(row = {}) {
    return {
      companyName: row.company_name || DEFAULTS.companyName,
      companyLegalName: row.company_legal_name || '',
      registrationNo: row.registration_no || '',
      tagline: row.tagline || DEFAULTS.tagline,
      phone: row.phone || '',
      website: row.website || '',
      logoUrl: row.logo_url || ''
    };
  }

  function toRow(profile = {}) {
    const p = { ...DEFAULTS, ...profile };
    return {
      id: 'default',
      company_name: String(p.companyName || '').trim() || DEFAULTS.companyName,
      company_legal_name: String(p.companyLegalName || '').trim() || null,
      registration_no: String(p.registrationNo || '').trim() || null,
      tagline: String(p.tagline || '').trim() || DEFAULTS.tagline,
      phone: String(p.phone || '').trim() || null,
      website: String(p.website || '').trim() || null,
      logo_url: String(p.logoUrl || '').trim() || null
    };
  }

  function loadLocal() {
    try {
      const saved = JSON.parse(localStorage.getItem(KEY) || '{}');
      return { ...DEFAULTS, ...saved };
    } catch (_) {
      return { ...DEFAULTS };
    }
  }

  function saveLocal(profile) {
    const next = { ...DEFAULTS, ...(profile || {}) };
    next.companyName = String(next.companyName || '').trim() || DEFAULTS.companyName;
    localStorage.setItem(KEY, JSON.stringify(next));
    return next;
  }

  function getDb() {
    if (!window.supabase?.createClient) return null;
    if (!window.__commercialCompanyProfileDb) {
      window.__commercialCompanyProfileDb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
        auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
      });
    }
    return window.__commercialCompanyProfileDb;
  }

  async function loadRemote() {
    const db = getDb();
    if (!db) return null;
    const { data, error } = await db.from('company_profile').select('*').eq('id', 'default').maybeSingle();
    if (error) throw error;
    return data ? fromRow(data) : null;
  }

  async function load() {
    let profile = loadLocal();
    try {
      const remote = await loadRemote();
      if (remote) {
        profile = saveLocal(remote);
        apply(profile);
      }
    } catch (_) {
      apply(profile);
    }
    return profile;
  }

  async function save(profile) {
    const next = saveLocal(profile);
    apply(next);
    window.dispatchEvent(new CustomEvent('commercial-company-profile-changed', { detail: next }));

    const db = getDb();
    if (!db) return { profile: next, synced: false, reason: 'supabase_client_unavailable' };

    try {
      const { error } = await db.from('company_profile').upsert(toRow(next), { onConflict: 'id' });
      if (error) throw error;
      return { profile: next, synced: true };
    } catch (error) {
      return { profile: next, synced: false, reason: error?.message || 'sync_failed' };
    }
  }

  function replaceText(root, from, to) {
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
    const nodes = [];
    while (walker.nextNode()) nodes.push(walker.currentNode);
    nodes.forEach(node => {
      if (node.nodeValue && node.nodeValue.includes(from)) node.nodeValue = node.nodeValue.split(from).join(to);
    });
  }

  function apply(profile = loadLocal()) {
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

  async function reset() {
    localStorage.removeItem(KEY);
    apply(DEFAULTS);
    const db = getDb();
    if (!db) return;
    try { await db.from('company_profile').upsert(toRow(DEFAULTS), { onConflict: 'id' }); } catch (_) {}
  }

  window.CommercialCompanyProfile = {
    KEY,
    DEFAULTS,
    SUPABASE_URL,
    load,
    loadLocal,
    loadRemote,
    save,
    apply,
    reset
  };

  const boot = async () => { apply(loadLocal()); await load(); };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
  else boot();
})();
