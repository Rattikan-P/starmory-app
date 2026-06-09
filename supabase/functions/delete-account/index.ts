// Edge Function: Delete Account (PDPA Compliant)
// Deletes: storage images, avatars, user data, AND auth user completely

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const BUCKETS = ['vocabulary-images', 'avatars']

serve(async (req) => {
  // Handle CORS preflight request
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Verify request method
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed' }), {
        status: 405,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // ✅ Verify JWT token from Authorization header
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Authorization header required' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Create client with anon key to verify user
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    )

    const { data: { user }, error: authError } = await supabase.auth.getUser(
      authHeader.replace('Bearer ', '')
    )

    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Invalid or expired token' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const userId = user.id

    // Create admin client for deletion
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    console.log(`[DELETE-ACCOUNT] Starting deletion for user: ${userId}`)

    // Step 1: Delete from all storage buckets
    for (const bucket of BUCKETS) {
      try {
        const { data: files, error: listError } = await supabaseAdmin
          .storage
          .from(bucket)
          .list(userId)

        if (!listError && files && files.length > 0) {
          const filePaths = files.map((f: { name: string }) => `${userId}/${f.name}`)
          const { error: deleteError } = await supabaseAdmin
            .storage
            .from(bucket)
            .remove(filePaths)

          if (deleteError) {
            console.error(`Error deleting files from ${bucket}:`, deleteError)
          } else {
            console.log(`✅ Deleted ${filePaths.length} files from ${bucket}`)
          }
        } else {
          console.log(`No files found in ${bucket} for this user`)
        }
      } catch (storageError) {
        console.error(`Error accessing ${bucket}:`, storageError)
        // Continue with other buckets even if one fails
      }
    }

    // Step 2: Delete from users table
    const { error: dbError } = await supabaseAdmin
      .from('users')
      .delete()
      .eq('id', userId)

    if (dbError) {
      console.error('Error deleting from users table:', dbError)
    }

    // Step 3: Delete the auth user
    const { error: deleteAuthError } = await supabaseAdmin.auth.admin.deleteUser(userId)

    if (deleteAuthError) {
      console.error('Error deleting auth user:', deleteAuthError)
      return new Response(JSON.stringify({ error: deleteAuthError.message }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    console.log(`✅ Account completely deleted: ${userId}`)

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Account deleted completely (data + avatars + vocabulary images + auth)'
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )

  } catch (error: any) {
    console.error('Error in delete-account function:', error)
    return new Response(
      JSON.stringify({ error: error.message || 'Unknown error' }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
