/*********

This example shows remapping an Influx's out values with an array of envelopes,
creating an 'uneven terrain' in possibility space; in effect,
linear changes in control inputs will cause output parameters
to change at different rates in different zones of the space.

*********/

// didactic first example, single param remapped by envelope

q = q ? ();
// simple random envelope: goes from -1 left, 0 center, 1 right,
// random breakpoints in between

q.makeEnv = { |q, numSteps = 8|
	var numTimes = numSteps.max(2).round(2).asInteger;
	var levels = (numTimes + 1).collect { 1.0.rand2 };
	// bit boring to have them regular
	var times = (1/numTimes).dup(numTimes);
	var curves = numTimes.collect { 3.0.rand2 };
	// put in fixed values
	levels[0] = -1;
	levels[numTimes div: 2] = 0;
	levels[numTimes] = 1;
	Env(levels, times, curves);
};

e = q.makeEnv; e.plot;


///////// bit more subtle: control degree of value randomness and curvature
q.makeEnv = { |q, numSteps = 8, rand = 1.0, maxCurve = 3.0|
	var numTimes = numSteps.max(2).round(2).asInteger;
	var levels = (numTimes + 1).collect { |i| 1.0.rand2.blend( (i / numTimes).unibi, 1-rand) };
	// bit boring to have them regular
	var times = (1/numTimes).dup(numTimes);
	var curves = numTimes.collect { maxCurve.rand2 };
	// put in fixed values
	levels[0] = -1;
	levels[numTimes div: 2] = 0;
	levels[numTimes] = 1;
	Env(levels, times, curves);
};

/*
q.makeEnv(8, 0, 0).plot; // no random deviation -> straight line
q.makeEnv(8, 0, 3.0).plot; // all points on a line, just curves
q.makeEnv(8, 0, 8.0).plot; // strong curves

q.makeEnv(8, 1.0, 0).plot; // big rand values allowed, no curves
q.makeEnv(8, 0.5, 0).plot; // smaller rand values
q.makeEnv(8, 0.2, 0).plot; // small rand values
q.makeEnv(8, 0.2, 3.0).plot; // small rand values plus curves
q.makeEnv(12, 0.5, 3.0).plot; // more steps
*/

e = q.makeEnv;

//////////// simplify - single param remap
w = Window("remap by env", Rect(400, 400, 300, 300)).front; w.addFlowLayout;
Plotter("env", Rect(0, 0, 300, 200), w).value = e.discretize;
x = EZSlider(w, 300@30, \ctlr, \pan, { |sl| y.value = e.at(sl.value.biuni).postln });
y = EZSlider(w, 300@30, \mapped, \pan);

Ndef(\a, { RLPF.ar(PinkNoise.ar([0.2, 0.2]), \freq.kr(600), 0.1) }).play;

x.action = { |sl|
	var remapped = e.at(sl.value.biuni).postln;
	y.value = remapped;
	Ndef(\a).setUni(\freq, remapped.biuni);
};

/////////////////////

/// example with influx and sound with 8 params:
(
Ndef(\a).addSpec(\intv, [-24, 24]);
Ndef(\a).addSpec(\timescale, [0.01, 10, \exp]);
Ndef(\a).addSpec(\curve, [-10, 10]);
Ndef(\a).addSpec(\ffreq, \freq);
Ndef(\a).addSpec(\loopnode, [0, 12]);

Ndef(\a).addSpec(\dens, [10, 1000]);
Ndef(\a).addSpec(\resfreq, \freq);
Ndef(\a).addSpec(\ringtime, [0.01, 1, \exp]);

Ndef(\a, { |freq=250, intv=19, timescale=1, curve=0, loopnode=0, dens = 10, resfreq = 500, ringtime = 0.01|
    var n = 15;
    var env = EnvGen.kr(
        Env({ 1.0.rand2 }!(n+1), {1.0.rand}!n, curve, releaseNode: n-1, loopNode: loopnode.min(n-3)),
        timeScale: timescale);
    var pitch = (env * [1, 0.33, -1] * intv).midiratio * freq;
    var form = Formant.ar(pitch, pitch.rotate(1) * 1.6, pitch.rotate(2) * 2.6);

    var dusty = Ringz.ar(Dust.ar(dens!3), resfreq * LFNoise0.kr([3, 5, 7], 0.5, 1), ringtime) * ((dens ** -0.5) * (ringtime ** -0.3)) ;
    Splay.ar(form * dusty);

}).play(vol: 0.25);
Ndef(\a).gui.moveTo(0, 50).skipjack.dt_(0.05);
);

(
///////// make an influx and guis for it
a = Influx(2, 8);

// make plot/edit views for weights:
d = InfluxIOWGui(a); d.skipjack.dt = 0.05;
k = InfluxKtlGui(a).moveTo(0, 800);

// connect the influx action to the Ndef
a.attachMapped(Ndef(\a));
)
// -> center is all params in center
//    x 1 y 0: is shape of x weights and vice versa

// try adding tanh compression to influx out:
// -> params dont quite hit the edges
a.addProc(\base, { |val| val.tanh } );




////// NOW try to apply remap by semi-predictable envs:
////// -1, 0, 1 values remain the same
(
~envs = 8.collect { q.makeEnv };
// func to plot them
q.plotenvs = { |q, envs|
	envs.collect (_.discretize).flop.flat.plot("envs", Rect(500, 0, 300, 800), false, 8, -1, 1);
};
// q.plotenvs(~envs);

// make envs with just 4 steps - every param moves faster in some areas and slower in others
a.addHalo('envs', a.weights.collect { q.makeEnv(4) });
// see the current envs:  3 turning points possible
q.plotenvs(a.getHalo(\envs));

// and turn on envelope remapping:
a.addProc(\base, { |val, i|
	a.getHalo(\envs)[i].at(val.tanh.biuni);
} );
)

// 8 steps - far more turning points of parameters in each envelope
// -> we can access a lot more variety in the possibility space!
a.addHalo('envs', a.weights.collect { q.makeEnv(8) });
q.plotenvs(a.getHalo(\envs));

// down at 2 steps, random reshaping disappears,
// back to almost normal influx behavior, except for slight curves!
a.addHalo('envs', a.weights.collect { q.makeEnv(2) });
q.plotenvs(a.getHalo(\envs));

// maybe too many steps already?
// supernervous behaviour, fast change slopes everywhere
a.addHalo('envs', a.weights.collect { q.makeEnv(12) });
q.plotenvs(a.getHalo(\envs));

