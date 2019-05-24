setBatchMode(true); 
a=getTitle(); 
run("RGB Color"); 
div=nSlices; 
for(i=0;i<div;i++){ 
	selectWindow(a); 
	setSlice(i+1); 
	run("Duplicate...", "title=_b"); 
	run("HSB Stack"); 
	setSlice(1); 
	run("Set...", "value="+((256/div)*i)+" slice"); 
	setSlice(2); 
	run("Set...", "value=255 slice"); 
	run("RGB Color"); 
	imageCalculator("Copy", a ,"_b"); 
	selectWindow("_b"); 
	close(); 
} 
setBatchMode(false); 