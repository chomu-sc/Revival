// 기도와 말씀 · 정해 둔 시간에 기도/말씀 알림을 보내요.
// 데이터베이스의 예약 작업(pg_cron)이 1분마다, 보낼 알림이 있을 때만 이 함수를 불러요.
import { createClient } from 'npm:@supabase/supabase-js@2.45.4';
import webpush from 'npm:web-push@3.6.7';

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

type Due = { user_id: string; kind: 'pray' | 'word'; today_count: number; daily_goal: number | null; active_prayers: number };

function message(d: Due) {
  if (d.kind === 'pray') {
    return {
      title: '기도할 시간이에요',
      body: d.active_prayers > 0
        ? `함께 기도할 제목이 ${d.active_prayers}개 있어요. 잠시 마음을 모아 기도해요.`
        : '잠시 멈추고 마음을 모아 기도하는 시간을 가져요.',
      tag: 'remind-pray', url: './#pray',
    };
  }
  const goal = Number(d.daily_goal) || 0, n = d.today_count || 0;
  const fmt = (x: number) => Number.isInteger(x) ? String(x) : x.toFixed(1);
  return {
    title: '말씀 읽을 시간이에요',
    body: goal
      ? (n >= goal ? `오늘 목표 ${fmt(goal)}장을 다 읽었어요. 한 장 더 읽어 볼까요?` : `오늘 목표 ${fmt(goal)}장 중 ${n}장 읽었어요. 함께 말씀을 펴 봐요.`)
      : (n > 0 ? `오늘 ${n}장 읽었어요. 조금 더 읽어 볼까요?` : '오늘의 말씀을 펴 볼까요?'),
    tag: 'remind-word', url: './#bible',
  };
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'method' }, 405);
  try {
    const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { auth: { persistSession: false } });
    const { data: secrets } = await admin.from('app_secrets').select('key, value').in('key', ['vapid_public', 'vapid_private', 'cron_secret']);
    const keys = Object.fromEntries((secrets ?? []).map((r: { key: string; value: string }) => [r.key, r.value]));
    if (!keys.cron_secret || req.headers.get('x-cron-secret') !== keys.cron_secret) return json({ error: 'unauthorized' }, 401);
    if (!keys.vapid_public || !keys.vapid_private) return json({ error: 'push keys missing' }, 500);

    const { data: due, error } = await admin.rpc('claim_due_reminders');
    if (error) throw error;
    if (!due?.length) return json({ sent: 0 });

    const ids = [...new Set((due as Due[]).map(d => d.user_id))];
    const { data: subs } = await admin.from('push_subscriptions').select('endpoint, user_id, p256dh, auth').in('user_id', ids);
    webpush.setVapidDetails('mailto:joseungchan164@gmail.com', keys.vapid_public, keys.vapid_private);

    let sent = 0;
    await Promise.all((due as Due[]).flatMap(d => {
      const payload = JSON.stringify(message(d));
      return (subs ?? []).filter((s: { user_id: string }) => s.user_id === d.user_id).map(async (s: { endpoint: string; p256dh: string; auth: string }) => {
        try {
          await webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, payload, { TTL: 3600, urgency: 'normal' });
          sent++;
        } catch (e) {
          const code = (e as { statusCode?: number })?.statusCode;
          if (code === 404 || code === 410) await admin.from('push_subscriptions').delete().eq('endpoint', s.endpoint);
          else console.error('push failed', code, String((e as Error)?.message ?? e));
        }
      });
    }));
    return json({ due: due.length, sent });
  } catch (e) {
    console.error(e);
    return json({ error: String((e as Error)?.message ?? e) }, 500);
  }
});
