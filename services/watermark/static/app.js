'use strict';
const $ = id => document.getElementById(id);
let ready = false, busy = false, activeJob = null;
const setButtons = () => ['mark-submit','check-submit'].forEach(id => { $(id).disabled = !ready || busy; });
async function health() {
  try { const response = await fetch('/api/health'); const data = await response.json(); ready = data.ready === true; $('engine-status').textContent = data.message; $('engine-status').classList.toggle('unavailable', !ready); }
  catch { ready = false; $('engine-status').textContent = 'The local server is unavailable. Start it with the launcher, then refresh.'; }
  setButtons();
}
const tabs = [$('mark-tab'), $('check-tab')];
function tab(index) { tabs.forEach((button,i) => { button.setAttribute('aria-selected', String(index===i)); button.tabIndex = index===i ? 0 : -1; $(i ? 'check-panel' : 'mark-panel').hidden = index!==i; }); }
tabs.forEach((button,index) => { button.addEventListener('click', () => tab(index)); button.addEventListener('keydown', e => { if (['ArrowLeft','ArrowRight','Home','End'].includes(e.key)) { e.preventDefault(); const next = e.key==='Home' ? 0 : e.key==='End' ? 1 : 1-index; tab(next); tabs[next].focus(); } }); });
['mark','check'].forEach(prefix => {
  const input = $(prefix+'-file'), zone = input.closest('.dropzone');
  const update = () => { $(prefix+'-file-name').textContent = input.files[0] ? input.files[0].name : 'or drop it here'; };
  input.addEventListener('change', update);
  zone.addEventListener('dragover', e => { e.preventDefault(); zone.classList.add('drag'); });
  zone.addEventListener('dragleave', () => zone.classList.remove('drag'));
  zone.addEventListener('drop', e => { e.preventDefault(); zone.classList.remove('drag'); if (e.dataTransfer.files.length) { const transfer = new DataTransfer(); transfer.items.add(e.dataTransfer.files[0]); input.files = transfer.files; update(); } });
  $(prefix+'-form').addEventListener('submit', e => { e.preventDefault(); submit(prefix); });
});
function showError(message) { $('error').textContent = message; $('error').hidden = false; $('result').setAttribute('aria-busy','false'); $('progress-area').hidden=true; busy=false; setButtons(); }
function upload(url, data) { return new Promise((resolve,reject) => {
  const xhr = new XMLHttpRequest(); xhr.open('POST', url); xhr.timeout=130000;
  xhr.upload.onprogress = e => { if(e.lengthComputable) { $('progress').max=e.total; $('progress').value=e.loaded; $('phase').textContent=`Uploading · ${Math.round(e.loaded/e.total*100)}%`; } };
  xhr.onload = () => { try { const value=JSON.parse(xhr.responseText); if(xhr.status!==202) reject(new Error(value.error||'The upload was not accepted.')); else resolve(value); } catch { reject(new Error('The local server returned an unreadable response.')); } };
  xhr.onerror=()=>reject(new Error('Upload failed. Check that the local server is running.'));
  xhr.ontimeout=()=>reject(new Error('The upload took too long. Try a smaller video.'));
  xhr.send(data);
}); }
async function submit(prefix) {
  if(busy) return;
  const file=$(prefix+'-file').files[0];
  if(!file) return;
  if(file.size>100*1024*1024) { showError('Choose a video under 100 MiB.'); return; }
  busy=true; setButtons(); $('error').hidden=true; $('finished').hidden=true; $('empty-art').hidden=true; $('progress-area').hidden=false; $('result').setAttribute('aria-busy','true'); $('progress').removeAttribute('value'); $('phase').textContent='Starting upload…';
  $('result-title').textContent=prefix==='mark' ? 'Marking your video' : 'Checking your video'; $('result-description').textContent='The file stays on this computer.';
  try { const job=await upload(prefix==='mark'?'/api/jobs':'/api/verify',new FormData($(prefix+'-form'))); activeJob=job.job_id; $('progress').removeAttribute('value'); await poll(job.job_id); }
  catch(error) { showError(error.message); }
}
async function poll(id) {
  while(activeJob===id) {
    const response=await fetch('/api/jobs/'+encodeURIComponent(id)); const job=await response.json();
    if(!response.ok) throw new Error(job.error||'This job is no longer available.');
    $('phase').textContent=job.message;
    if(job.state==='error') throw new Error(job.message);
    if(job.state==='complete'||job.state==='denied') { finish(job); return; }
    await new Promise(resolve=>setTimeout(resolve,1200));
  }
}
function finish(job) {
  busy=false; setButtons(); $('result').setAttribute('aria-busy','false'); $('progress-area').hidden=true; $('finished').hidden=false; $('downloads').replaceChildren();
  const blocked=job.state==='denied', marking=job.operation==='embed'&&!blocked, result=job.result||{}, detection=blocked?(result.detection||{}):result;
  $('result-title').textContent=blocked?'Re-marking refused':marking?'Your marked video is ready':'Your check is complete'; $('result-description').textContent=blocked?job.message:marking?'The restrictions were recovered from the finished video. Keep the MP4 and manifest together.':'These instructions come from the supported pixel payload. They do not verify ownership.';
  $('preview').hidden=!marking; if(marking) $('preview').src=job.downloads.video; else { $('preview').removeAttribute('src'); $('preview').load(); }
  $('manifest-reminder').hidden=!marking; $('verdict').hidden=marking;
  if(!marking) { const found=detection.valid===true; const matched=detection.matches_expected; $('verdict').textContent=!found?'No supported mark recovered':matched===false?'A different asset ID was found':matched===true?'The asset ID matches':'A pixel identifier was found'; $('verdict').classList.toggle('uncertain',!found||matched===false); }
  const permission=result.permission||{}, denied=permission.decision==='deny';
  const restrictions={copying:'Do not copy',redistribution:'Do not redistribute',ai_training:'Do not train AI on this',ai_use:'Do not use with AI'};
  $('policy-title').textContent=denied?'Embedded restrictions recovered':'Permission unknown';
  $('policy-instruction').textContent=denied?(permission.restrictions||[]).map(key=>restrictions[key]||key).join(' · '):'No permission to copy or use with AI was established.';
  $('policy-context').textContent=blocked?'This app honored the recovered restriction. No new video was created.':denied?'A compatible connected app can read this signal and refuse the restricted action.':detection.payload_version==='TBW1'?'This older mark carries an ID without use instructions. Obtain separate permission before proceeding.':'A missing, unreadable or unspecified instruction does not grant permission. Obtain separate permission before proceeding.';
  $('result-id').value=marking?job.asset_id:(detection.recovered_asset_id||'No identifier recovered'); $('copy-id').disabled=!marking&&!detection.recovered_asset_id;
  for(const [kind,url] of Object.entries(job.downloads||{})) { const a=document.createElement('a'); a.href=url; a.download=kind==='video'?'marked.mp4':kind+'.json'; a.className=kind; a.textContent={video:'Download MP4 ↓',manifest:'Save manifest ↓',report:'Save check report ↓'}[kind]; $('downloads').append(a); }
  $('report').textContent=JSON.stringify(result,null,2); $('expiry').textContent='These local files expire '+new Date(job.expires_at*1000).toLocaleString()+'.';
  if(marking) $('asset-id').value=job.asset_id;
}
$('copy-id').addEventListener('click',async()=>{ try { await navigator.clipboard.writeText($('result-id').value); $('copy-id').textContent='Copied'; setTimeout(()=>{$('copy-id').textContent='Copy';},1500); } catch { $('result-id').select(); } });
$('delete-job').addEventListener('click',async()=>{ if(!activeJob) return; try { const response=await fetch('/api/jobs/'+encodeURIComponent(activeJob),{method:'DELETE'}); const data=await response.json(); if(!response.ok) throw new Error(data.error); $('preview').removeAttribute('src'); $('preview').load(); $('finished').hidden=true; $('result-title').textContent='Local files removed'; $('result-description').textContent='Any copies you downloaded stay with you.'; activeJob=null; } catch(error) { showError(error.message); } });
health(); setInterval(()=>{if(!busy) health();},30000);
