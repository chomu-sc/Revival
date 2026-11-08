// 기도와 말씀 · 새 문의가 오면 총 관리자 기기로 푸시 알림을 보내요.
// 문의를 보낸 사용자가 저장 직후 이 함수를 불러요. 함수는 그 문의가 정말 그 사람이 방금 보낸 것인지 확인한 뒤, 한 번만 알림을 보내요.
// 알림에는 아직 안 읽은 문의 수(badge)를 함께 담아 앱 아이콘에 숫자로 보여줘요.
import { createClient } from 'npm:@supabase/supabase-js@2.45.4';
import webpush from 'npm:web-push@3.6.7';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'method' }, 405);
  try {
    const url = Deno.env.get('SUPABASE_URL')!;
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const authHeader = req.headers.get('Authorization') ?? '';

    const userClient = createClient(url, anonKey, { global: { headers: { Authorization: authHeader } }, auth: { persistSession: false } });
    const { data: userData } = await userClient.auth.getUser();
    const user = userData?.user;
    if (!user) return json({ error: 'unauthorized' }, 401);

    const body = await req.json().catch(() => ({}));
    const inquiryId = Number(body?.inquiry_id);
    if (!Number.isFinite(inquiryId)) return json({ error: 'bad request' }, 400);

    const admin = createClient(url, serviceKey, { auth: { persistSession: false } });
    const { data: q } = await admin.from('inquiries').select('id, user_id, group_id, content, created_at').eq('id', inquiryId).maybeSingle();
    if (!q || q.user_id !== user.id) return json({ error: 'not found' }, 404);
    if (Date.now() - new Date(q.created_at).getTime() > 10 * 60 * 1000) return json({ skipped: 'old' });

    // 같은 문의로 두 번 알림이 가지 않게 먼저 표시해 둬요
    const { error: claimErr } = await admin.from('inquiry_notified').insert({ inquiry_id: q.id });
    if (claimErr) return json({ skipped: 'already' });

    const [prof, grp, secrets, admins] = await Promise.all([
      admin.from('profiles').select('nickname').eq('id', q.user_id).maybeSingle(),
      q.group_id ? admin.from('groups').select('name').eq('id', q.group_id).maybeSingle() : Promise.resolve({ data: null }),
      admin.from('app_secrets').select('key, value').in('key', ['vapid_public', 'vapid_private']),
      admin.from('profiles').select('id').eq('is_super_admin', true),
    ]);
    const keys = Object.fromEntries((secrets.data ?? []).map((r: { key: string; value: string }) => [r.key, r.value]));
    if (!keys.vapid_public || !keys.vapid_private) return json({ error: 'push keys missing' }, 500);
    const adminIds = (admins.data ?? []).map((r: { id: string }) => r.id);
    if (!adminIds.length) return json({ sent: 0 });

    const { data: subs } = await admin.from('push_subscriptions').select('endpoint, user_id, p256dh, auth').in('user_id', adminIds);
    if (!subs?.length) return json({ sent: 0 });

    // 관리자마다 아직 안 읽은 문의 수
    const [{ data: reads }, { data: hidden }, { data: recent }] = await Promise.all([
      admin.from('inquiry_reads').select('user_id, seen_at').in('user_id', adminIds),
      admin.from('inquiry_hidden').select('inquiry_id'),
      admin.from('inquiries').select('id, created_at').order('created_at', { ascending: false }).limit(500),
    ]);
    const hiddenIds = new Set((hidden ?? []).map((h: { inquiry_id: number }) => h.inquiry_id));
    const seenAt = new Map((reads ?? []).map((r: { user_id: string; seen_at: string }) => [r.user_id, new Date(r.seen_at).getTime()]));
    const badgeFor = (uid: string) => {
      const t = seenAt.get(uid) ?? 0;
      return (recent ?? []).filter((x: { id: number; created_at: string }) => !hiddenIds.has(x.id) && new Date(x.created_at).getTime() > t).length;
    };

    webpush.setVapidDetails('mailto:joseungchan164@gmail.com', keys.vapid_public, keys.vapid_private);
    const who = prof.data?.nickname || '누군가';
    const where = grp.data?.name ? ` · ${grp.data.name}` : '';
    const text = String(q.content).replace(/\s+/g, ' ').trim();

    let sent = 0;
    await Promise.all(subs.map(async (s: { endpoint: string; user_id: string; p256dh: string; auth: string }) => {
      const payload = JSON.stringify({
        title: '새 문의가 왔어요',
        body: `${who}${where}: ${text.length > 90 ? text.slice(0, 90) + '…' : text}`,
        tag: `inquiry-${q.id}`,
        url: './#inbox',
        badge: badgeFor(s.user_id),
      });
      try {
        await webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, payload, { TTL: 86400, urgency: 'high' });
        sent++;
      } catch (e) {
        const code = (e as { statusCode?: number })?.statusCode;
        if (code === 404 || code === 410) await admin.from('push_subscriptions').delete().eq('endpoint', s.endpoint);
        else console.error('push failed', code, String((e as Error)?.message ?? e));
      }
    }));
    return json({ sent });
  } catch (e) {
    console.error(e);
    return json({ error: String((e as Error)?.message ?? e) }, 500);
  }
});
