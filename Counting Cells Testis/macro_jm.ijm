run ("Revert");
cols = newArray("red","green","blue","cyan","magenta","yellow");
run ("Remove Overlay");
run ("Select None");
run("Make Composite");
setSlice(2);
run("Duplicate...", "duplicate channels=2");
run("Median...", "radius=20");
setAutoThreshold("Intermodes dark");
setOption("BlackBackground", true);
run("Convert to Mask");
run("Watershed");
run("Analyze Particles...", "size=2200-Infinity clear add");
close();
snapshot();
roiManager("Show None");
roiManager("Show All");
n = roiManager('count');
for (i=0; i<n; i++) {
   roiManager('select', i);
	run("Gaussian Blur...", "sigma=3");
	run("Find Maxima...", "prominence=1 light output=[Point Selection]");
	run("Properties... ", "  stroke="+cols[i%cols.length]+" point=Circle size=[Extra Large] show");
	run ("Add Selection...");
}
reset;