setBatchMode(true);

List.setCommands;
if (List.get("PluginName")!="LabelMap to ROI Manager (2D)") {
	print("Please activate the SCF MPI CBG update site");
} 

roiManager("reset");

dir1 = getDirectory("Source");
dir2 = getDirectory("Target");
list = getFileList(dir1);
	
for (i=0; i<list.length; i++){
	path = dir1 + list[i];
	if (endsWith(list[i], "_DAPI.tif")){
		open(path);
		tempName = File.nameWithoutExtension;
		roiManager("reset");
		extracLabels(tempName);
		
	}
}

function extracLabels(binaryName){
	labelsID = getImageID();
	getDimensions(width, height, channels, slices, frames);
	newImage("binary", "8-bit black", width, height, 1);
	binaryID = getImageID();
	selectImage(labelsID);
	run("LabelMap to ROI Manager (2D)");
	nROIs = roiManager("count");
	for (i = 0; i < nROIs; i++){
		selectImage(binaryID);
		roiManager("Select", i);
		run("Fill", "slice");
		run("Make Band...", "band=1");
		run("Clear", "slice");
	}
	selectImage(binaryID);
	outPath = dir2 + binaryName+"_binary.tif";
	saveAs("tiff", outPath);
	run("Close All");
}

setBatchMode(true);