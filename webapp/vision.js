/* On-device inference only: camera frames never leave the browser.
 * Libraries/model weights download on first use. No embedded credentials. */
window.jaryq = (() => {
  let busy=false, detector, worker, activeStream, generation=0;
  function cancel(){generation++;activeStream?.getTracks().forEach(t=>t.stop());activeStream=null;}
  const loaded=new Map();
  function script(url){
    if(!loaded.has(url))loaded.set(url,new Promise((resolve,reject)=>{
      const s=document.createElement('script');s.src=url;s.onload=resolve;s.onerror=()=>{loaded.delete(url);reject(new Error('model_download'));};document.head.appendChild(s);
    }));return loaded.get(url);
  }
  async function frame(){
    if(!navigator.mediaDevices?.getUserMedia)throw new Error('camera_unsupported');
    const token=generation;
    const stream=await navigator.mediaDevices.getUserMedia({video:{facingMode:{ideal:'environment'},width:{ideal:1280},height:{ideal:960}},audio:false});
    if(token!==generation){stream.getTracks().forEach(t=>t.stop());throw new Error('cancelled');}activeStream=stream;
    const video=document.createElement('video');video.style.cssText='position:fixed;left:-10000px;width:1px;height:1px';video.setAttribute('aria-hidden','true');document.body.append(video);video.muted=true;video.playsInline=true;video.srcObject=stream;
    try{
      await video.play();await new Promise(r=>setTimeout(r,650));
      if(token!==generation)throw new Error('cancelled');
      const canvas=document.createElement('canvas');canvas.width=video.videoWidth;canvas.height=video.videoHeight;
      if(!canvas.width)throw new Error('no_frame');
      const ctx=canvas.getContext('2d',{willReadFrequently:true});ctx.drawImage(video,0,0);
      const tiny=document.createElement('canvas');tiny.width=32;tiny.height=32;const c=tiny.getContext('2d');c.drawImage(canvas,0,0,32,32);const pixels=c.getImageData(0,0,32,32).data;
      let light=0;for(let i=0;i<pixels.length;i+=4)light+=pixels[i]*.2126+pixels[i+1]*.7152+pixels[i+2]*.0722;
      if(light/1024<30)throw new Error('too_dark');return canvas;
    }finally{stream.getTracks().forEach(t=>t.stop());video.srcObject=null;video.remove();if(activeStream===stream)activeStream=null;}
  }
  async function capture(mode,language){
    if(busy)return JSON.stringify({error:'busy'});busy=true;const token=generation;
    try{
      const canvas=await frame();if(token!==generation)throw new Error('cancelled');
      if(mode==='text'){
        await script('https://cdn.jsdelivr.net/npm/tesseract.js@6.0.1/dist/tesseract.min.js');
        worker??=await Tesseract.createWorker('rus+kaz',1,{logger:()=>{}});
        // Tesseract.js 6 returns per-word confidence only when blocks are requested.
        const {data}=await worker.recognize(canvas,{},{blocks:true});
        const words=(data.blocks||[]).flatMap(b=>b.paragraphs).flatMap(p=>p.lines).flatMap(l=>l.words).filter(w=>(w.text||'').trim());
        // One unsure word can be a negation or a dosage digit, so an average
        // score is not enough: reject the whole reading instead of trimming it.
        const sure=Number.isFinite(data.confidence)&&data.confidence>=65&&words.length>0&&words.every(w=>Number.isFinite(w.confidence)&&w.confidence>=60);
        const text=sure?data.text.trim():'';
        return JSON.stringify({text,confidence:sure?data.confidence/100:0});
      }
      await script('https://cdn.jsdelivr.net/npm/@tensorflow/tfjs@4.22.0/dist/tf.min.js');
      await script('https://cdn.jsdelivr.net/npm/@tensorflow-models/coco-ssd@2.2.3/dist/coco-ssd.min.js');
      detector??=await cocoSsd.load({base:'lite_mobilenet_v2'});
      const objects=(await detector.detect(canvas,8,.65)).filter(o=>o.score>=.65);
      const aliases={'dining table':'table','cell phone':'mobile phone','tv':'television','potted plant':'plant','motorbike':'motorcycle','sofa':'couch'};
      return JSON.stringify({labels:objects.slice(0,4).map(o=>({label:aliases[o.class]||o.class,confidence:o.score})),obstacles:objects.map(o=>({zone:Math.min(2,Math.floor((o.bbox[0]+o.bbox[2]/2)/canvas.width*3)),area:o.bbox[2]*o.bbox[3]/(canvas.width*canvas.height)}))});
    }catch(error){return JSON.stringify({error:error?.message||'recognition_failed'});}finally{busy=false;}
  }
  return {capture,cancel};
})();
