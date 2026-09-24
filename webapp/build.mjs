import {mkdir,copyFile,cp} from 'node:fs/promises';
await mkdir('dist',{recursive:true});
for(const file of ['index.html','style.css','app.js','navigation.js','address.js','vision.js','labels.json','manifest.webmanifest','icon.svg','sw.js'])await copyFile(file,`dist/${file}`);
