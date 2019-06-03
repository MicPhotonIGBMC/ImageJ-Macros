macro "Stack to Hyperstack [F1]" { 

setBatchMode(true);

var numChannels;
var numSlices;

dir1=getDirectory("Input");
dir2=getDirectory("Output");
list=getFileList(dir1);
numChannels=getNumber("How many channels", 3);

for (i=0; i<list.length; i++){
	if (endsWith(list[i], ".tif")){
		open(dir1+list[i]);
		nameWoExt=File.nameWithoutExtension;
		getDimensions(width, height, channels, slices, frames);
		numSlices=slices/numChannels;
		run("Stack to Hyperstack...", "order=xyczt(default) channels=numChannels slices=numSlices frames=1 display=Color");
		saveAs("tiff", dir2+nameWoExt+".tif"); 
		run("Close");
	}
}

setBatchMode(false);
}