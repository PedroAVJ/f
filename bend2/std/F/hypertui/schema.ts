export type Schema = {[key:string]:any};
const annotations = new Set(['$schema','$id','$comment','title','description','default','examples','example','deprecated','readOnly','writeOnly','format','contentEncoding','contentMediaType','errorMessage','x-openai-web-call-encoding']);
const values = new Set(['type','enum','const','required','minimum','maximum','exclusiveMinimum','exclusiveMaximum','multipleOf','minLength','maxLength','pattern','minItems','maxItems','uniqueItems','minProperties','maxProperties','$ref']);
const maps = new Set(['properties','$defs','definitions','patternProperties','dependentSchemas']);
const singles = new Set(['items','additionalProperties','not','if','then','else','contains','propertyNames']);
const groups = new Set(['allOf','anyOf','oneOf','prefixItems']);
const own = (value:object,key:string) => Object.hasOwn(value,key);

export function checkSchema(schema:unknown,depth=0):void {
  if(typeof schema==='boolean') return;
  if(!schema || typeof schema!=='object' || Array.isArray(schema) || depth>64) throw Error('Invalid action schema.');
  for(const [key,value] of Object.entries(schema)) {
    if(annotations.has(key)) continue;
    if(maps.has(key)) {
      if(!value || typeof value!=='object' || Array.isArray(value)) throw Error('Invalid schema map: '+key);
      for(const child of Object.values(value)) checkSchema(child,depth+1);
    } else if(singles.has(key)) checkSchema(value,depth+1);
    else if(groups.has(key)) {
      if(!Array.isArray(value)) throw Error('Invalid schema alternatives: '+key);
      for(const child of value) checkSchema(child,depth+1);
    } else if(!values.has(key)) throw Error('Unsupported action schema keyword: '+key);
    if(key==='$ref' && (typeof value!=='string' || !value.startsWith('#/'))) throw Error('Only local schema references are supported.');
    if(key==='pattern') {if(typeof value!=='string') throw Error('Invalid schema pattern.');new RegExp(value,'u');}
    if(key==='type' && !(Array.isArray(value)?value:[value]).every(v=>['object','array','string','number','integer','boolean','null'].includes(v))) throw Error('Invalid schema type.');
    if(key==='required' && (!Array.isArray(value)||value.some(v=>typeof v!=='string'))) throw Error('Invalid required fields.');
    if(key==='enum' && (!Array.isArray(value)||!value.length)) throw Error('Invalid enum.');
  }
}
const canonical = (value:any):string => value && typeof value==='object' ? Array.isArray(value) ? '['+value.map(canonical).join(',')+']' : '{'+Object.keys(value).sort().map(k=>JSON.stringify(k)+':'+canonical(value[k])).join(',')+'}' : JSON.stringify(value);
export function validate(schema:Schema,value:unknown,location='arguments'):void {
  let budget=50000;
  const root=schema;
  const resolve=(ref:string) => ref.slice(2).split('/').map(s=>s.replace(/~1/g,'/').replace(/~0/g,'~')).reduce((v,key)=>v && typeof v==='object' && own(v,key)?v[key]:undefined,root);
  function error(message:string):never {throw Error(message);}
  function matches(rule:any,value:any,path:string,depth:number) {try{visit(rule,value,path,depth);return true;}catch(e){if(e instanceof RangeError)throw e;return false;}}
  function visit(rule:any,value:any,path:string,depth:number):void {
    if(--budget<0 || depth>64) throw new RangeError('Action schema validation limit exceeded.');
    if(rule===true) return;
    if(rule===false) error(path+' is not allowed.');
    if(!rule || typeof rule!=='object') error('Invalid referenced schema.');
    if(rule.$ref) {const target=resolve(rule.$ref);if(target===undefined)error('Unknown local schema reference.');visit(target,value,path,depth+1);}
    if(rule.allOf) for(const child of rule.allOf) visit(child,value,path,depth+1);
    if(rule.anyOf && !rule.anyOf.some((child:any)=>matches(child,value,path,depth+1))) error(path+' does not match an allowed schema.');
    if(rule.oneOf && rule.oneOf.filter((child:any)=>matches(child,value,path,depth+1)).length!==1) error(path+' must match exactly one schema.');
    if(rule.not!==undefined && matches(rule.not,value,path,depth+1)) error(path+' matches a forbidden schema.');
    if(rule.if!==undefined) {const branch=matches(rule.if,value,path,depth+1)?rule.then:rule.else;if(branch!==undefined)visit(branch,value,path,depth+1);}
    if(rule.type) {
      const types=Array.isArray(rule.type)?rule.type:[rule.type];
      const valid=types.some((type:string)=>type==='null'?value===null:type==='array'?Array.isArray(value):type==='object'?!!value&&typeof value==='object'&&!Array.isArray(value):type==='integer'?typeof value==='number'&&Number.isInteger(value):type==='number'?typeof value==='number'&&Number.isFinite(value):typeof value===type);
      if(!valid) error(path+' must be '+types.join(' or ')+'.');
    }
    if(own(rule,'const') && canonical(value)!==canonical(rule.const)) error(path+' must equal its declared constant.');
    if(rule.enum && !rule.enum.some((v:any)=>canonical(v)===canonical(value))) error(path+' is not an allowed value.');
    if(typeof value==='string') {
      const length=Array.from(value).length;
      if(rule.minLength!==undefined&&length<rule.minLength || rule.maxLength!==undefined&&length>rule.maxLength) error(path+' has an invalid string length.');
      if(rule.pattern && !new RegExp(rule.pattern,'u').test(value)) error(path+' does not match its pattern.');
    } else if(typeof value==='number') {
      if(!Number.isFinite(value) || rule.minimum!==undefined&&value<rule.minimum || rule.maximum!==undefined&&value>rule.maximum || rule.exclusiveMinimum!==undefined&&value<=rule.exclusiveMinimum || rule.exclusiveMaximum!==undefined&&value>=rule.exclusiveMaximum) error(path+' is outside its numeric range.');
      if(rule.multipleOf!==undefined && Math.abs(value/rule.multipleOf-Math.round(value/rule.multipleOf))>1e-10) error(path+' is not a permitted multiple.');
    } else if(Array.isArray(value)) {
      if(rule.minItems!==undefined&&value.length<rule.minItems || rule.maxItems!==undefined&&value.length>rule.maxItems) error(path+' has an invalid item count.');
      if(rule.uniqueItems && new Set(value.map(canonical)).size!==value.length) error(path+' must have unique items.');
      value.forEach((item,index)=>{const child=rule.prefixItems?.[index]??rule.items;if(child!==undefined)visit(child,item,path+'['+index+']',depth+1);});
      if(rule.contains!==undefined && !value.some(item=>matches(rule.contains,item,path,depth+1))) error(path+' has no matching item.');
    } else if(value && typeof value==='object') {
      const keys=Object.keys(value);
      if(rule.minProperties!==undefined&&keys.length<rule.minProperties || rule.maxProperties!==undefined&&keys.length>rule.maxProperties) error(path+' has an invalid property count.');
      for(const name of rule.required??[]) if(!own(value,name)) error(path+'.'+name+' is required.');
      for(const name of keys) {
        if(rule.propertyNames!==undefined)visit(rule.propertyNames,name,path+' property name',depth+1);
        let known=false;
        if(rule.properties && own(rule.properties,name)) {visit(rule.properties[name],value[name],path+'.'+name,depth+1);known=true;}
        for(const [pattern,child] of Object.entries(rule.patternProperties??{})) if(new RegExp(pattern,'u').test(name)) {visit(child,value[name],path+'.'+name,depth+1);known=true;}
        if(!known && rule.additionalProperties===false) error('Unknown field: '+path+'.'+name);
        if(!known && typeof rule.additionalProperties==='object') visit(rule.additionalProperties,value[name],path+'.'+name,depth+1);
      }
      for(const [name,child] of Object.entries(rule.dependentSchemas??{})) if(own(value,name)) visit(child,value,path,depth+1);
    }
  }
  visit(schema,value,location,0);
}
