import {randomUUID} from 'node:crypto';
import {setTimeout as delay} from 'node:timers/promises';

export function farmSummary(farm,object='qx_farm_board',page=1){
  if(!farm)return null;
  const view={map:farm.map,mapTitle:farm.mapTitle,todo:farm.todo,urgent:farm.urgent?.slice(0,5),plotTotal:farm.plotTotal,petsTotal:farm.petsTotal};
  const sections={qx_shared_chest:['sharedChestRooms','sharedChest'],qx_fields:['plotList'],qx_pasture:['animalsDetailed','pens','pondTasks'],qx_pets:['petsDetailed','petTodo'],qx_cottage:['beds','occupiedBeds']};
  const size=5;
  for(const key of sections[object]||['next']){
    const value=farm[key];
    if(Array.isArray(value)){
      view[key]=value.slice((page-1)*size,page*size);
      view[key+'Total']=value.length;
      if(value.length>page*size)view.more='look 的 item 可填 page:'+(page+1);
    }else if(value!=null)view[key]=value;
  }
  if(object==='qx_pasture')view.pond=farm.pond;
  if(object==='qx_pets'&&farm.pet)view.pet=farm.pet;
  return view;
}

// Farm changes are committed by the game. Retain its receipt and refusal reason.
export async function useQingxi(resident,object,spec,item){
  const act=spec.farmAction;
  const call=async(fields)=>{
    const record=(ok,text)=>{
      if(['approach','crop_targets','look','guide'].includes(fields.act))return;
      resident._qingxiLog=[...(resident._qingxiLog||[]).slice(-63),{at:Date.now(),act:fields.act,ok,text:String(text||'').slice(0,200)}];
    };
    try {
      const receipt=await resident.eco('qingxi',fields);
      if(receipt.ok===false||receipt.farmOk===false||receipt.error)throw Error(receipt.error||receipt.text||'游戏拒绝了这次操作');
      const {state,view,catalog,farm,...result}=receipt;
      if(farm){
        resident._qingxiFarm=farm;
        result.farm=farmSummary(farm,object.id,Number(/^page:(\d+)$/.exec(item)?.[1])||1);
      }
      record(true,receipt.text);return result;
    }catch(e){record(false,e.message);throw e;}
  };
  if(act==='look'&&object.id!=='qx_farm_board')return call({act:'look',arg:item.startsWith('page:')?'':item});
  await resident.walkTo('qingxi-village',object.zone);
  const execute=async(arg,verb=act,spot=object.zone)=>{
    const fields={act:verb,arg,spot,workId:randomUUID()};
    {
      const deadline=Date.now()+90000;
      for(;;){
        const arrival=await call({...fields,act:'approach',workAct:verb});
        if(verb==='fill_water'&&arrival.waterSource==='village'){
          await resident.walkTo('qingxi-village','qx_plaza');
          const refill=await execute('','village_well','qx_plaza');
          await resident.walkTo('qingxi-village',object.zone);
          return refill;
        }
        if(arrival.arrived===true)break;
        if(!Number.isFinite(arrival.waitMs)||Date.now()>=deadline)throw Error(arrival.text||'尚未走到操作点');
        await delay(Math.min(1800,Math.max(180,arrival.waitMs)));
      }
    }
    if(act==='guide'&&['prices','breeds','growth','actions','rules'].includes(arg)){
      await call({act:'look'});
      const farm=resident._qingxiFarm;
      return {ok:true,topic:arg,detail:(['breeds','growth'].includes(arg)?farm?.petRules?.[arg]:farm?.[arg])??null};
    }
    return call(fields);
  };
  if(['plant','harvest','water_plot'].includes(act)){
    if(/^([1-9]\d*|\d+[:：]\d+)$/.test(item.trim())){
      const {farm,...receipt}=await execute(item.trim());
      return {ok:true,results:[receipt]};
    }
    const plan=await call({act:'crop_targets',workAct:act,arg:item});
    if(!plan.plotIds?.length)throw Error(plan.text||'没有符合条件的田块');
    const results=[];
    for(const plot of plan.plotIds){
      try{const {farm,...receipt}=await execute(String(plot));results.push(receipt);}
      catch(error){if(!results.length)throw error;return {ok:false,results,error:error.message};}
    }
    return {ok:true,results};
  }
  const result=await execute(item);
  if(!['fish','river_fish'].includes(act))return result;
  if(!(result.biteMs>0&&result.biteMs<=6000))throw Error(result.text||'没有收到抛竿回执');
  await delay(result.biteMs+250);
  return call({act:'reel',arg:''});
}
