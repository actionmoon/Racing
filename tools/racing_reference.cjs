// Execute the original Yo and Ho methods, extracted unchanged from the capture.
const fs = require('fs');
const source = fs.readFileSync('docs/reference/qqfeiche3d/readable-script.js', 'utf8');
const configStart = source.indexOf('  var qn = {');
const vehicleEnd = source.indexOf('  function kc(', configStart);
const trackStart = source.indexOf('      sample(t, e = this._tmp)');
const trackEnd = source.indexOf('      surfaceY(', trackStart);
const helpers = source.slice(source.indexOf('  var he = '), source.indexOf('  function bn('));
const api = new Function(helpers + source.slice(configStart, vehicleEnd) +
  '\nvar $o = {}; class ReferenceTrack {' + source.slice(trackStart, trackEnd) +
  '}; return {Yo,ReferenceTrack};')();
const requests = JSON.parse(fs.readFileSync(0, 'utf8'));
const result = requests.map(request => {
  const data = request.track || JSON.parse(fs.readFileSync('docs/reference/qqfeiche3d/tracks/city.json','utf8'));
  const track = Object.assign(new api.ReferenceTrack(), data.track.arrays, {
    N:data.track.samples,length:data.track.length,ds:data.track.sampleDistance,
    halfW:data.track.halfWidth,boostPads:data.boostPads,_tmp:{}
  });
  const car = new api.Yo(track, null, 'reference');
  car.reset(request.distance || 0, request.lateral || 0);
  Object.assign(car, request.initial || {});
  return request.frames.map(frame => {
    if (frame.action === 'start') {car.startBoost=1.4;car.s=Math.max(car.s,16);}
    if (frame.action === 'endDrift') car.endDrift();
    car.update(1/120, frame.input || {}, true, false);
    const state = {};
    for (const [k,v] of Object.entries(car))
      if (['number','boolean','string'].includes(typeof v) && k !== 'name') state[k]=v;
    state.events=car.events.splice(0);
    return state;
  });
});
process.stdout.write(JSON.stringify(result));
