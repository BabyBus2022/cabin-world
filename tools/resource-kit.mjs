import fs from 'node:fs'
import path from 'node:path'
import crypto from 'node:crypto'
import { fileURLToPath } from 'node:url'

const home = path.dirname(path.dirname(fileURLToPath(import.meta.url)))
const edit = path.join(home, 'editable', 'resources')
const pack = path.join(home, 'CabinWorld.engine.pck')
const original = path.join(home, 'editable', 'CabinWorld.original.pck')
const manifest = JSON.parse(fs.readFileSync(path.join(home, 'editable', 'manifest.json'), 'utf8'))
const hash = (data, algorithm = 'sha256') => crypto.createHash(algorithm).update(data).digest()
const pad = (n, size) => (size - n % size) % size
function safe(root, name) {
  if (!name || name.includes('\\') || name.split('/').some(part => !part || part === '.' || part === '..' || part.includes(':'))) throw Error('Invalid resource path: ' + name)
  return path.join(root, ...name.split('/'))
}
function entries(buf) {
  if (buf.toString('ascii', 0, 4) !== 'GDPC') throw Error('Invalid game pack')
  const base = Number(buf.readBigUInt64LE(24))
  let p = Number(buf.readBigUInt64LE(32))
  const count = buf.readUInt32LE(p); p += 4
  const list = new Map()
  for (let i = 0; i < count; i++) {
    const n = buf.readUInt32LE(p); p += 4
    const name = buf.toString('utf8', p, p+n).replace(/\0+$/, ''); p += n
    const off = base + Number(buf.readBigUInt64LE(p))
    const size = Number(buf.readBigUInt64LE(p+8))
    const md5 = buf.subarray(p+16,p+32), flags = buf.readUInt32LE(p+32); p += 36
    if (off < base || off+size > buf.length || list.has(name)) throw Error('Invalid record: '+name)
    list.set(name, {data:buf.subarray(off,off+size), md5, flags})
  }
  return list
}
function* walk(dir, prefix='') {
  for (const item of fs.readdirSync(dir,{withFileTypes:true})) {
    const name=prefix+item.name
    if (item.isSymbolicLink()) throw Error('Links are not editable resources: '+name)
    if (item.isDirectory()) yield* walk(path.join(dir,item.name),name+'/')
    else if (item.isFile()) yield name
  }
}
function writePack(target, header, rows) {
  const fd=fs.openSync(target,'wx')
  let position=0
  function write(data) {
    let offset=0
    while(offset<data.length) offset+=fs.writeSync(fd,data,offset,data.length-offset,position+offset)
    position+=data.length
  }
  try {
    write(header.subarray(0,128))
    const directory=[Buffer.alloc(4)]
    directory[0].writeUInt32LE(rows.size)
    for (const [name,row] of rows) {
      write(Buffer.alloc(pad(position,16)))
      const nb=Buffer.from(name), len=nb.length+pad(nb.length,4), record=Buffer.alloc(4+len+36)
      record.writeUInt32LE(len); nb.copy(record,4)
      record.writeBigUInt64LE(BigInt(position-128),4+len);record.writeBigUInt64LE(BigInt(row.data.length),12+len)
      row.md5.copy(record,20+len);record.writeUInt32LE(row.flags,36+len)
      directory.push(record);write(row.data)
    }
    write(Buffer.alloc(pad(position,16)))
    const pointer=Buffer.alloc(8);pointer.writeBigUInt64LE(BigInt(position))
    write(Buffer.concat(directory));fs.writeSync(fd,pointer,0,8,32)
    fs.fsyncSync(fd)
  } finally {fs.closeSync(fd)}
}
function updateTexture(rows,name,png) {
  const mapping=rows.get(name+'.import')
  if(!mapping)return
  if(png.subarray(1,4).toString()!=='PNG' || png.toString('ascii',12,16)!=='IHDR')throw Error('Invalid PNG: '+name)
  const width=png.readUInt32BE(16),height=png.readUInt32BE(20)
  if(!width || !height || Math.max(width,height)>16384)throw Error('Unsupported PNG dimensions: '+name)
  for(const match of mapping.data.toString('utf8').matchAll(/^path(?:\.\w+)?="res:\/\/([^"]+\.ctex)"/gm)){
    const dest=match[1],old=rows.get(dest)
    if(!old || old.data.toString('ascii',0,4)!=='GST2')throw Error('Invalid texture mapping: '+name)
    const header=Buffer.from(old.data.subarray(0,56))
    header.writeUInt32LE(width,8);header.writeUInt32LE(height,12)
    header.writeUInt32LE(1,36);header.writeUInt16LE(width,40);header.writeUInt16LE(height,42)
    header.writeUInt32LE(0,44);header.writeUInt32LE(5,48);header.writeUInt32LE(png.length+4,52)
    const data=Buffer.concat([header,Buffer.from('PNG '),png])
    rows.set(dest,{data,md5:hash(data,'md5'),flags:0})
  }
}
function main(mode) {
  if (mode==='export') {
    const dest=path.join(home,'editable','exported')
    let count=0
    for (const [name,row] of entries(fs.readFileSync(pack))) {
      const file=safe(dest,name)
      if(fs.existsSync(file)) continue
      fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,row.data,{flag:'wx'});count++
    }
    console.log('Exported',count,'resources to',dest)
    return
  }
  if (!['apply','restore'].includes(mode)) throw Error('Expected apply, export or restore')
  const base=fs.existsSync(original)?original:pack
  const buf=fs.readFileSync(base)
  if (hash(buf).toString('hex')!==manifest.base) throw Error('Base pack belongs to a different release. Use a clean copy of this release.')
  if (base===pack) fs.copyFileSync(base,original,fs.constants.COPYFILE_EXCL)
  const temp=pack+'.edit-'+crypto.randomUUID()
  try {
    if(mode==='restore')fs.copyFileSync(original,temp,fs.constants.COPYFILE_EXCL)
    else {
      const rows=entries(buf)
      const changed=[]
      for(const name of walk(edit)){
        const data=fs.readFileSync(safe(edit,name))
        if (hash(data).toString('hex')===manifest.defaults[name]) continue
        if (name.endsWith('.json')) JSON.parse(data.toString('utf8').replace(/^\uFEFF/,''))
        if(name.endsWith('.png'))updateTexture(rows,name,data)
        if(name.endsWith('.tscn') || name.endsWith('.tres'))rows.delete(name+'.remap')
        if(name.endsWith('.gd')){rows.delete(name+'c');rows.delete(name+'.remap')}
        rows.set(name,{data,md5:hash(data,'md5'),flags:0});changed.push(name)
      }
      writePack(temp,buf,rows)
      const result=entries(fs.readFileSync(temp))
      if(result.size!==rows.size || changed.some(n=>!hash(result.get(n).data,'md5').equals(rows.get(n).md5))) throw Error('Could not verify edited pack')
      console.log('Changed resources:',changed.length)
    }
    fs.renameSync(temp,pack)
  } finally { if(fs.existsSync(temp))fs.unlinkSync(temp) }
  console.log('Ready:',pack)
}
try { main(process.argv[2]) } catch(err) { console.error(err.message);process.exitCode=1 }

