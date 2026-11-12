# Tek dosyalik kurulum: PowerShell'de bu dosyayi calistirin.
# Ornek: powershell -ExecutionPolicy Bypass -File .\setup-game.ps1
$ErrorActionPreference = 'Stop'

$root = Join-Path $env:USERPROFILE 'Desktop\arabalar'
$assetRepo = 'https://github.com/mhkmehmet12345-ops/Ara-lara.git'
$tempRepo = Join-Path $env:TEMP ('ara-lara-assets-' + [guid]::NewGuid().ToString('N'))
$publicDir = Join-Path $root 'public'
$modelDir = Join-Path $publicDir 'models'

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  throw 'Git bulunamadi. Git ve Git LFS kurulumundan sonra bu dosyayi tekrar calistirin.'
}

New-Item -ItemType Directory -Force $root, $publicDir, $modelDir | Out-Null

Write-Host 'Arac deposu ve LFS modelleri indiriliyor...'
git clone $assetRepo $tempRepo
if ($LASTEXITCODE -ne 0) { throw 'Arac deposu klonlanamadi.' }
git -C $tempRepo lfs pull
if ($LASTEXITCODE -ne 0) { throw 'Git LFS modelleri indirilemedi.' }

$models = @(Get-ChildItem -LiteralPath $tempRepo -Filter '*.glb' -File)
if ($models.Count -eq 0) { throw 'Depoda GLB arac modeli bulunamadi.' }
foreach ($model in $models) {
  if ($model.Length -lt 1024) { throw "LFS modeli gercek dosya degil veya eksik: $($model.Name) ($($model.Length) byte)" }
}
Copy-Item -Path (Join-Path $tempRepo '*.glb') -Destination $modelDir -Force
$modelNames = @(Get-ChildItem -LiteralPath $modelDir -Filter '*.glb' -File | ForEach-Object Name)
$modelNames | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $modelDir 'models.json') -Encoding UTF8

@'
{
  "name": "dugun-konvoyu",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "scripts": { "start": "node server.js" },
  "dependencies": { "express": "^4.21.2", "three": "^0.170.0", "ws": "^8.18.0" }
}
'@ | Set-Content -LiteralPath (Join-Path $root 'package.json') -Encoding UTF8

@'
import express from 'express';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { WebSocketServer, WebSocket } from 'ws';

const here = path.dirname(fileURLToPath(import.meta.url));
const app = express();
const server = http.createServer(app);
app.use('/vendor', express.static(path.join(here, 'node_modules', 'three')));
app.use(express.static(path.join(here, 'public')));
app.get('/health', (_req, res) => res.json({ ok: true }));
const wss = new WebSocketServer({ server, path: '/ws' });
wss.on('connection', socket => {
  socket.on('message', raw => {
    for (const client of wss.clients) {
      if (client !== socket && client.readyState === WebSocket.OPEN) client.send(raw.toString());
    }
  });
});
const port = Number(process.env.PORT || 8765);
server.listen(port, '127.0.0.1', () => console.log(`Server listening at http://127.0.0.1:${port}`));
'@ | Set-Content -LiteralPath (Join-Path $root 'server.js') -Encoding UTF8

@'
<!doctype html>
<html lang="tr">
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Gelin Konvoyu</title>
<script type="importmap">{"imports":{"three":"/vendor/build/three.module.js","three/addons/":"/vendor/examples/jsm/"}}</script>
<style>
*{box-sizing:border-box}html,body{margin:0;width:100%;height:100%;overflow:hidden;background:#050a10;font-family:Arial,sans-serif}#app{position:relative;width:min(100vw,1080px);height:min(100vh,1920px);margin:auto;overflow:hidden;background:#b9d9e8}canvas{display:block;width:100%;height:100%}.top{position:absolute;z-index:2;top:14px;left:16px;right:16px;display:flex;justify-content:space-between;pointer-events:none}.badge,.bottom{color:#f2f8ff;background:#344351df;border-radius:17px;padding:13px 19px;font-weight:900;box-shadow:0 8px 20px #0002}.badge:last-child{background:linear-gradient(120deg,#ff80c8,#d776ff)}.bottom{position:absolute;z-index:2;bottom:15px;left:16px;right:16px;display:flex;justify-content:space-between;font-size:13px}.status{position:absolute;z-index:3;top:50%;left:50%;transform:translate(-50%,-50%);padding:10px 14px;border-radius:10px;background:#172431c9;color:white;font-size:13px}.status:empty{display:none}
</style>
</head>
<body><main id="app"><div class="top"><div class="badge">GELİN &amp; DAMAT</div><div class="badge">KONVOY</div></div><div class="bottom"><span>Hediye geldikçe konvoy hareket eder</span><span id="count">Araçlar yükleniyor…</span></div><div class="status" id="status"></div></main>
<script type="module">
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
const app=document.querySelector('#app'), status=document.querySelector('#status'), count=document.querySelector('#count');
const scene=new THREE.Scene(); scene.background=new THREE.Color('#b9d9e8');
const camera=new THREE.PerspectiveCamera(42,app.clientWidth/app.clientHeight,.1,300); camera.position.set(0,23,34); camera.lookAt(0,0,-12);
const renderer=new THREE.WebGLRenderer({antialias:true}); renderer.setPixelRatio(Math.min(devicePixelRatio,1.7)); renderer.setSize(app.clientWidth,app.clientHeight); renderer.shadowMap.enabled=true; app.prepend(renderer.domElement);
scene.add(new THREE.HemisphereLight(0xffffff,0x263344,2)); const sun=new THREE.DirectionalLight(0xffffff,2.4); sun.position.set(-10,25,12); sun.castShadow=true; scene.add(sun);
const ground=new THREE.Mesh(new THREE.PlaneGeometry(200,200),new THREE.MeshStandardMaterial({color:'#b9d9e8'})); ground.rotation.x=-Math.PI/2; ground.position.y=-.12; ground.receiveShadow=true; scene.add(ground);
const road=new THREE.Mesh(new THREE.PlaneGeometry(25,100),new THREE.MeshStandardMaterial({color:'#283744',roughness:1})); road.rotation.x=-Math.PI/2; road.position.set(0,0,-18); road.receiveShadow=true; scene.add(road);
for(const x of [-12.4,12.4]){const edge=new THREE.Mesh(new THREE.BoxGeometry(.18,.04,100),new THREE.MeshStandardMaterial({color:'#dce8ee'}));edge.position.set(x,.03,-18);scene.add(edge)}
for(const x of [-6.25,0,6.25]){for(let z=-62;z<28;z+=7){const dash=new THREE.Mesh(new THREE.BoxGeometry(.12,.035,3.4),new THREE.MeshStandardMaterial({color:'#e4edf1'}));dash.position.set(x,.035,z);scene.add(dash)}}
const loader=new GLTFLoader(), vehicles=[]; let score=0;
function makeFallback(i){const group=new THREE.Group(), paint=['#f1d8ff','#ed4f73','#4db6df','#f4be49','#63c99b','#8899ee'][i%6];const body=new THREE.Mesh(new THREE.BoxGeometry(2.5,.75,4.2),new THREE.MeshStandardMaterial({color:paint,metalness:.18,roughness:.36}));body.position.y=.75;body.castShadow=true;group.add(body);const cabin=new THREE.Mesh(new THREE.BoxGeometry(1.7,.75,1.9),new THREE.MeshStandardMaterial({color:'#a9d8e9',metalness:.25,roughness:.25}));cabin.position.set(0,1.42,-.15);cabin.castShadow=true;group.add(cabin);for(const x of [-1.25,1.25])for(const z of [-1.25,1.25]){const w=new THREE.Mesh(new THREE.CylinderGeometry(.34,.34,.18,16),new THREE.MeshStandardMaterial({color:'#131820'}));w.rotation.z=Math.PI/2;w.position.set(x,.42,z);group.add(w)}return group}
function addModel(model,index,name){const box=new THREE.Box3().setFromObject(model), size=box.getSize(new THREE.Vector3()), center=box.getCenter(new THREE.Vector3()); const largest=Math.max(size.x,size.y,size.z)||1; model.scale.setScalar(4.2/largest); model.position.set(-center.x*model.scale.x,-box.min.y*model.scale.y,-center.z*model.scale.z); model.traverse(o=>{if(o.isMesh){o.castShadow=true;o.receiveShadow=true}}); place(model,index,name)}
function place(object,index,name){const slot=index%8;const lane=[-8.8,-2.9,2.9,8.8][slot%4];const row=Math.floor(slot/4);object.position.x+=lane;object.position.z+=row*9-(index===0?2:0);object.rotation.y=Math.PI;scene.add(object);vehicles.push({object,index,score:0,baseX:object.position.x,baseZ:object.position.z,name});}
(async()=>{try{const response=await fetch('/models/models.json');if(!response.ok)throw Error('models.json HTTP '+response.status);const files=await response.json();if(!Array.isArray(files)||!files.length)throw Error('Model listesi boş');const selected=files.slice(0,12);for(let i=0;i<selected.length;i++){const file=selected[i];try{const gltf=await loader.loadAsync('/models/'+encodeURIComponent(file));addModel(gltf.scene,i,file.replace(/\.glb$/i,'').replaceAll('_',' '))}catch(e){console.error('GLB yüklenemedi:',file,e);place(makeFallback(i),i,file.replace(/\.glb$/i,''))}}count.textContent=`${vehicles.length} araç konvoyda`;status.textContent='';}catch(e){console.error(e);for(let i=0;i<8;i++)place(makeFallback(i),i,i===0?'Gelin arabası':`Konvoy ${i}`);status.textContent='Yerel araç modelleri yüklenemedi; yedek araçlar gösteriliyor';count.textContent=`${vehicles.length} araç konvoyda`}})();
function receive(data){const name=String(data.user||data.name||'Misafir');score+=Number(data.score||data.count||1);let car=vehicles.find(v=>v.name===name);if(!car&&vehicles.length){car=vehicles[vehicles.length-1]}if(car){car.score=score;car.baseZ=Math.min(15,car.baseZ+1.5);}}
let socket;function connect(){try{socket=new WebSocket(`ws://${location.host}/ws`);socket.onmessage=e=>{try{receive(JSON.parse(e.data))}catch{}};socket.onclose=()=>setTimeout(connect,1800)}catch{setTimeout(connect,1800)}}connect();
function animate(t){requestAnimationFrame(animate);const time=t*.001;for(const car of vehicles){car.object.position.z=car.baseZ+Math.sin(time*1.6+car.index)*.18;car.object.position.y=Math.abs(Math.sin(time*2+car.index))*.035;car.object.rotation.y=Math.PI+Math.sin(time+car.index)*.025}renderer.render(scene,camera)}requestAnimationFrame(animate);
function resize(){const w=app.clientWidth,h=app.clientHeight;camera.aspect=w/h;camera.updateProjectionMatrix();renderer.setSize(w,h)}addEventListener('resize',resize);
</script></body></html>
'@ | Set-Content -LiteralPath (Join-Path $publicDir 'index.html') -Encoding UTF8

Write-Host 'NPM paketleri kuruluyor...'
Push-Location $root
try {
  npm install
  if ($LASTEXITCODE -ne 0) { throw 'npm install basarisiz.' }
} finally { Pop-Location }

Remove-Item -LiteralPath $tempRepo -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "Kurulum tamam. Proje: $root"
Write-Host 'Baslatmak icin: cd "$env:USERPROFILE\Desktop\arabalar"; npm start'
Write-Host 'Sonra tarayicida http://127.0.0.1:8765 acin.'
