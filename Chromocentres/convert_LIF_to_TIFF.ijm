// INITIALISE MACRO
print("\\Clear");
roiManager("reset");
run("Bio-Formats Macro Extensions");	//enable macro functions for Bio-formats Plugin
setBatchMode(true);

//Close Results table
if (isOpen("Results")) {
	selectWindow("Results");
	run("Close");
} 

//Close Images
while (nImages > 0){
	close();
}

//Reset the ROImanager
roiManager("reset");


// INPUT/OUTPUT
dir1 = getDirectory("Select the source directory containing the lif files for conversion to tiff format");
dir2 = getDirectory("Select the target directory to save the tiff files");
list = getFileList(dir1);


// PROCESS LIF FILES
for (i = 0; i < list.length; i++) {
	if (endsWith(list[i], ".lif")){
		indexDot=indexOf(list[i], ".lif");
		fileNameWithoutExtension=substring(list[i], 0, indexDot);
		processFile(list[i]);
	}
}


selectWindow("Log");	// The log contain the count results of objects per nucleus
saveAs("Text", dir2+"log.txt"); 
roiManager("reset");
run("Close All");
setBatchMode(false);
print("DONE");


/*
 * FUNCTIONS
 * 
*/


// Requires run("Bio-Formats Macro Extensions");
function processFile(fileToProcess){
	path=dir1+fileToProcess;
	Ext.setId(path);
	Ext.getCurrentFile(fileToProcess);
	Ext.getSeriesCount(seriesCount); // this gets the number of series
	print("Processing the file = " + fileToProcess);
	// see http://imagej.1557.x6.nabble.com/multiple-series-with-bioformats-importer-td5003491.html
	for (j=0; j<seriesCount; j++) {
        Ext.setSeries(j);
        Ext.getSeriesName(seriesName);
        //Ext.getSizeZ(sizeZ);
        Ext.getSizeC(sizeC);	// Channel number check
		run("Bio-Formats Importer", "open=&path color_mode=Default view=Hyperstack stack_order=XYCZT series_"+j+1); 
		originalID=getImageID();
		originalTitle=getTitle();
		newImageTitle = fileNameWithoutExtension + "_" + seriesName;
		print(newImageTitle);
		//File.makeDirectory(dir1+newImageTitle);
		run("Grays");
		saveAs("tiff", dir2+newImageTitle+".tiff");
	}
}
