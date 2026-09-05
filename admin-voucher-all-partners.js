(() => {
  'use strict';

  function install() {
    const partnerSelect = document.getElementById('voucherPartner');
    const search = document.getElementById('voucherSearch');
    const status = document.getElementById('voucherStatus');
    const dateFrom = document.getElementById('voucherDateFrom');
    const dateTo = document.getElementById('voucherDateTo');
    const exportBtn = document.getElementById('exportVoucherExcel');
    const clearBtn = document.getElementById('clearVoucherFilters');
    if (!partnerSelect || !search || !status || !dateFrom || !dateTo || !exportBtn || !clearBtn) return false;

    if (![...partnerSelect.options].some(o => o.value === 'ALL')) {
      const opt = document.createElement('option');
      opt.value = 'ALL';
      opt.textContent = 'All Partners';
      partnerSelect.insertBefore(opt, partnerSelect.firstChild);
    }
    if (partnerSelect.value === 'SELECT') partnerSelect.value = 'ALL';

    const filtered = () => {
      const q = String(search.value || '').toLowerCase();
      const sf = status.value;
      const pf = partnerSelect.value || 'ALL';
      const df = dateFrom.value;
      const dt = dateTo.value;
      const rows = typeof window.visibleVoucherRecords === 'function' ? window.visibleVoucherRecords() : (window.vouchers || []);
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

    const render = () => {
      const list = filtered();
      const c = { VALID: 0, REDEEMED: 0, EXPIRED: 0 };
      list.forEach(v => { c[window.voucherEffectiveStatus(v)] = (c[window.voucherEffectiveStatus(v)] || 0) + 1; });
      document.getElementById('vTotal').textContent = list.length;
      document.getElementById('vValid').textContent = c.VALID || 0;
      document.getElementById('vRedeemed').textContent = c.REDEEMED || 0;
      document.getElementById('vExpired').textContent = c.EXPIRED || 0;
      const box = document.getElementById('voucherRecords');
      box.innerHTML = list.length ? list.map(v => {
        const st = window.voucherEffectiveStatus(v);
        return `<div class="vrecord"><div class="vtop"><div style="flex:1"><div class="vcode">${window.esc(v.voucher_code || v.id)}</div><div class="pcode">${window.esc(window.engineLabel(v))}</div></div><span class="vstatus ${st.toLowerCase()}">${st}</span></div><div class="vmeta"><b>Customer:</b> ${window.esc(v.customer_name || '—')}<br><b>Partner:</b> ${window.esc(window.partnerNameFor(v))}<br><b>Type:</b> ${window.esc(window.engineLabel(v))}<br><b>Valid Until:</b> ${window.esc(v.expiry_date || '—')}<br><b>Redeem at:</b> ${window.esc(window.branchLabel(v))}${v.redeemed_at ? `<br><b>Redeemed At:</b> ${window.esc(new Date(v.redeemed_at).toLocaleString(navigator.language || 'en-US'))}` : ''}</div></div>`;
      }).join('') : '<p class="sub">No voucher records found.</p>';
    };

    const exportExcel = () => {
      const list = filtered();
      if (!list.length) {
        if (typeof window.msg === 'function') window.msg(document.getElementById('voucherMsg'), 'No records to export.');
        return;
      }
      if (typeof XLSX === 'undefined') {
        if (typeof window.msg === 'function') window.msg(document.getElementById('voucherMsg'), 'Excel exporter failed to load.');
        return;
      }
      const rows = list.map(v => {
        const ver = (window.voucherVersions || []).find(x => x.id === v.version_id);
        const tmp = ver && (window.voucherTemplates || []).find(x => x.id === ver.template_id);
        return {
          'Voucher Code': v.voucher_code || '',
          'Status': window.voucherEffectiveStatus(v),
          'Customer': v.customer_name || '',
          'Phone': v.customer_phone || '',
          'Partner': window.partnerNameFor(v),
          'Voucher Type': window.engineLabel(v),
          'Template Code': tmp?.template_code || '',
          'Version': ver ? `V${ver.version_no} ${ver.version_name || ''}` : '',
          'Valid Until': v.expiry_date || '',
          'Redeem At': window.branchLabel(v),
          'Issued At': v.issued_at || '',
          'Redeemed At': v.redeemed_at || ''
        };
      });
      const ws = XLSX.utils.json_to_sheet(rows);
      const wb = XLSX.utils.book_new();
      XLSX.utils.book_append_sheet(wb, ws, 'Voucher Records');
      XLSX.writeFile(wb, `commercial-vouchers-${new Date().toISOString().slice(0,10)}.xlsx`);
    };

    window.filteredVouchers = filtered;
    window.renderVouchers = render;
    window.exportVoucherExcel = exportExcel;

    partnerSelect.onchange = render;
    search.oninput = render;
    status.onchange = render;
    dateFrom.onchange = render;
    dateTo.onchange = render;
    exportBtn.onclick = exportExcel;
    clearBtn.onclick = () => {
      search.value = '';
      status.value = 'ALL';
      partnerSelect.value = 'ALL';
      dateFrom.value = '';
      dateTo.value = '';
      render();
    };

    render();
    return true;
  }

  let tries = 0;
  const timer = setInterval(() => {
    tries += 1;
    if (install() || tries >= 40) clearInterval(timer);
  }, 250);
})();
