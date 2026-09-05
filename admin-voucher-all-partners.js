(() => {
  'use strict';

  const SUPABASE_URL = 'https://hukihbcyyqhanaqrizvm.supabase.co';
  const SUPABASE_KEY = 'sb_publishable_kpPFeGYpedq2auo01Zo50A_aiSjdeVh';
  let client = null;
  let liveRows = [];
  let partnerMap = new Map();
  let branchMap = new Map();

  const esc = v => String(v ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));

  function getClient(){
    if (client) return client;
    if (!window.supabase?.createClient) return null;
    client = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY, {
      auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
    });
    return client;
  }

  function effectiveStatus(v){
    const s = String(v.status || '').toLowerCase();
    if (s === 'redeemed') return 'REDEEMED';
    if (s === 'expired' || (v.expiry_date && new Date(v.expiry_date + 'T23:59:59') < new Date())) return 'EXPIRED';
    return 'VALID';
  }

  function filteredRows(){
    const partnerSelect = document.getElementById('voucherPartner');
    const search = document.getElementById('voucherSearch');
    const status = document.getElementById('voucherStatus');
    const dateFrom = document.getElementById('voucherDateFrom');
    const dateTo = document.getElementById('voucherDateTo');
    const q = String(search?.value || '').toLowerCase();
    const sf = status?.value || 'ALL';
    const pf = partnerSelect?.value || 'ALL';
    const df = dateFrom?.value || '';
    const dt = dateTo?.value || '';
    return liveRows.filter(v => {
      const st = effectiveStatus(v);
      const pname = partnerMap.get(v.partner_id) || '';
      const hay = [v.voucher_code, v.customer_name, v.customer_phone, pname, v.voucher_type].join(' ').toLowerCase();
      const d = v.issued_at ? new Date(v.issued_at) : null;
      return (!q || hay.includes(q)) &&
        (sf === 'ALL' || st === sf) &&
        (pf === 'ALL' || String(v.partner_id || '') === pf) &&
        (!df || (d && d >= new Date(df + 'T00:00:00'))) &&
        (!dt || (d && d <= new Date(dt + 'T23:59:59')));
    });
  }

  function render(){
    const list = filteredRows();
    const counts = {VALID:0, REDEEMED:0, EXPIRED:0};
    list.forEach(v => counts[effectiveStatus(v)]++);
    const t = document.getElementById('vTotal'), va = document.getElementById('vValid'), r = document.getElementById('vRedeemed'), e = document.getElementById('vExpired');
    if (t) t.textContent = String(list.length);
    if (va) va.textContent = String(counts.VALID);
    if (r) r.textContent = String(counts.REDEEMED);
    if (e) e.textContent = String(counts.EXPIRED);
    const box = document.getElementById('voucherRecords');
    if (!box) return;
    box.innerHTML = list.length ? list.map(v => {
      const st = effectiveStatus(v);
      const pname = partnerMap.get(v.partner_id) || '—';
      const redeemBranch = v.redeemed_branch_id ? (branchMap.get(v.redeemed_branch_id) || '—') : '—';
      return `<div class="vrecord"><div class="vtop"><div style="flex:1"><div class="vcode">${esc(v.voucher_code || v.id)}</div><div class="pcode">${esc(v.voucher_type || 'Voucher')}</div></div><span class="vstatus ${st.toLowerCase()}">${st}</span></div><div class="vmeta"><b>Customer:</b> ${esc(v.customer_name || '—')}<br><b>Partner:</b> ${esc(pname)}<br><b>Type:</b> ${esc(v.voucher_type || 'Voucher')}<br><b>Valid Until:</b> ${esc(v.expiry_date || '—')}<br><b>Redeem at:</b> ${esc(redeemBranch)}${v.redeemed_at ? `<br><b>Redeemed At:</b> ${esc(new Date(v.redeemed_at).toLocaleString(navigator.language || 'en-US'))}` : ''}</div></div>`;
    }).join('') : '<p class="sub">No voucher records found.</p>';
  }

  async function loadLive(){
    const db = getClient();
    if (!db) return;
    const voucherMsg = document.getElementById('voucherMsg');
    try {
      const [vr, pr, rr, br] = await Promise.all([
        db.from('vouchers').select('id,voucher_code,partner_id,customer_name,customer_phone,voucher_type,expiry_date,status,issued_at,redeemed_at').order('issued_at',{ascending:false}).limit(1000),
        db.from('partners').select('id,partner_name,partner_code,status'),
        db.from('redemptions').select('voucher_id,branch_id,status,redeemed_at').eq('status','success'),
        db.from('branches').select('id,branch_name,branch_code,status').eq('status','active')
      ]);
      if (vr.error) throw vr.error;
      if (pr.error) throw pr.error;
      partnerMap = new Map((pr.data || []).map(p => [p.id, p.partner_name || p.partner_code]));
      branchMap = new Map((br.data || []).map(b => [b.id, b.branch_name || b.branch_code]));
      const redMap = new Map((rr.data || []).map(x => [x.voucher_id, x]));
      liveRows = (vr.data || []).map(v => ({...v, redeemed_branch_id: redMap.get(v.id)?.branch_id || null}));

      const sel = document.getElementById('voucherPartner');
      if (sel) {
        const current = sel.value;
        sel.innerHTML = '<option value="ALL">All Partners</option>' + (pr.data || [])
          .filter(p => String(p.partner_code || '').toUpperCase() !== 'ADMIN' && String(p.status || '').toLowerCase() === 'active')
          .map(p => `<option value="${esc(p.id)}">${esc(p.partner_name || p.partner_code)}</option>`).join('');
        sel.value = [...sel.options].some(o => o.value === current) ? current : 'ALL';
      }
      if (voucherMsg) voucherMsg.innerHTML = '';
      render();
    } catch (err) {
      if (voucherMsg) voucherMsg.innerHTML = `<div class="msg err">Unable to load voucher records: ${esc(err?.message || String(err))}</div>`;
    }
  }

  function exportExcel(){
    const list = filteredRows();
    const msg = document.getElementById('voucherMsg');
    if (!list.length) {
      if (msg) msg.innerHTML = '<div class="msg err">No records to export.</div>';
      return;
    }
    if (typeof XLSX === 'undefined') {
      if (msg) msg.innerHTML = '<div class="msg err">Excel exporter failed to load.</div>';
      return;
    }
    const rows = list.map(v => ({
      'Voucher Code': v.voucher_code || '',
      'Status': effectiveStatus(v),
      'Customer': v.customer_name || '',
      'Phone': v.customer_phone || '',
      'Partner': partnerMap.get(v.partner_id) || '',
      'Voucher Type': v.voucher_type || '',
      'Valid Until': v.expiry_date || '',
      'Issued At': v.issued_at || '',
      'Redeemed At': v.redeemed_at || '',
      'Redeem Branch': v.redeemed_branch_id ? (branchMap.get(v.redeemed_branch_id) || '') : ''
    }));
    const ws = XLSX.utils.json_to_sheet(rows);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Voucher Records');
    XLSX.writeFile(wb, `commercial-vouchers-${new Date().toISOString().slice(0,10)}.xlsx`);
  }

  function install(){
    const sel = document.getElementById('voucherPartner');
    const search = document.getElementById('voucherSearch');
    const status = document.getElementById('voucherStatus');
    const dateFrom = document.getElementById('voucherDateFrom');
    const dateTo = document.getElementById('voucherDateTo');
    const exportBtn = document.getElementById('exportVoucherExcel');
    const clearBtn = document.getElementById('clearVoucherFilters');
    const refreshBtn = document.getElementById('voucherRefresh');
    if (!sel || !search || !status || !dateFrom || !dateTo || !exportBtn || !clearBtn || !refreshBtn) return false;

    sel.onchange = render;
    search.oninput = render;
    status.onchange = render;
    dateFrom.onchange = render;
    dateTo.onchange = render;
    exportBtn.onclick = exportExcel;
    refreshBtn.onclick = loadLive;
    clearBtn.onclick = () => {
      search.value=''; status.value='ALL'; sel.value='ALL'; dateFrom.value=''; dateTo.value=''; render();
    };
    loadLive();
    return true;
  }

  let tries = 0;
  const timer = setInterval(() => {
    tries += 1;
    if (install() || tries >= 40) clearInterval(timer);
  }, 250);
})();
