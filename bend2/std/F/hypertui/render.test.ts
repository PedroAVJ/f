import { expect, test } from 'bun:test';
import { resolve } from 'node:path';
import { render, localImage, checkSchema, validate } from './render.ts';
import { Session } from './host.ts';
import '../../../main.ts';
const app = (await import('../../../../tests/hypertui/app.bend')).default;
const assets = resolve(import.meta.dir,'../../../../tests/hypertui');

test('same F tree renders interleaved text, real image bytes, links and typed actions',async () => {
  const page = await render(app.hypertui_page(app.s(),'hypertui://demo/'), asset => localImage(assets,asset));
  expect(app.human_html(app.s())).toContain('src="challenge.png"');
  const index = page.content.findIndex(item => item.type === 'image');
  expect(index).toBeGreaterThan(0);
  expect(page.content.slice(0,index).some(item => item.type === 'text' && item.text === 'Before image')).toBe(true);
  expect(page.content[index+1]).toEqual({type:'text',text:'After image'});
  const image = page.content[index];
  expect(image.type === 'image' && Buffer.from(image.data,'base64').subarray(1,4).toString()).toBe('PNG');
  expect(page.content.some(item => item.type === 'text' && item.text === '[Code](<hypertui://demo/code>)')).toBe(true);
  expect(page.actions[0].inputSchema.required).toEqual(['amount']);
});
test('mutation validates page scope and types, returns redirect and invalidates stale actions', async () => {
  const session = new Session(app,assets);
  await expect(session.act('hypertui://demo/','increment',{amount:1})).rejects.toThrow('Open');
  await session.open('hypertui://demo/');
  await expect(session.act('hypertui://demo/','increment',{amount:'1'})).rejects.toThrow('integer');
  await expect(session.act('hypertui://demo/code','increment',{amount:1})).rejects.toThrow('Open');
  const result = await session.act('hypertui://demo/','increment',{amount:1});
  expect(result.content[0].text).toBe('[Continue](<hypertui://demo/>)');
  await expect(session.act('hypertui://demo/','increment',{amount:1})).rejects.toThrow('Open');
  const page = await session.open('hypertui://demo/');
  expect(page.content.some(item => item.type === 'text' && item.text === '1')).toBe(true);
});
test('code page has a fence and no previous page actions',async () => {
  const session = new Session(app,assets);
  await session.open('hypertui://demo/');
  const page = await session.open('hypertui://demo/code');
  expect(page.content[0]).toEqual({type:'text',text:'```bend\ndef answer() -> U32: 42\n```'});
  expect(page.content.at(-1)?.type === 'text' && page.content.at(-1)?.text).toContain('"actions": []');
  await expect(session.act('hypertui://demo/code','increment',{amount:1})).rejects.toThrow('not enabled');
});
test('image resolver rejects paths outside the asset root and unsupported schema keywords fail closed',async () => {
  await expect(localImage(assets,'../../README.md')).rejects.toThrow('outside');
  expect(() => checkSchema({type:'string',unsupportedConstraint:true} as any)).toThrow('Unsupported');
  expect(() => validate({type:'object',properties:{},additionalProperties:false},{extra:1})).toThrow('Unknown');
});
