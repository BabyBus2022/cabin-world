extends RefCounted

const OWNER="owner"
const RECEIPT="cabinCoinReceipt"
var displayed:=0
var pending:Dictionary={}
var resident_action:=false

func balance()->int:
 return int(Economy.people.get(OWNER,{}).get("wallet",{}).get("coins",0))

func ensure_owner()->bool:
 if Economy.people.get(OWNER,{}).has("wallet"):return true
 return Economy._answer({"actor":OWNER,"op":"top_up","id":"init-farm-wallet-"+str(Time.get_ticks_usec())}).get("ok",false)

# Only a receipt written alongside a successful farm save can move Cabin World money.
# Unmarked farm saves may contain arbitrary legacy balances, including zero.
func remember(raw):
 if raw is Dictionary and int(raw.get("seq",0))>int(pending.get("seq",0)) and raw.has("delta"):
  pending=raw.duplicate()

func recover(folder:String,files:Array):
 for name_ in files:
  var path=folder.path_join(name_)
  if not FileAccess.file_exists(path):continue
  var doc=JSON.parse_string(FileAccess.get_file_as_string(path))
  if doc is Dictionary:remember(doc.get(RECEIPT))
 if not pending.is_empty():settle()

func settle()->bool:
 if pending.is_empty():return true
 if not ensure_owner():return false
 var person:Dictionary=Economy.people[OWNER]
 var seq=int(person.get("farmCoinSeq",0))
 if int(pending.seq)<=seq:
  pending={};return true
 if int(pending.seq)!=seq+1:return false
 var before=balance()
 var rev=int(person.get("rev",0))
 var after=before+int(pending.delta)
 if after<0:return false
 person.wallet.coins=after
 person.farmCoinSeq=pending.seq
 person.rev=rev+1
 if not Economy._save():
  person.wallet.coins=before;person.farmCoinSeq=seq;person.rev=rev
  return false
 pending={}
 return true

func attach(sim):
 remember(sim.data.get(RECEIPT))
 ensure_owner()
 settle()
 displayed=balance()+int(pending.get("delta",0))
 sim.data.coins=displayed
 sim.cabin_wallet=self

# Keep any uncommitted local transaction when the arcade or shop changes the wallet.
func refresh(sim):
 if resident_action or not pending.is_empty():return
 var latest=balance()
 if latest!=displayed:
  sim.data.coins=int(sim.data.coins)+latest-displayed
  displayed=latest

func save(sim,path:String)->bool:
 # A resident temporarily uses the live farm simulation with her own wallet.
 # The normal resident commit saves once she has restored the player's view.
 if resident_action:return true
 if not ensure_owner() or not settle():return false
 refresh(sim)
 var delta=int(sim.data.coins)-displayed
 if delta==0:return sim.write_farm_file(path)
 var previous=sim.data.get(RECEIPT)
 var receipt={"seq":int(Economy.people[OWNER].get("farmCoinSeq",0))+1,"delta":delta}
 sim.data[RECEIPT]=receipt
 if not sim.write_farm_file(path):
  if previous==null:sim.data.erase(RECEIPT)
  else:sim.data[RECEIPT]=previous
  return false
 pending=receipt
 displayed=int(sim.data.coins)
 return settle()
