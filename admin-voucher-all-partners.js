(() => {
  'use strict';

  function install() {
    const partnerSelect = document.getElementById('voucherPartner');
    const search = document.getElementById('voucherSearch');
    const status = document.getElementById('voucherStatus');
    const dateFrom = document.getElementById('voucherDateFrom');
    const dateTo = document.getElementById('voucherDateTo');
    if (!partnerSelect || !search || !status || !dateFrom || !dateTo) return false;
    if (window.__commercialVoucherAllPartnersInstalled) return true;
    window.__commercialVoucherAllPartnersInstalled = true;

    const ensureAllOption = () => {
      const hadAll = [...partnerSelect.options].some(o => o.value === 'ALL');
      if (!hadAll) {
        const opt = document.createElement('option');
        opt.value = 'ALL';
        opt.textContent = 'All Partners';
        partnerSelect.insertBefore(opt, partnerSelect.firstChild);
      }
      if (!partnerSelect.value || partnerSelect.value === 'SELECT') partnerSelect.value = 'ALL';
    };

    ensureAllOption();

    const filteredAllPartners = () => {
      const q = String(search.value || '').toLowerCase();
      const sf = status.value;
      const pf = partnerSelect.value || 'ALL';
      const df = dateFrom.value;
      const dt = dateTo.value;
      const rows = typeof window.visibleVoucherRecords === 'function' ? window.visibleVoucherRecords() : [];
      return rows.filter(v => {
        const st = window.voucherEffectiveStatus(v);
        const hay = [v.voucher_code, v.customer_name, v.customer_phone, window.partnerNameFor(v), v.voucher_type, window.engineLabel(v)].join(' ').toLowerCase();
        const pid = String(v.partner_id || v.issued_by_partner_id || '');
        const d = v.issued_at ? new Date(v.issued_at) : null;
        return (!q || hay.includes(q)) &&
          (sf === 'ALL' || st === sf) &&
          (pf === 'ALL' || pid === pf) &&
          (!df || (d && d >= new Date(df + 'T00:00:00'))) &&
          (!dt || (d && d <= new Date(dt + 'T23:59:59')));
      });
    };

    // Replace only the filtering rule. The original Admin render/export functions
    // remain in charge so workbook columns and existing UI behavior stay canonical.
    window.filteredVouchers = filteredAllPartners;

    const observer = new MutationObserver(() => {
      const before = partnerSelect.value;
      ensureAllOption();
      if ((before === '' || before === 'SELECT') && typeof window.renderVouchers === 'function') {
        window.renderVouchers();
      }
    });
    observer.observe(partnerSelect, { childList: true });

    partnerSelect.addEventListener('change', () => {
      ensureAllOption();
      if (typeof window.renderVouchers === 'function') window.renderVouchers();
    });

    const clearBtn = document.getElementById('clearVoucherFilters');
    if (clearBtn) {
      clearBtn.addEventListener('click', () => {
        setTimeout(() => {
          ensureAllOption();
          partnerSelect.value = 'ALL';
          if (typeof window.renderVouchers === 'function') window.renderVouchers();
        }, 0);
      });
    }

    if (typeof window.renderVouchers === 'function') window.renderVouchers();
    return true;
  }

  let tries = 0;
  const timer = setInterval(() => {
    tries += 1;
    if (install() || tries >= 40) clearInterval(timer);
  }, 250);
})();
