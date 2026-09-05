import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders },
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: corsHeaders });
  if (req.method !== "POST") return json({ success: false, error: "Method not allowed" }, 405);

  try {
    const jwt = (req.headers.get("authorization") || "").match(/^Bearer\s+(.+)$/i)?.[1];
    if (!jwt) return json({ success: false, error: "Unauthorized" }, 401);

    const url = Deno.env.get("SUPABASE_URL");
    const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!url || !service) return json({ success: false, error: "Missing Supabase environment variables" }, 500);

    const admin = createClient(url, service, { auth: { persistSession: false } });
    const { data: userData, error: userError } = await admin.auth.getUser(jwt);
    const caller = userData?.user;
    if (userError || !caller) return json({ success: false, error: "Unauthorized" }, 401);

    const { data: adminRow, error: adminError } = await admin.from("partner_users")
      .select("user_id,role,status").eq("user_id", caller.id).eq("role", "admin").eq("status", "active").maybeSingle();
    if (adminError) return json({ success: false, error: "Failed to verify admin", details: adminError.message }, 500);
    if (!adminRow) return json({ success: false, error: "Admin access required" }, 403);

    const body = await req.json();
    const action = typeof body.action === "string" ? body.action.trim().toLowerCase() : "";
    if (!action) return json({ success: false, error: "action is required" }, 400);

    if (action === "create_template") {
      const { data, error } = await admin.rpc("svc_admin_create_voucher_template", {
        p_actor_user_id: caller.id,
        p_template_code: body.template_code,
        p_template_name: body.template_name,
        p_voucher_category: body.voucher_category || "custom",
        p_description: body.description ?? null,
      });
      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: true, template_id: data }, 201);
    }

    if (action === "publish_version") {
      const { data, error } = await admin.rpc("svc_admin_publish_voucher_version", {
        p_actor_user_id: caller.id,
        p_template_id: body.template_id,
        p_version_name: body.version_name ?? null,
        p_face_value: body.face_value ?? null,
        p_discount_percent: body.discount_percent ?? null,
        p_validity_type: body.validity_type || "days_after_issue",
        p_valid_days: body.valid_days ?? 90,
        p_valid_from: body.valid_from ?? null,
        p_valid_until: body.valid_until ?? null,
        p_min_spend: body.min_spend ?? null,
        p_max_discount: body.max_discount ?? null,
        p_usage_limit: body.usage_limit ?? 1,
        p_transferable: body.transferable ?? true,
        p_terms_text: body.terms_text ?? null,
        p_supply_limit: body.supply_limit ?? null,
        p_all_branches: body.all_branches ?? false,
      });
      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: true, version_id: data }, 201);
    }

    if (action === "allocate") {
      const quantity = Number(body.quantity);
      if (!Number.isInteger(quantity) || quantity <= 0) return json({ success: false, error: "quantity must be a positive integer" }, 400);
      const allBranches = body.all_branches !== false;
      const branchCodes = Array.isArray(body.branch_codes) ? body.branch_codes.map((x: unknown) => String(x)) : [];
      const { data, error } = await admin.rpc("svc_admin_allocate_voucher_to_partner_scoped", {
        p_actor_user_id: caller.id,
        p_partner_id: body.partner_id,
        p_version_id: body.version_id,
        p_quantity: quantity,
        p_valid_from: body.valid_from ?? null,
        p_valid_until: body.valid_until ?? null,
        p_all_branches: allBranches,
        p_branch_codes: allBranches ? [] : branchCodes,
      });
      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: true, allocation_id: data, all_branches: allBranches, branch_codes: allBranches ? [] : branchCodes }, 201);
    }

    if (action === "allocate_all") {
      const quantity = Number(body.quantity);
      if (!Number.isInteger(quantity) || quantity <= 0) return json({ success: false, error: "quantity must be a positive integer" }, 400);

      const { data: partnerRows, error: partnerError } = await admin.from("partners")
        .select("id,partner_code,partner_name,status").eq("status", "active");
      if (partnerError) return json({ success: false, error: "Failed to load active Partners", details: partnerError.message }, 500);

      const targets = (partnerRows || []).filter((p) => {
        const code = String(p.partner_code || "").trim().toUpperCase();
        return code !== "ADMIN" && code !== "LEGACY";
      });

      let succeeded = 0;
      const failed: Array<{ partner_id: string; partner_code: string; error: string }> = [];
      for (const p of targets) {
        const { error } = await admin.rpc("svc_admin_allocate_voucher_to_partner_scoped", {
          p_actor_user_id: caller.id,
          p_partner_id: p.id,
          p_version_id: body.version_id,
          p_quantity: quantity,
          p_valid_from: body.valid_from ?? null,
          p_valid_until: body.valid_until ?? null,
          p_all_branches: true,
          p_branch_codes: [],
        });
        if (error) failed.push({ partner_id: p.id, partner_code: String(p.partner_code || ""), error: error.message });
        else succeeded += 1;
      }

      if (failed.length > 0) return json({ success: false, error: "Bulk allocation partially failed", result: { partners_targeted: targets.length, partners_allocated: succeeded, quantity_each: quantity, failed } }, 409);
      return json({ success: true, result: { partners_targeted: targets.length, partners_allocated: succeeded, quantity_each: quantity, excluded_partner_codes: ["ADMIN", "LEGACY"] } }, 201);
    }

    if (action === "revoke_unissued") {
      const quantity = Number(body.quantity);
      if (!Number.isInteger(quantity) || quantity <= 0) return json({ success: false, error: "quantity must be a positive integer" }, 400);
      const { data, error } = await admin.rpc("svc_admin_revoke_unissued_allocation", {
        p_actor_user_id: caller.id,
        p_allocation_id: body.allocation_id,
        p_quantity: quantity,
        p_reason: body.reason ?? null,
      });
      if (error) return json({ success: false, error: error.message }, 409);
      return json({ success: true, result: data });
    }

    if (action === "retire_version") {
      const { error } = await admin.rpc("svc_admin_retire_voucher_version", {
        p_actor_user_id: caller.id,
        p_version_id: body.version_id,
        p_reason: body.reason ?? null,
      });
      if (error) return json({ success: false, error: error.message }, 400);
      return json({ success: true });
    }

    return json({ success: false, error: "Unsupported action" }, 400);
  } catch (e) {
    return json({ success: false, error: "Unexpected error", details: e instanceof Error ? e.message : String(e) }, 500);
  }
});