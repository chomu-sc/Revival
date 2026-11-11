// 기도와 말씀 · 새 기도제목이 올라오면, 「새 기도제목 알림」을 켠 같은 서버 사람들에게 알려줘요.
// 데이터베이스 트리거가 기도제목 저장 직후 이 함수를 불러요 (x-cron-secret 확인).
import { createClient } from 'npm:@supabase/supabase-js@2.45.4';
import webpush from 'npm:web-push@3.6.7';

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'method' }, 405);
  try {
    const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { auth: { persistSession: false } });
    const { data: secrets } = await admin.from('app_secrets').select('key, value').in('key', ['vapid_public', 'vapid_private', 'cron_secret']);
    const keys = Object.fromEntries((secrets ?? []).map((r: { key: string; value: string }) => [r.key, r.value]));
    if (!keys.cron_secret || req.headers.get('x-cron-secret') !== keys.cron_secret) return json({ error: 'unauthorized' }, 401);
    if (!keys.vapid_public || !keys.vapid_private) return json({ error: 'push keys missing' }, 500);

    const body = await req.json().catch(() => ({}));
    const id = Number(body?.prayer_id);
    if (!Number.isFinite(id)) return json({ error: 'bad request' }, 400);

    const { data: p } = await admin.from('prayers').select('id, user_id, group_id, created_at').eq('id', id).maybeSingle();
    if (!p || !p.group_id) return json({ skipped: 'not found' });
    if (Date.now() - new Date(p.created_at).getTime() > 10 * 60 * 1000) return json({ skipped: 'old' });

    const { data: members } = await admin.from('group_members').select('user_id').eq('group_id', p.group_id).neq('user_id', p.user_id);
    const memberIds = (members ?? []).map((m: { user_id: string }) => m.user_id);
    if (!memberIds.length) return json({ sent: 0 });
    const { data: prefs } = await admin.from('notify_prefs').select('user_id').eq('new_prayer', true).in('user_id', memberIds);
    const ids = (prefs ?? []).map((r: { user_id: string }) => r.user_id);
    if (!ids.length) return json({ sent: 0 });
    const { data: subs } = await admin.from('push_subscriptions').select('endpoint, p256dh, auth').in('user_id', ids);
    if (!subs?.length) return json({ sent: 0 });

    // 잠금 화면에 내용이 보이지 않도록, 알림에는 제목만 담아요
    const payload = JSON.stringify({ title: '새 기도제목이 올라왔어요', body: '', tag: `prayer-${p.id}`, url: './#pray' });

    webpush.setVapidDetails('mailto:joseungchan164@gmail.com', keys.vapid_public, keys.vapid_private);
    let sent = 0;
    await Promise.all(subs.map(async (s: { endpoint: string; p256dh: string; auth: string }) => {
      try {
        await webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, payload, { TTL: 21600, urgency: 'normal' });
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
