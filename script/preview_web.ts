import { resolve, join } from 'node:path';

const directory = process.env.DOT_PREVIEW_DIRECTORY ? resolve(process.env.DOT_PREVIEW_DIRECTORY) : resolve(import.meta.dir, '../dist/dot.web');
const thread = { id: 'web-preview', title: 'Near', status: 'idle', historyIsLatest: true, historyHasMore: false, historyBefore: '', messages: [
  { id: '1', role: 'user', text: 'Show me the web conversation.' },
  { id: '2', role: 'assistant', text: '# Dot on the web\n\nThe conversation uses the same components as the iPhone app.\n\n- Send a message\n- Search the conversation\n- Attach a photo or record audio\n\n**Formatting**, `inline code`, and [links](https://example.com) stay readable.\n\n' + Array.from({ length: 32 }, (_, i) => `Paragraph ${i + 1}: This synthetic conversation checks scrolling while the header and message composer remain available.`).join('\n\n') },
] };
const acceptedRequestIds: string[] = [];
const snapshot = () => ({ threads: [thread], selectedThreadId: thread.id, acceptedRequestIds, provider: 'codex' });
const server = Bun.serve({ hostname: '127.0.0.1', port: Number(process.env.DOT_PREVIEW_PORT ?? 19454), async fetch(request) {
  const url = new URL(request.url);
  if (url.pathname === '/api/session') return Response.json(snapshot());
  if (url.pathname === '/api/search') {
    const query = request.method === 'POST' ? (await request.json() as { query: string }).query : url.searchParams.get('q') ?? '';
    return Response.json({ ...snapshot(), threads: [{ ...thread, messages: thread.messages.filter(message => message.text.toLowerCase().includes(query.toLowerCase())) }] });
  }
  if (url.pathname === '/api/turn' && request.method === 'POST') {
    const body = await request.json() as { requestId: string; text: string };
    if (!acceptedRequestIds.includes(body.requestId)) {
      acceptedRequestIds.push(body.requestId);
      thread.messages.push({ id: crypto.randomUUID(), role: 'user', text: body.text }, { id: crypto.randomUUID(), role: 'assistant', text: 'Preview reply: ' + body.text });
    }
    return Response.json(snapshot());
  }
  if (url.pathname.startsWith('/api/')) return Response.json({ error: 'This local preview does not send media to a provider.' }, { status: 400 });
  const name = url.pathname === '/' ? 'index.html' : url.pathname.slice(1);
  if (!/^[a-zA-Z0-9._-]+$/.test(name)) return new Response('Not found', { status: 404 });
  const file = Bun.file(join(directory, name));
  return await file.exists() ? new Response(file) : new Response('Not found', { status: 404 });
} });
console.log(`Synthetic Dot preview: http://127.0.0.1:${server.port}`);
