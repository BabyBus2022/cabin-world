import {randomUUID} from 'node:crypto';
const names={xiangqi:'象棋',gomoku:'五子棋',snake:'贪吃蛇'};
export class PlayerGames {
  constructor(host,hall,residents,flags){
    Object.assign(this,{host,hall,residents,flags});
    this.active=null;
    host.on('disconnected',()=>{this.active=null;});
    host.on('frame',f=>this.frame(f).catch(e=>{
      const types={'arcade.ownerInviteAnswer':'arcade.ownerInviteAnswerResult','arcade.playerReady':'arcade.playerReadyResult','arcade.playerInvite':'arcade.inviteReply'};
      host.send({type:types[f.type]||'arcade.playerResult',id:f.id,ok:false,error:e.message});
    }));
  }
  offer(r,game,words,fromPlayer=false,id=randomUUID()){
    if(!this.flags.invites12)throw Error('尚未启用游戏邀约');
    if(!Object.hasOwn(names,game)||!words?.trim()||words.length>80)throw Error('请选择象棋、五子棋或贪吃蛇，并填写本次邀请语（1–80字）');
    if(game==='gomoku'&&!this.flags.gomoku)throw Error('五子棋尚未启用');
    if(r.task||this.active?.until>Date.now()||this.active?.session?.status==='playing')throw Error('已有活动或邀请正在进行');
    const invite={id,r,game,until:Date.now()+90000,accepted:fromPlayer,remote:false};
    this.active=invite;
    this.hall.invitation={id,key:game,resident:r.key,from:fromPlayer?'owner':r.key,status:fromPlayer?'accepted':'pending',game:names[game],residentSeat:'no_seat_requested',ownerSeat:'no_seat_requested'};
    this.hall.view();
    if(!fromPlayer)this.host.send({type:'arcade.ownerInvite',from:r.key,name:r.name,inviteId:id,key:game,game:names[game],place:'星光电玩城',words,seconds:90});
    return {ok:true,inviteId:id,words};
  }
  async frame(f){
    if(!f.type?.startsWith('arcade.')||!['ownerInviteAnswer','playerInvite','playerLeave','playerJoin','playerReady','playerInput'].includes(f.type.slice(7)))return;
    const send=(type,extra)=>this.host.send({type:'arcade.'+type,id:f.id,...extra});
    let a=this.active;
    if(f.type==='arcade.playerInvite'){
      const r=this.residents.get(f.resident);
      if(!r)throw Error('住户不在场');
      const previous=f.previousMatchId&&this.hall.history.find(h=>h.matchId===f.previousMatchId&&h.kind===f.key&&['owner',r.key].every(id=>h.players.some(m=>m.id===id)));
      if(f.previousMatchId&&!previous)throw Error('上一局的对手与续局邀请不符');
      const made=this.offer(r,f.key,'一起玩'+(names[f.key]||'游戏'),true,f.id);
      a=this.active;a.remote=f.remote===true||previous?.remote===true;
      send('inviteReply',{...made,pending:true,resident:r.key,name:r.name});
      this.host.send({type:'arcade.inviteStatus',inviteId:a.id,status:'accepted',resident:r.key,name:r.name,key:a.game,game:names[a.game]});
      return;
    }
    if(f.type==='arcade.ownerInviteAnswer'){
      if(!a||a.id!==f.inviteId||a.until<Date.now())throw Error('邀请已过期');
      a.accepted=!!f.accept;a.remote=f.remote===true;
      this.hall.invitation.status=a.accepted?'accepted':'declined';this.hall.view();
      if(!a.accepted)this.active=null;
      send('ownerInviteAnswerResult',{ok:true,accept:!!f.accept,inviteId:f.inviteId});return;
    }
    if(f.type==='arcade.playerJoin'){
      if(!a||a.id!==f.inviteId||!a.accepted||a.until<Date.now()||a.game!==f.key)throw Error('请先接受有效的同桌邀请');
      const obj=a.r.objects.get(a.game==='snake'?'arcade_snake':'arcade_xiangqi');
      const task=this.hall.play(a.r,obj,'duo',a.game);
      const s=this.hall.sessions.get(a.game);const key=s.key;
      const zone=a.game==='snake'?'arcade_snake_right':'arcade_xiangqi_near';
      const guest={key:'owner',name:'你',effect:null};
      s.guest={request:f.id,remote:a.remote};
      s.members.push({r:guest,seat:1,zone,scene:a.r.spaces.get('arcade').scene,seated:false,
        resolve:out=>send('playerFinished',{outcome:{...out,matchId:s.id,kind:a.game,name:names[a.game],reason:s.reason,partner:a.r.name}}),
        reject:e=>send('playerFinished',{outcome:{matchId:s.id,reason:e.message,result:'interrupted'}})});
      a.session=s;task.promise.finally(()=>{if(this.active===a)this.active=null;});
      send('playerResult',{ok:true,key,zone,seat:1,matchId:s.id,partner:a.r.name,joined:true,remote:a.remote});this.hall.watch(s);return;
    }
    const s=a?.session;
    if(f.type==='arcade.playerLeave'){
      if(s&&(s.id===f.matchId||s.guest.request===f.id))this.hall.interrupt(s,'玩家离席');
      if(a&&(a.id===f.inviteId||a.id===f.id))this.active=null;
      return;
    }
    if(!s||s.id!==f.matchId)return;
    const member=s.members.find(m=>m.r.key==='owner');
    if(f.type==='arcade.playerReady'&&s.status==='waiting'){
      member.seated=s.guest.remote||await this.hall.rule('residentAt',{actor:'owner',scene:member.scene,zone:member.zone});
      send('playerReadyResult',{ok:!!member.seated,matchId:s.id});if(member.seated)await this.hall.pulse({key:s.key,matchId:s.id});
    }
    if(f.type==='arcade.playerInput'&&s.status==='playing'){
      const inp=f.input||{};
      if(inp.resign===true){this.hall.interrupt(s,'玩家认输离席');return;}
      if(a.game==='snake'&&['up','down','left','right'].includes(inp.direction))s.playerInput={owner:inp.direction};
      else if(s.board?.sides?.[s.board.turn]==='owner'){
        if(a.game==='gomoku'&&Number.isInteger(inp.at)&&inp.at>=0&&inp.at<225)s.playerInput={player:'owner',at:inp.at};
        if(a.game==='xiangqi'&&[inp.from,inp.to].every(i=>Number.isInteger(i)&&i>=0&&i<90))s.playerInput={player:'owner',from:inp.from,to:inp.to};
      }
    }
  }
}
