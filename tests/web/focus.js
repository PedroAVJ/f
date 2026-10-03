// Run in a real browser: verifyFocus(startBend). Worker/HTTP are controlled;
// assertions exercise the actual private shell without changing Bend's program.
export async function verifyFocus(startBend) {
  const check = (ok, name) => { if (!ok) throw Error(name); };
  const wait = async test => { for (let i=0;i<400;i++) { if (test()) return; await new Promise(r=>setTimeout(r,5)); } throw Error('test timed out'); };
  const previousWorker=globalThis.Worker, previousFetch=globalThis.fetch, cases=[];
  let worker, serial=0, app;
  class MockWorker {
    constructor() { worker=this;this.replies=new Map(); }
    postMessage(m) { if (m.type==='reply') this.replies.set(m.id,m.reply); }
    terminate() {}
  }
  globalThis.Worker=MockWorker;
  const root=document.createElement('main');document.body.append(root);
  const request=(operation,data) => {
    const id=++serial;worker.onmessage({data:{type:'request',id,operation,data}});
    return wait(()=>worker.replies.has(id)).then(()=>{ const reply=worker.replies.get(id);check(reply.status===1,'host reply '+reply.data);return reply.data; });
  };
  const paint=html=>request(1,html), field=()=>root.querySelector('[data-bend-field=a]');
  const type=(input,value) => { input.value=value;input.dispatchEvent(new InputEvent('input',{bubbles:true,data:value})); };
  const markup=(value,status='one',extra='') => `<section><p id="status">${status}</p><label>A<input data-bend-field="a" value="${value}"></label>${extra}<label><input type="file" data-bend-upload="/photo"></label></section>`;
  try {
    app=startBend(root,{gpu:false});
    await paint(markup('abc'));
    const a=field(), section=root.firstChild, upload=root.querySelector('[data-bend-upload]');
    a.focus();a.setSelectionRange(1,2,'backward');
    const mutations=[];const observer=new MutationObserver(ms=>mutations.push(...ms));observer.observe(root,{subtree:true,childList:true,attributes:true,characterData:true});
    await paint(markup('abc','two'));await new Promise(r=>setTimeout(r,0));observer.disconnect();
    check(field()===a&&document.activeElement===a&&a.selectionStart===1&&a.selectionEnd===2&&a.selectionDirection==='backward','unchanged field identity/focus/selection');
    check(mutations.length===1&&mutations[0].type==='characterData'&&mutations[0].target.parentElement.id==='status','only changed text mutates DOM');cases.push('unchanged nodes and selection; only changed text mutated');
    await paint(markup('abc','two','<label>B<input data-bend-field="b" value="new"></label>'));
    check(root.firstChild===section&&field()===a&&document.activeElement===a,'adding a second field retains section/input focus');
    await paint(markup('abc','two'));
    check(root.firstChild===section&&field()===a&&document.activeElement===a,'removing second field retains section/input focus');cases.push('field insertion/removal preserves general containers');
    const firstEvent=request(2,'');type(a,'abcd');await firstEvent;
    type(a,'abcde');a.setSelectionRange(2,3);
    await paint(markup('abcd','older render'));
    check(a.value==='abcde'&&document.activeElement===a&&a.selectionStart===2&&a.selectionEnd===3,'older reply preserves newer queued typing');
    check(JSON.parse(await request(2,'')).value==='abcde','latest queued edit delivered');
    await paint(markup('ABCDE','normalized'));
    check(a.value==='ABCDE'&&field()===a&&document.activeElement===a&&a.selectionStart===2,'acknowledged edit permits reducer normalization');cases.push('typing outruns render; latest consumed edit can normalize');
    a.dispatchEvent(new CompositionEvent('compositionstart',{bubbles:true}));
    const composingEvent=request(2,'');type(a,'ABCDEあ');await composingEvent;
    await paint(markup('older','composition'));
    check(a.value==='ABCDEあ'&&field()===a&&document.activeElement===a,'composition survives compatible render');
    a.dispatchEvent(new CompositionEvent('compositionend',{bubbles:true}));type(a,'ABCDEあい');
    await paint(markup('ABCDEあ','older final reply'));
    check(a.value==='ABCDEあい','composition final input survives older reply');
    await request(2,'');await paint(markup('done','new final reply'));
    check(a.value==='done','post-composition consumed edit can update');cases.push('composition and final-input ordering');
    a.focus();a.setSelectionRange(1,2);
    await paint('<section><label><input type="file" data-bend-upload="/photo"></label><p id="status">reordered</p><label>A<input data-bend-field="a" value="done"></label></section>');
    check(field()===a&&root.querySelector('[data-bend-upload]')===upload&&document.activeElement===a&&a.selectionStart===1&&a.selectionEnd===2,'keyed reorder retains input/upload/focus/selection');cases.push('keyed reorder and upload node identity');
    await paint(markup('done','controls','<label>N<input type="number" data-bend-field="n" value="2"></label><label>T<textarea data-bend-field="t">seed</textarea></label>'));
    const number=root.querySelector('[data-bend-field=n]');number.focus();type(number,'3');
    await paint(markup('done','older number','<label>N<input type="number" data-bend-field="n" value="2"></label><label>T<textarea data-bend-field="t">seed</textarea></label>'));
    check(number.value==='3'&&document.activeElement===number,'number pending value survives attribute reply');await request(2,'');
    await paint(markup('done','normalized number','<label>N<input type="number" data-bend-field="n" value="4"></label><label>T<textarea data-bend-field="t">seed</textarea></label>'));
    check(number.value==='4','number accepts consumed normalization');cases.push('number input value attributes');
    const textarea=root.querySelector('[data-bend-field=t]');textarea.focus();textarea.dispatchEvent(new CompositionEvent('compositionstart',{bubbles:true}));type(textarea,'seedあ');await request(2,'');
    await paint(markup('done','textarea composition','<label>N<input type="number" data-bend-field="n" value="4"></label><label>T<textarea data-bend-field="t">other</textarea></label>'));
    check(textarea.value==='seedあ'&&document.activeElement===textarea,'textarea composing value/children retained');
    textarea.dispatchEvent(new CompositionEvent('compositionend',{bubbles:true}));type(textarea,'seedあい');await request(2,'');
    await paint(markup('done','textarea final','<label>N<input type="number" data-bend-field="n" value="4"></label><label>T<textarea data-bend-field="t">final</textarea></label>'));
    check(textarea.value==='final','textarea accepts consumed final value');cases.push('textarea composition children and final value');
    await paint(markup('done','uploads'));a.focus();
    // Actual image decoding and JPEG encoding, with a controlled HTTP response.
    const image=document.createElement('canvas');image.width=2;image.height=2;
    const blob=await new Promise(r=>image.toBlob(r,'image/png'));const photo=new File([blob],'same.png',{type:'image/png'});
    const select=(file) => { const transfer=new DataTransfer();transfer.items.add(file);upload.files=transfer.files;upload.dispatchEvent(new Event('change',{bubbles:true})); };
    let posts=0;globalThis.fetch=async()=>{posts++;return new Response('{"ok":true}',{headers:{'Content-Type':'application/json'}});};
    select(photo);await wait(()=>posts===1&&upload.files.length===0);
    select(photo);await wait(()=>posts===2&&upload.files.length===0);
    check(root.querySelector('[data-bend-upload]')===upload,'same-file retry retains file node');cases.push('same-file retry after upload clears only file selection');
    select(new File([blob],'bad.gif',{type:'image/gif'}));await wait(()=>upload.files.length===0);
    check(posts===2,'invalid photo rejected before HTTP');select(photo);await wait(()=>posts===3&&upload.files.length===0);
    cases.push('same-file retry after upload error');
    // An older upload completion must not clear a newer retained selection.
    const releases=[];globalThis.fetch=()=>new Promise(resolve=>releases.push(()=>resolve(new Response('{"ok":true}'))));
    select(photo);await wait(()=>releases.length===1);
    const newer=new File([blob],'newer.png',{type:'image/png'});select(newer);await wait(()=>releases.length===2);
    releases[0]();await new Promise(r=>setTimeout(r,30));
    check(upload.files[0]?.name==='newer.png','superseded upload cannot clear newer file selection');
    releases[1]();await wait(()=>upload.files.length===0);cases.push('superseded upload ownership');
    await paint('<main><div class="panel"><label>A<input data-bend-field="a" value="panel"></label><p>one</p></div></main>');
    const main=root.firstChild,panel=main.firstChild,panelInput=field();panelInput.focus();panelInput.setSelectionRange(1,3);
    await paint('<main><div class="banner">Notice</div><div class="panel"><label>A<input data-bend-field="a" value="panel"></label><p>one</p></div></main>');
    check(root.firstChild===main&&main.lastChild===panel&&field()===panelInput&&document.activeElement===panelInput&&panelInput.selectionStart===1,'new unkeyed banner preserves equal focused panel');
    await paint('<main><div class="banner">Notice</div><div class="panel"><label>A<input data-bend-field="a" value="panel"></label><p>changed</p></div></main>');
    check(main.lastChild===panel&&field()===panelInput&&document.activeElement===panelInput,'changed panel also retains control anchor');
    await paint('<main><div class="panel"><label>A<input data-bend-field="a" value="panel"></label><p>changed</p></div></main>');
    check(main.firstChild===panel&&field()===panelInput&&document.activeElement===panelInput,'removing unkeyed banner retains panel');cases.push('unkeyed sibling insertion/removal reserves focused branch');
    await paint('<section><p id="status">removed</p></section>');
    check(!root.contains(panelInput)&&document.activeElement!==panelInput,'removed field is not refocused');cases.push('deleted field stays deleted');
    return {pass:true,cases};
  } finally { app?.stop();root.remove();globalThis.Worker=previousWorker;globalThis.fetch=previousFetch; }
}
