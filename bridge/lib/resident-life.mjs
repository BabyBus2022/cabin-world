import fs from 'node:fs';
import path from 'node:path';
import {randomUUID} from 'node:crypto';
import {supplyNeeds} from './pasture-needs.mjs';

const allowed = new Set(['cabin_go','cabin_use','cabin_buy','cabin_eat','cabin_restaurant']);
const note = e => String(e?.message || e).slice(0,240);
export class ResidentLife {
  constructor({folder,flags,residents,dispatch,ready,event}) {
    Object.assign(this,{folder,flags,residents,dispatch,ready,event});
    this.file=path.join(folder,'resident-plans.json');
    this.plans=fs.existsSync(this.file)?JSON.parse(fs.readFileSync(this.file,'utf8')):[];
    this.busy=new Set(); this.nextCheck=new Map(); this.closed=false;
    // A disconnect after the game committed a purchase must not buy it a second time.
    for(const p of this.plans) if(p.status==='running'){p.status='blocked';p.issue='上次中断，请核对游戏回执后再安排剩余步骤';}
    this.timer=setInterval(()=>this.tick(),2000);this.timer.unref();
  }
  save(){
    const tmp=this.file+'.'+randomUUID()+'.tmp';
    fs.writeFileSync(tmp,JSON.stringify(this.plans));fs.renameSync(tmp,this.file);
  }
  handle(actor,a){
    if(!this.flags.agenda12)throw Error('请先启用住户候补计划');
    if(!a.action||a.action==='list')return {ok:true,plans:this.plans.filter(p=>p.actor===actor).slice(-30)};
    if(a.action==='cancel'){
      const p=this.plans.find(p=>p.actor===actor&&p.id===a.id);
      if(!p||p.status==='running')throw Error('请在当前步骤结束后取消剩余安排');
      p.status='cancelled';this.save();return {ok:true,plan:p};
    }
    if(a.action==='revise'){
      const prev=this.plans.find(p=>p.id===a.id&&p.actor===actor);
      if(!prev||!['queued','blocked'].includes(prev.status))throw Error('只能修改等待中或受阻的计划');
      const next=this.add(actor,a.title||prev.title,a.steps,'manual');
      if(next!==prev){prev.status='cancelled';this.save();}
      return {ok:true,plan:next};
    }
    if(a.action!=='add')throw Error('请选择 add、list、revise 或 cancel');
    return {ok:true,plan:this.add(actor,a.title,a.steps,'manual')};
  }
  add(actor,title,steps,source){
    if(typeof title!=='string'||!title.trim()||!Array.isArray(steps)||!steps.length||steps.length>32)throw Error('填写计划名称和 1 至 32 个步骤');
    const clean=steps.map(s=>{
      if(!allowed.has(s.tool)||!s.args||typeof s.args!=='object'||Array.isArray(s.args)||JSON.stringify(s.args).length>2000)throw Error('无效的游戏步骤');
      if('actor' in s.args)throw Error('每份计划只控制自己的角色');
      return {tool:s.tool,args:s.args};
    });
    const prior=this.plans.find(p=>p.actor===actor&&p.source===source&&['queued','running'].includes(p.status)&&JSON.stringify(p.steps)===JSON.stringify(clean));
    if(prior)return prior;
    if(source!=='manual'){
      const blocked=this.plans.find(p=>p.actor===actor&&p.source===source&&p.status==='blocked'&&p.failedAt>Date.now()-600000&&JSON.stringify(p.steps)===JSON.stringify(clean));
      if(blocked)return blocked;
    }
    if(this.plans.filter(p=>p.actor===actor&&['queued','running'].includes(p.status)).length>=24)throw Error('候补计划已满');
    this.plans=this.plans.filter((p,i)=>i>=this.plans.length-80||['queued','running','blocked'].includes(p.status));
    const p={id:randomUUID(),actor,title:title.slice(0,100),source,steps:clean,index:0,status:'queued'};
    this.plans.push(p);this.save();return p;
  }
  tick(){
    if(this.closed||!this.ready())return;
    for(const r of this.residents.values()){
      if(this.busy.has(r.key)||r.task||r.view?.options?.paused||r.processes?.list().some(x=>x.kind==='body'&&['queued','running'].includes(x.status)))continue;
      this.busy.add(r.key);
      this.advance(r).catch(e=>this.event({type:'resident-care',actor:r.key,text:note(e)})).finally(()=>this.busy.delete(r.key));
    }
  }
  async advance(r){
    const due=(this.nextCheck.get(r.key)||0)<=Date.now();
    if(due){
      this.nextCheck.set(r.key,Date.now()+60000);
      if(this.flags.needs12||this.flags.pasture12||this.flags.farmwork12)await this.care(r);
    }
    if(this.closed||!this.ready()||r.task)return;
    const enabled=p=>p.source==='manual'?this.flags.agenda12:p.source==='needs'?this.flags.needs12:this.flags.village12&&(p.source==='field'?this.flags.farmwork12:this.flags.pasture12);
    const p=this.plans.find(p=>p.actor===r.key&&p.status==='queued'&&enabled(p));
    if(!p)return;
    const step=p.steps[p.index];p.status='running';this.save();
    try{
      let result=await this.dispatch(step.tool,{...step.args,actor:r.key});
      if(result?.promise){const task=result;await task.promise;if(task.status!=='done')throw Error(task.error||'未收到完成回执');result=task.result;}
      if(!result||result.ok===false||result.farmOk===false)throw Error(result?.error||result?.text||'游戏拒绝了这一步');
      p.index++;p.status=p.index===p.steps.length?'completed':'queued';
    }catch(e){p.status='blocked';p.issue=note(e);p.failedAt=Date.now();}
    this.save();this.event({type:'resident-plan',actor:r.key,title:p.title,status:p.status,finished:p.index,issue:p.issue});
  }
  async care(r){
    if(this.flags.needs12){
      await r.eco('sync',{rev:0});
      for(const [key,need] of [['hydration','thirst'],['satiety','hunger']]){
        const level=r.view?.feeling?.[key];if(!Number.isFinite(level)||level>25)continue;
        if(this.plans.some(p=>p.actor===r.key&&p.source==='needs'&&['queued','running'].includes(p.status)))return;
        const {plan}=await r.eco('need_plan',{need,who:r.who,space:r.space||'',now:Date.now(),weather:r.weatherNow()});
        if(!plan)return;
        const steps=[];
        if(plan.action==='use')steps.push({tool:'cabin_use',args:{object:plan.objectId,use:plan.use}});
        if(plan.action==='buy')steps.push({tool:'cabin_buy',args:{product:plan.product,drinkHere:plan.drinkHere===true}});
        if(['eat','drink','buy'].includes(plan.action)&&!plan.drinkHere)steps.push({tool:'cabin_eat',args:{product:plan.product}});
        if(steps.length)this.add(r.key,need==='thirst'?'补充水分':'补充体力',steps,'needs');
        return;
      }
    }
    if(!this.flags.village12||(!this.flags.pasture12&&!this.flags.farmwork12))return;
    let latest=null;
    for(const file of ['open-meadow.json','village-center-test.json']){
      const target=path.join(this.folder,'world','qingxi-saves',file);
      if(!fs.existsSync(target))continue;
      const data=JSON.parse(fs.readFileSync(target,'utf8'));
      if(!latest||Number(data.last_wall)>Number(latest.last_wall))latest=data;
    }
    for(const n of (this.flags.pasture12?supplyNeeds(latest):[])){
      const source='pasture/'+n.kind;
      if(this.plans.some(p=>p.source===source&&['queued','running'].includes(p.status)))continue;
      const steps=[{tool:'cabin_go',args:{place:'qingxi',zone:'qx_farm'}}];
      if(n.buy)steps.push({tool:'cabin_use',args:{object:'qx_seed_counter',use:'buy',item:n.food+'×'+n.buy}});
      for(let i=0;i<n.portions;i++)steps.push({tool:'cabin_use',args:{object:'qx_pasture',use:'feed',item:n.animal}});
      this.add(r.key,'给'+n.animal+'补'+n.food,steps,source);
      this.event({type:'pasture-supply',actor:r.key,text:n.count+'只'+n.animal+'缺粮，已安排补给'});return;
    }
    if(!this.flags.farmwork12||!latest?.layout?.plots?.length||this.plans.some(p=>['queued','running'].includes(p.status)))return;
    const {farm}=await r.eco('qingxi',{act:'look'});
    if(!farm||!Array.isArray(farm.plotList))return;
    const use=farm.plotList.some(p=>p.can_harvest||p.can_clear)?'harvest':farm.plotList.some(p=>p.can_plant)&&latest.bag?.seed>0?'plant':farm.plotList.some(p=>p.can_water)?'water':'';
    if(use&&!this.plans.some(p=>p.source==='field'&&['queued','running'].includes(p.status)))this.add(r.key,'照看农田',[{tool:'cabin_use',args:{object:'qx_fields',use}}],'field');
  }
  close(){this.closed=true;clearInterval(this.timer);}
}
