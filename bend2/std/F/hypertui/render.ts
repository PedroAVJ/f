import { open, realpath } from 'node:fs/promises';
import { constants } from 'node:fs';
import { resolve, relative, isAbsolute } from 'node:path';

export type Content = {type:'text'; text:string} | {type:'image'; data:string; mimeType:string};
export type Schema = {type:'object'|'string'|'integer'|'number'|'boolean'|'array'; properties?:Record<string,Schema>; required?:string[]; additionalProperties?:false; items?:Schema; enum?:unknown[]; minimum?:number; maximum?:number; description?:string};
export type Action = {name:string; description:string; inputSchema:Schema};
export type Page = {content:Content[]; actions:Action[]};
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
export function checkSchema(schema: Schema, depth = 0): void {
  if (!schema || typeof schema !== 'object' || depth > 12) throw Error('Invalid action schema.');
  const allowed = ['type','properties','required','additionalProperties','items','enum','minimum','maximum','description'];
  if (Object.keys(schema).some(key => !allowed.includes(key))) throw Error('Unsupported action schema keyword.');
  if (!['object','string','integer','number','boolean','array'].includes(schema.type)) throw Error('Unsupported action schema type.');
  if (schema.type === 'object') {
    if (schema.additionalProperties !== false || !schema.properties || typeof schema.properties !== 'object') throw Error('Action objects require explicit properties and additionalProperties:false.');
    if (schema.required && (!Array.isArray(schema.required) || schema.required.some(key => !Object.hasOwn(schema.properties!,key)))) throw Error('Invalid required action field.');
    for (const child of Object.values(schema.properties)) checkSchema(child, depth+1);
  }
  if (schema.type === 'array') checkSchema(schema.items!, depth+1);
  if (schema.enum && (!Array.isArray(schema.enum) || !schema.enum.length)) throw Error('Invalid enum.');
  for (const bound of [schema.minimum,schema.maximum]) if (bound !== undefined && !Number.isFinite(bound)) throw Error('Invalid number bound.');
}
export function validate(schema: Schema, value: unknown, location = 'arguments'): void {
  if (schema.type === 'object') {
    if (!value || typeof value !== 'object' || Array.isArray(value)) throw Error(location+' must be an object.');
    const object = value as Record<string,unknown>;
    for (const name of schema.required ?? []) if (!Object.hasOwn(object,name)) throw Error(location+'.'+name+' is required.');
    for (const [name,item] of Object.entries(object)) {
      if (!Object.hasOwn(schema.properties!,name)) throw Error('Unknown field: '+location+'.'+name);
      validate(schema.properties![name],item,location+'.'+name);
    }
  } else if (schema.type === 'array') {
    if (!Array.isArray(value)) throw Error(location+' must be an array.');
    value.forEach((item,index) => validate(schema.items!,item,`${location}[${index}]`));
  } else if (schema.type === 'integer' || schema.type === 'number') {
    if (typeof value !== 'number' || !Number.isFinite(value) || (schema.type === 'integer' && !Number.isInteger(value))) throw Error(location+' must be a '+schema.type+'.');
    if (schema.minimum !== undefined && value < schema.minimum || schema.maximum !== undefined && value > schema.maximum) throw Error(location+' is outside its range.');
  } else if (typeof value !== schema.type) throw Error(location+' must be a '+schema.type+'.');
  if (schema.enum && !schema.enum.some(item => JSON.stringify(item) === JSON.stringify(value))) throw Error(location+' is not an allowed value.');
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
  const page: Page = {content:[], actions:[]};
  let count = 0, bytes = 0;
  const add = (block: Content) => {
    bytes += block.type === 'text' ? Buffer.byteLength(block.text) : block.data.length;
    if (bytes > 24*1024*1024) throw Error('Page exceeds the 24 MiB content budget.');
    page.content.push(block);
  };
  async function walk(node: Value, depth = 0): Promise<void> {
    if (depth > 256) throw Error('UI nesting limit exceeded.');
    for (let current = node; tag(current) !== 'Last'; current = current.next) {
      if (++count > 10000) throw Error('UI node limit exceeded.');
      const name: string = current.name;
      if (name.startsWith('hypertui:')) {
        const meta = JSON.parse(name.slice(9));
        if (meta.kind === 'query') add(text(`[${escape(meta.label)}](<${uri(meta.uri)}>)`));
        else if (meta.kind === 'code') {
          if (typeof meta.source !== 'string' || !/^[a-zA-Z0-9_+-]*$/.test(meta.language)) throw Error('Invalid code block.');
          const fence = '`'.repeat(Math.max(3,...Array.from(meta.source.matchAll(/`+/g),match => match[0].length+1)));
          add(text(`${fence}${meta.language}\n${meta.source}\n${fence}`));
        } else if (meta.kind === 'action') {
          if (!/^[a-zA-Z][a-zA-Z0-9_]{0,63}$/.test(meta.name) || typeof meta.label !== 'string' || typeof meta.enabled !== 'boolean') throw Error('Invalid action declaration.');
          checkSchema(meta.inputSchema);
          if (meta.inputSchema.type !== 'object') throw Error('Action arguments must be an object.');
          if (page.actions.some(action => action.name === meta.name)) throw Error('Duplicate page action.');
          if (meta.enabled) page.actions.push({name:meta.name, description:meta.label, inputSchema:meta.inputSchema});
          add(text(escape(meta.label)+(meta.enabled ? ` (action: ${meta.name})` : ' (disabled)')));
        } else throw Error('Unknown HyperTUI semantic node.');
      } else if (tag(current) === 'Node') {
        if (name.startsWith('heading · ')) add(text('# '+escape(name.slice(10))));
        else await walk(current.first,depth+1);
      } else if (tag(current) === 'Leaf') {
        const shape = current.shape;
        if (tag(shape.geometry) === 'Text') add(text(escape(shape.geometry.string)));
        else if (tag(shape.fill) === 'Image') {
          if (tag(shape.fill.bitmap) !== 'Photo') throw Error('Atlas frames require an explicitly rendered image asset.');
          if (name.startsWith('img · ')) add(text(escape(name.slice(6))));
          add(await loadImage(shape.fill.bitmap.asset));
        }
      } else throw Error('Unknown F UI tree constructor.');
    }
  }
  await walk(tree);
  return page;
}
