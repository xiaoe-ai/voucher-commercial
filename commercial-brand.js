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

  const LEGACY_VISIBLE_REPLACEMENTS = [
    ['EO-20260808-XXXXXXX', 'Enter voucher code'],
    ['Evolution Optical', 'Commercial Voucher'],
    ['EVOLUTION OPTICAL', 'COMMERCIAL VOUCHER'],
    ['FREE GLASSES', 'SPECIAL VOUCHER']
  ];

  function installCommercialThemeApiAlias() {
    if (window.CommercialVoucherThemes) return true;
    if (window.EOVoucherThemes) {
      window.CommercialVoucherThemes = window.EOVoucherThemes;
      return true;
    }
    return false;
  }

  function watchCommercialThemeApi() {
    if (installCommercialThemeApiAlias()) return;
    let attempts = 0;
    const timer = setInterval(() => {
      attempts += 1;
      if (installCommercialThemeApiAlias() || attempts >= 80) clearInterval(timer);
    }, 100);
  }

  function installPartnerBranchCutover() {
    if (!/\/partner(?:-launch|-install)?\.html$/i.test(location.pathname) && !/\/partner\.html$/i.test(location.pathname)) return;
    if (window.__commercialPartnerBranchCutoverInstalled) return;

    const tryInstall = () => {
      if (typeof window.loadBranchDirectory !== 'function' || typeof window.redemptionCodesFor !== 'function' || typeof window.outletSummaryFor !== 'function') return false;

      window.loadBranchDirectory = async function() {
        const extendedFields = 'id,branch_code,branch_name,status,address_line1,address_line2,city,state,postcode,country,phone,whatsapp,map_url';
        let result = await db.from('branches').select(extendedFields).eq('status', 'active');
        if (result.error) {
          result = await db.from('branches').select('id,branch_code,branch_name,status').eq('status', 'active');
        }
        if (result.error) return;

        branchDirectory = {};
        (result.data || []).forEach(b => {
          const addressParts = [b.address_line1, b.address_line2, b.postcode, b.city, b.state, b.country]
            .map(v => String(v || '').trim())
            .filter(Boolean);
          branchDirectory[b.branch_code] = {
            name: cleanOutletName(b.branch_name || b.branch_code),
            address: addressParts.join(', '),
            phone: String(b.phone || '').trim(),
            whatsapp: String(b.whatsapp || '').trim(),
            map_url: String(b.map_url || '').trim()
          };
        });
      };

      window.redemptionCodesFor = function(o) {
        if (!o) return [];
        const versionCodes = o.version_branch_codes || [];
        if (partnerClaimAll && o.all_branches) return Object.keys(branchDirectory);
        if (partnerClaimAll && !o.all_branches) return versionCodes.filter(c => !!branchDirectory[c]);
        if (!partnerClaimAll && o.all_branches) return partnerClaimCodes.filter(c => !!branchDirectory[c]);
        return partnerClaimCodes.filter(c => versionCodes.includes(c) && !!branchDirectory[c]);
      };

      window.outletSummaryFor = function(o) {
        const codes = window.redemptionCodesFor(o);
        return { details: codes.map(c => branchDirectory[c]).filter(Boolean) };
      };

      window.__commercialPartnerBranchCutoverInstalled = true;
      return true;
    };

    if (tryInstall()) return;
    let attempts = 0;
    const timer = setInterval(() => {
      attempts += 1;
      if (tryInstall() || attempts >= 80) clearInterval(timer);
    }, 100);
  }

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
    const dbClient = getDb();
    if (!dbClient) return null;
    const { data, error } = await dbClient.from('company_profile').select('*').eq('id', 'default').maybeSingle();
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
    installExportGuard(next);
    installLegacyVisibleGuard();
    watchCommercialThemeApi();
    installPartnerBranchCutover();
    window.dispatchEvent(new CustomEvent('commercial-company-profile-changed', { detail: next }));

    const dbClient = getDb();
    if (!dbClient) return { profile: next, synced: false, reason: 'supabase_client_unavailable' };

    try {
      const { error } = await dbClient.from('company_profile').upsert(toRow(next), { onConflict: 'id' });
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

  function scrubLegacyVisibleText() {
    const root = document.body || document.documentElement;
    LEGACY_VISIBLE_REPLACEMENTS.forEach(([from, to]) => replaceText(root, from, to));
    document.querySelectorAll('input[placeholder], textarea[placeholder]').forEach(el => {
      const p = el.getAttribute('placeholder') || '';
      if (/^EO[-_]/i.test(p) || /evolution optical/i.test(p)) el.setAttribute('placeholder', 'Enter voucher code');
    });
  }

  function installLegacyVisibleGuard() {
    scrubLegacyVisibleText();
    if (window.__commercialLegacyVisibleGuardInstalled) return;
    window.__commercialLegacyVisibleGuardInstalled = true;
    const observer = new MutationObserver(() => scrubLegacyVisibleText());
    observer.observe(document.documentElement, { childList: true, subtree: true, characterData: true, attributes: true, attributeFilter: ['placeholder'] });
  }

  function slugifyCompanyName(value) {
    const slug = String(value || DEFAULTS.companyName)
      .trim()
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '');
    return slug || 'commercial';
  }

  function commercialExportFilename(date = new Date(), profile = loadLocal()) {
    return `${slugifyCompanyName(profile.companyName)}-vouchers-${date.toISOString().slice(0, 10)}.xlsx`;
  }

  function installExportGuard(profile = loadLocal()) {
    if (window.__commercialExportGuardInstalled) return;
    const tryInstall = () => {
      if (!window.XLSX?.writeFile) return false;
      const original = window.XLSX.writeFile.bind(window.XLSX);
      window.XLSX.writeFile = (workbook, filename, ...rest) => {
        let nextName = String(filename || '');
        if (!nextName || /evolution[-_ ]?vouchers/i.test(nextName) || /^commercial[-_ ]?vouchers/i.test(nextName)) {
          nextName = commercialExportFilename(new Date(), loadLocal());
        }
        return original(workbook, nextName, ...rest);
      };
      window.__commercialExportGuardInstalled = true;
      return true;
    };
    if (tryInstall()) return;
    let attempts = 0;
    const timer = setInterval(() => {
      attempts += 1;
      if (tryInstall() || attempts >= 40) clearInterval(timer);
    }, 250);
  }

  function apply(profile = loadLocal()) {
    const name = profile.companyName || DEFAULTS.companyName;
    const legal = profile.companyLegalName || '';
    const tagline = profile.tagline || DEFAULTS.tagline;
    const root = document.body || document.documentElement;

    document.documentElement.dataset.commercialCompany = name;
    document.querySelectorAll('[data-company-name]').forEach(el => { el.textContent = name; });
    document.querySelectorAll('[data-company-legal-name]').forEach(el => { el.textContent = legal || name; });
    document.querySelectorAll('[data-company-tagline]').forEach(el => { el.textContent = tagline; });

    replaceText(root, 'YOUR COMPANY', name.toUpperCase());
    replaceText(root, 'Your Company', name);
    replaceText(root, 'Commercial Voucher Admin', `${name} Admin`);
    replaceText(root, 'Commercial Voucher', `${name} Voucher`);
    replaceText(root, 'FREE GLASSES', 'SPECIAL VOUCHER');
    replaceText(root, 'Sdn Bhd', legal || tagline || name);

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
    scrubLegacyVisibleText();
  }

  async function reset() {
    localStorage.removeItem(KEY);
    apply(DEFAULTS);
    installExportGuard(DEFAULTS);
    installLegacyVisibleGuard();
    watchCommercialThemeApi();
    installPartnerBranchCutover();
    const dbClient = getDb();
    if (!dbClient) return;
    try { await dbClient.from('company_profile').upsert(toRow(DEFAULTS), { onConflict: 'id' }); } catch (_) {}
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
    reset,
    slugifyCompanyName,
    commercialExportFilename,
    scrubLegacyVisibleText,
    installCommercialThemeApiAlias,
    installPartnerBranchCutover
  };

  const boot = async () => {
    const profile = loadLocal();
    apply(profile);
    installExportGuard(profile);
    installLegacyVisibleGuard();
    watchCommercialThemeApi();
    installPartnerBranchCutover();
    await load();
  };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
  else boot();
})();
