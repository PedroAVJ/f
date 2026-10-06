import { open, realpath } from 'node:fs/promises';
import { constants } from 'node:fs';
import { resolve, relative, isAbsolute } from 'node:path';

export type Content = {type:'text'; text:string} | {type:'image'; data:string; mimeType:string};
import { checkSchema, type Schema } from './schema.ts';
export { checkSchema, validate, type Schema } from './schema.ts';
export type Action = {name:string; description:string; inputSchema:Schema};
export type Query = {label:string; uri:string};
export type Store = {queries:Record<string,Query>; mutations:Record<string,Action>};
export type Page = {content:Content[]; actions:Action[]; store:Store};
type Value = {$:string; [key:string]:any};
const tag = (v: Value) => v.$.split('.').at(-1);
const text = (value: string): Content => ({type:'text', text:value});
const escape = (value: string) => value.replace(/[\\`*_{}\[\]<>#!|]/g, '\\$&');
export function uri(value: unknown): string {
  if (typeof value !== 'string' || value.length > 8192 || /[\s<>]/.test(value)) throw Error('Expected an absolute page URI.');
  const parsed = new URL(value);
  if (!['hypertui:','https:','http:'].includes(parsed.protocol)) throw Error('Unsupported page URI scheme.');
  return parsed.href;
}
export async function localImage(root: string, asset: string): Promise<Content> {
  const directory = await realpath(root), file = await realpath(resolve(directory,asset));
  const subpath = relative(directory,file);
  if (subpath.startsWith('..') || isAbsolute(subpath)) throw Error('Image is outside the application asset root.');
  const handle = await open(file, constants.O_RDONLY | constants.O_NOFOLLOW | constants.O_NONBLOCK);
  try {
    const stat = await handle.stat();
    if (!stat.isFile() || stat.size > 8*1024*1024) throw Error('Image must be a file of at most 8 MiB.');
    const bytes = await handle.readFile();
    const mimeType = bytes.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10])) ? 'image/png'
      : bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255 ? 'image/jpeg'
      : bytes.subarray(0,4).toString() === 'RIFF' && bytes.subarray(8,12).toString() === 'WEBP' ? 'image/webp' : '';
    if (!mimeType) throw Error('Expected PNG, JPEG, or WebP image bytes.');
    return {type:'image', mimeType, data:bytes.toString('base64')};
  } finally { await handle.close(); }
}

export async function render(tree: Value, loadImage: (asset:string) => Promise<Content>): Promise<Page> {
  // Older F applications still return the first-child/next-sibling tree.
  // Lower it through the same Bend adapter used by new applications.
  if (['Last','Leaf','Node'].includes(tag(tree))) {
    await import('../../../main.ts');
    const adapter = (await import('./tree.bend')).default;
    tree = adapter.lower(tree);
  }
  const store: Store = {queries:Object.create(null), mutations:Object.create(null)};
  const page: Page = {content:[], actions:[], store};
  let count = 0, bytes = 0;
  const add = (block: Content) => {
    bytes += block.type === 'text' ? Buffer.byteLength(block.text) : block.data.length;
    if (bytes > 24*1024*1024) throw Error('Page exceeds the 24 MiB content budget.');
    page.content.push(block);
  };
  async function walk(node: Value, position = 'root', depth = 0): Promise<void> {
    if (depth > 256) throw Error('UI nesting limit exceeded.');
    if (++count > 10000) throw Error('UI node limit exceeded.');
    const kind = tag(node);
    if (kind !== 'Fork' && kind !== 'Tip') throw Error('Unknown F UI tree constructor.');
    const value = kind === 'Fork' ? node.branch : node.value;
    const name: string = value.name;
    if (name.startsWith('hypertui:')) {
      const meta = JSON.parse(name.slice(9));
      if (meta.kind === 'query') {
        const query: Query = {label:meta.label, uri:uri(meta.uri)};
        if (typeof query.label !== 'string') throw Error('Invalid query label.');
        store.queries[position] = query;
        add(text(`[${escape(query.label)}](<${query.uri}>)`));
      } else if (meta.kind === 'code') {
        if (typeof meta.source !== 'string' || !/^[a-zA-Z0-9_+-]*$/.test(meta.language)) throw Error('Invalid code block.');
        const fence = '`'.repeat(Math.max(3,...Array.from(meta.source.matchAll(/`+/g),match => match[0].length+1)));
        add(text(`${fence}${meta.language}\n${meta.source}\n${fence}`));
      } else if (meta.kind === 'action') {
        if (!/^[a-zA-Z][a-zA-Z0-9_]{0,63}$/.test(meta.name) || typeof meta.label !== 'string' || typeof meta.enabled !== 'boolean') throw Error('Invalid action declaration.');
        checkSchema(meta.inputSchema);
        if (meta.inputSchema.type !== 'object') throw Error('Action arguments must be an object.');
        if (Object.hasOwn(store.mutations,meta.name)) throw Error('Duplicate page action.');
        if (meta.enabled) store.mutations[meta.name] = {name:meta.name, description:meta.label, inputSchema:meta.inputSchema};
        add(text(escape(meta.label)+(meta.enabled ? ` (action: ${meta.name})` : ' (disabled)')));
      } else throw Error('Unknown HyperTUI semantic node.');
    } else if (kind === 'Fork') {
      if (name.startsWith('heading · ')) add(text('# '+escape(name.slice(10))));
      else {
        let children=node.children,index=0;
        while (tag(children)==='Con') {
          await walk(children.head,position+'/'+index++,depth+1);
          children=children.tail;
        }
        if (tag(children)!=='Nil') throw Error('Expected UI tree children.');
      }
    } else {
      const shape = value.shape;
      if (tag(shape.geometry) === 'Text') add(text(escape(shape.geometry.string)));
      else if (tag(shape.fill) === 'Image') {
        if (tag(shape.fill.bitmap) !== 'Photo') throw Error('Atlas frames require an explicitly rendered image asset.');
        if (name.startsWith('img · ')) add(text(escape(name.slice(6))));
        add(await loadImage(shape.fill.bitmap.asset));
      }
    }
  }
  await walk(tree);
  page.actions = Object.values(store.mutations);
  return page;
}
