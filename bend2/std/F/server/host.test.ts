import { afterEach, expect, test } from 'bun:test';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { run } from './host.ts';

const cleanups: (() => void)[] = [];
afterEach(() => { for (const close of cleanups.splice(0).reverse()) close(); });

async function fixture(effects: object[], scenario = '') {
  const directory = mkdtempSync(join(tmpdir(), 'bend-host-test-'));
  cleanups.push(() => rmSync(directory, {recursive:true, force:true}));
  const module = join(directory, 'app.mjs');
  writeFileSync(module, `import {encode,decode} from ${JSON.stringify(join(import.meta.dir, 'host.ts'))};
    const list = xs => xs.reduceRight((tail,head) => ({$: 'Con',head:encode(head),tail}), {$:'Nil'});
    const step = (state,effects=[]) => ({state:encode(state),effects:list(effects)});
    export default {
      initial(input) {const config=decode(input); return step({events:[],scenario:config.scenario},config.effects);},
      transition(input,message) {
        const state=decode(input),event=decode(message); state.events.push(event);
        if (event.type==='cancel') return step(state,[{type:'http.cancel',id:'request'}]);
        if (state.scenario && event.operation==='http.fetch' && event.ok && !state.reused) {
          state.reused=true; return step(state,[{type:'http.fetch',id:'request',url:state.scenario}]);
        }
        return step(state);
      }
    };`);
  const host = await run(module, {effects, scenario} as Parameters<typeof run>[1]);
  cleanups.push(host.close);
  const events = () => (host.state() as {events: {type:string; id?:string; operation?:string; ok?:boolean; value?:unknown; error?:string}[]}).events;
  return {host, events, directory};
}

async function until(check: () => boolean) {
  const deadline = Date.now() + 3000;
  while (!check()) {
    if (Date.now() >= deadline) throw Error('Timed out waiting for host event.');
    await Bun.sleep(5);
  }
}

test('a missing executable never acknowledges a successful spawn', async () => {
  const {events} = await fixture([{type:'process.spawn', id:'missing', command:'/missing-bend-host-test-executable'}]);
  await until(() => events().some(event => event.operation === 'process.spawn' && event.ok === false));
  await Bun.sleep(10);
  expect(events().filter(event => event.operation === 'process.spawn' && event.ok)).toEqual([]);
});

test('exclusive file creation preserves the original bytes', async () => {
  const directory = mkdtempSync(join(tmpdir(), 'bend-create-test-'));
  cleanups.push(() => rmSync(directory, {recursive:true, force:true}));
  const file = join(directory, 'receipt.json');
  const {events} = await fixture([{type:'file.create',id:'first',path:file,data:'one'}, {type:'file.create',id:'retry',path:file,data:'two'}]);
  expect(events().find(event => event.id === 'first')?.value).toEqual({created:true});
  expect(events().find(event => event.id === 'retry')?.value).toEqual({created:false});
  expect(readFileSync(file, 'utf8')).toBe('one');
});

test('completed fetch cleanup cannot erase a reused request cancellation handle', async () => {
  const server = Bun.serve({hostname:'127.0.0.1', port:0, fetch:request => new URL(request.url).pathname === '/fast' ? new Response('first') : new Promise<Response>(() => {})});
  cleanups.push(() => server.stop(true));
  const origin = `http://127.0.0.1:${server.port}`;
  const {host, events} = await fixture([{type:'http.fetch',id:'request',url:origin+'/fast'}], origin+'/slow');
  await until(() => events().some(event => event.operation === 'http.fetch' && event.ok));
  await Bun.sleep(10);
  host.emit({type:'cancel'});
  await until(() => events().some(event => event.operation === 'http.fetch' && event.ok === false));
  expect(events().filter(event => event.operation === 'http.fetch' && event.ok)).toHaveLength(1);
});

test('duplicate active fetch IDs fail without losing the original cancellation handle', async () => {
  const server = Bun.serve({hostname:'127.0.0.1',port:0,fetch:() => new Promise<Response>(() => {})});
  cleanups.push(() => server.stop(true));
  const effect = {type:'http.fetch',id:'request',url:`http://127.0.0.1:${server.port}/slow`};
  const {host, events} = await fixture([effect, effect]);
  expect(events().some(event => event.error === 'HTTP request handle is already in use.')).toBe(true);
  host.emit({type:'cancel'});
  await until(() => events().filter(event => event.operation === 'http.fetch' && event.ok === false).length === 2);
  expect(events().some(event => event.operation === 'http.fetch' && event.ok)).toBe(false);
});
