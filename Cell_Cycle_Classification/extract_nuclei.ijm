/* July 2019
 * Bertrand Vernay
 * vernayb@igbmc.fr
 *  
 * For: Michail AMOIRIDIS (Soutgoglou Team: http://www.igbmc.fr/research/department/1/team/28/) 
 *  
 * Extraction of Cell Nuclei
 * Data: lif files (Leica SP8-X)
 * Dimensions: 4 channels stack
 * Labels: 
 * 	 channel 1 = H3Ser10 (AF647) : marker G2
 *   channel 2 = Edu (AF594): DNA synthesis
 *   channel 3 = Top2a (AF488)
 *   channel 4 = DAPI
 * 
 * Tools used: 
 *  
 *  
 */ 

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


// INITIALISE VARIABLES
var originalTitle;
var fileNameWithoutExtension;
var seriesName;
var tempNucleusTitle;
var indexROI;


// INPUT/OUTPUT
dir1 = getDirectory("Select the directory containing the lif files to analyse");
dir2 = getDirectory("Select the directory to save the extracted nuclei");
list = getFileList(dir1);


// PROCESS LIF FILES
for (i = 0; i < list.length; i++) {
	if (endsWith(list[i], ".lif")){
		indexDot=indexOf(list[i], ".lif");
		fileNameWithoutExtension=substring(list[i], 0, indexDot);
		print(fileNameWithoutExtension);
		processFile(list[i]);
	}
}

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
        Ext.getSizeZ(sizeZ);
        if (sizeZ > 1){
			run("Bio-Formats Importer", "open=&path color_mode=Default view=Hyperstack stack_order=XYCZT series_"+j+1); 
        	originalID=getImageID();
        	originalTitle=getTitle();
        	newImageTitle = fileNameWithoutExtension + "_" + seriesName;
        	//print("Image name = "+newImageTitle);
        	newImageTitle=replace(newImageTitle,"/","_");	//prevent error with Mark and find files
        	//print("After replacement = "+newImageTitle);
        	File.makeDirectory(dir1+newImageTitle);
        	File.makeDirectory(dir1+newImageTitle+File.separator+"ROIs");
        	//run("Grays");
        	saveAs("tiff", dir1+File.separator+newImageTitle+File.separator+"ROIs"+File.separator+newImageTitle+".tiff");
        	
        	// IDENTIFY THE NUCLEI IN THE Z-STACK IMAGE & SAVE THE ROIset
        	findNuclei();

			// SAVE INDIVIDUAL STACK IMAGE FOR EACH SEGMENTED NUCLEUS FOR MEASUREMENT WITH REDIRECT TO IMAGE
			extractSingleNucleus(originalID);
			run("Close All");
		}
	}
}


function findNuclei() {
	// Save the detected nuclei in a ROISet file	
	run("Z Project...", "projection=[Max Intensity]");
	mipID=getImageID();
	//run("Grays");
	run("Gaussian Blur...", "sigma=2 stack");
	Stack.setChannel(4);
	run("Convert to Mask", "method=Li background=Dark black");
	Stack.setChannel(4);
	run("Watershed", "slice");
	roiManager("reset");	// reset the ROI Manager before adding the next image ROIs
	run("Analyze Particles...", "size=40-5000 exclude add");
	roiManager("save", dir1+File.separator+newImageTitle+File.separator+"ROIs"+File.separator+newImageTitle+".zip");
	selectImage(mipID);
	close();
}


function extractSingleNucleus(imageIdentity) {	// image id 
	// Extract stack of each identified nucleus
	numberROI=roiManager("count");
	for (l = 0; l <numberROI ; l++) {
		selectImage(imageIdentity);
		roiManager("select", l);
		run("Duplicate...", "duplicate");
		duplicateNucleusID=getImageID();
		run("Clear Outside", "stack");
		run("Select None");
		run("Grays");
		saveAs("tiff", dir2+newImageTitle+"_nucleus_ROI_"+l+".tiff");
		selectImage(duplicateNucleusID);
		close();
	}
}