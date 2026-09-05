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
    const authHeader = req.headers.get("authorization") || "";
    const jwt = authHeader.match(/^Bearer\s+(.+)$/i)?.[1];
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
    const partnerId = typeof body.partner_id === "string" ? body.partner_id.trim() : "";
    const staffLimit = Number(body.staff_limit);
    if (!partnerId) return json({ success: false, error: "partner_id is required" }, 400);
    if (!Number.isInteger(staffLimit) || staffLimit < 0 || staffLimit > 1000) return json({ success: false, error: "staff_limit must be an integer from 0 to 1000" }, 400);

    const { data: partner, error: partnerError } = await admin.from("partners")
      .select("id,partner_code,partner_name,staff_limit").eq("id", partnerId).maybeSingle();
    if (partnerError) return json({ success: false, error: "Failed to find Partner", details: partnerError.message }, 500);
    if (!partner) return json({ success: false, error: "Partner not found" }, 404);

    const previousLimit = Number(partner.staff_limit || 0);
    const { data: updated, error: updateError } = await admin.from("partners").update({ staff_limit: staffLimit })
      .eq("id", partnerId).select("id,partner_code,partner_name,staff_limit,staff_access_enabled").single();
    if (updateError) return json({ success: false, error: "Unable to update Staff limit", details: updateError.message }, 500);

    const { count } = await admin.from("partner_users").select("id", { count: "exact", head: true })
      .eq("partner_id", partnerId).eq("role", "partner_staff").neq("status", "inactive").is("removed_at", null);

    await admin.from("admin_audit_log").insert({
      actor_user_id: caller.id,
      action_type: "partner_staff_limit_updated",
      entity_type: "partners",
      entity_id: partnerId,
      partner_id: partnerId,
      before_data: { staff_limit: previousLimit },
      after_data: { staff_limit: staffLimit },
      metadata: { source: "edge_function", function: "admin-set-partner-staff-limit", partner_code: partner.partner_code, partner_name: partner.partner_name },
    });

    return json({
      success: true,
      partner: updated,
      current_staff: count ?? 0,
      note: (count ?? 0) > staffLimit ? "Current Staff count is above the new limit. Existing Staff were kept; no new Staff can be added until the count is within the limit." : null,
    });
  } catch (e) {
    return json({ success: false, error: "Unexpected error", details: e instanceof Error ? e.message : String(e) }, 500);
  }
});