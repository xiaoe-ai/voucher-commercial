import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...corsHeaders,
    },
  });
}

function errorResponse(message: string, status = 400, details?: unknown) {
  return jsonResponse(
    {
      success: false,
      error: message,
      ...(details !== undefined ? { details } : {}),
    },
    status,
  );
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405);
  }

  try {
    const authHeader = req.headers.get("authorization") || "";
    const match = authHeader.match(/^Bearer\s+(.+)$/i);
    const jwt = match?.[1];

    if (!jwt) {
      return errorResponse("Missing Authorization header", 401);
    }

    const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
    const SUPABASE_SERVICE_ROLE_KEY =
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      return errorResponse("Missing Supabase environment variables", 500);
    }

    const adminClient = createClient(
      SUPABASE_URL,
      SUPABASE_SERVICE_ROLE_KEY,
      { auth: { persistSession: false } },
    );

    const {
      data: { user },
      error: userError,
    } = await adminClient.auth.getUser(jwt);

    if (userError || !user) {
      return errorResponse("Unauthorized", 401);
    }

    const { data: adminRow, error: adminError } = await adminClient
      .from("partner_users")
      .select("user_id, role, status")
      .eq("user_id", user.id)
      .eq("role", "admin")
      .eq("status", "active")
      .maybeSingle();

    if (adminError) {
      return errorResponse(
        "Failed to verify admin",
        500,
        adminError.message,
      );
    }

    if (!adminRow) {
      return errorResponse("Forbidden: admin access required", 403);
    }

    const body = await req.json();
    const partnerId =
      typeof body.partner_id === "string" ? body.partner_id.trim() : "";
    const newPassword =
      typeof body.new_password === "string" ? body.new_password : "";

    if (!partnerId) {
      return errorResponse("Missing partner_id", 400);
    }

    if (newPassword.length < 6) {
      return errorResponse(
        "Password must be at least 6 characters",
        400,
      );
    }

    const { data: partner, error: partnerError } = await adminClient
      .from("partners")
      .select("id, partner_code, partner_name")
      .eq("id", partnerId)
      .maybeSingle();

    if (partnerError) {
      return errorResponse(
        "Failed to find Partner",
        500,
        partnerError.message,
      );
    }

    if (!partner) {
      return errorResponse("Partner not found", 404);
    }

    const { data: partnerUser, error: partnerUserError } = await adminClient
      .from("partner_users")
      .select("user_id, partner_id, role, status")
      .eq("partner_id", partnerId)
      .eq("role", "partner_admin")
      .maybeSingle();

    if (partnerUserError) {
      return errorResponse(
        "Failed to find Partner login",
        500,
        partnerUserError.message,
      );
    }

    if (!partnerUser?.user_id) {
      return errorResponse(
        "No partner_admin login is linked to this Partner",
        404,
      );
    }

    const { data: updatedUser, error: updateError } =
      await adminClient.auth.admin.updateUserById(
        partnerUser.user_id,
        { password: newPassword },
      );

    if (updateError || !updatedUser.user) {
      return errorResponse(
        "Failed to reset Partner password",
        500,
        updateError?.message,
      );
    }

    const { error: auditError } = await adminClient
      .from("admin_audit_log")
      .insert({
        actor_user_id: user.id,
        action_type: "partner_password_reset",
        entity_type: "auth_user",
        entity_id: partnerUser.user_id,
        partner_id: partnerId,
        before_data: null,
        after_data: null,
        metadata: {
          source: "edge_function",
          function: "reset-partner-password",
          partner_code: partner.partner_code,
          partner_name: partner.partner_name,
          target_role: "partner_admin",
          secret_material_logged: false,
        },
      });

    if (auditError) {
      return errorResponse(
        "Password was reset, but audit logging failed. Contact system administrator immediately.",
        500,
        auditError.message,
      );
    }

    return jsonResponse({
      success: true,
      partner_id: partnerId,
      user_id: partnerUser.user_id,
      audit_logged: true,
      message: "Partner password reset successfully.",
    });
  } catch (e) {
    return errorResponse(
      "Unexpected error",
      500,
      e instanceof Error ? e.message : String(e),
    );
  }
});