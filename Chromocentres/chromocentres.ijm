/* May 2019
 * Bertrand Vernay
 * vernayb@igbmc.fr
 *  
 * Detection of chromocentres
 * Data: lif files
 * Dimensions: single channel stack
 * Label: DAPI
 *  
 * Tools used: 
 * 	MorphoLibJ (https://imagej.net/MorphoLibJ)
 * 	Update site	IJPB-plugins 
 *  References/Citation:
 *  Please note that MorphoLibJ is based on a publication. If you use it successfully 
 *  for your research please be so kind to cite our work:
 *  Legland, D.; Arganda-Carreras, I. & Andrey, P. (2016), 
 *  "MorphoLibJ: integrated library and plugins for mathematical 
 *  morphology with ImageJ", Bioinformatics (Oxford Univ Press) 
 *  32(22): 3532-3534, PMID 27412086, doi:10.1093/bioinformatics/btw413 (on Google Scholar).
 *  
 *  3D Object Counter Pluin
 *  Link: http://imagejdocu.tudor.lu/plugin/analysis/3d_object_counter/start
 *  References/Citation:
 *	When using the “3D Object Counter” plugin for publication, please refer to 
 *	S. Bolte & F. P. Cordelières, A guided tour into subcellular colocalization analysis 
 *	in light microscopy, Journal of Microscopy, Volume 224, Issue 3: 213-232, to this 
 *	webpage and of course to ImageJ, as explained in the FAQ section, on ImageJ’s website. 
 *	A copy of your paper being sent to my e-mail address would also be greatly appreciated !
 *  
 */ 


// CHECKING REQUIRED PLUGINS ARE INSTALLED
// MorphoLibJ (https://imagej.net/MorphoLibJ)
// Update site	IJPB-plugins 

macro "Counting Chromocentre [F1]"{
List.setCommands; 
//List.getList; //print all plugins key / value in the log window
if (List.get("Morphological Filters (3D)")!="") { 
	print("MorphoLibJ is installed");
	} 
else {
	exit("MorphoLibJ is not installed");
	//Print instructions in log file how to install MorphoLibJ	 
	print("Plugin MorphoLibJ required (https://imagej.net/MorphoLibJ#Installation)");
	print("In Fiji: Help>Update ...>Manage update sites>IJPB-plugins");
}


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
saveAs("Text", dir1+"log.txt"); 
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
        	print(newImageTitle);
        	File.makeDirectory(dir1+newImageTitle);
        	run("Grays");
        	saveAs("tiff", dir1+File.separator+newImageTitle+File.separator+newImageTitle+".tiff");
        	
        	// IDENTIFY THE NUCLEI IN THE Z-STACK IMAGE & SAVE THE ROIset
        	findNuclei();

			// SAVE INDIVIDUAL STACK IMAGE FOR EACH SEGMENTED NUCLEUS FOR MEASUREMENT WITH REDIRECT TO IMAGE
			extractSingleNucleus(originalID);
        	
        	// HELP FOR SEGMENTATION OF CHROMOCENTRES
        	selectImage(originalID);
        	run("Morphological Filters (3D)", "operation=[White Top Hat] element=Ball x-radius=5 y-radius=5 z-radius=2");
			run("Gaussian Blur...", "sigma=0.10 scaled stack");
			topHatID=getImageID();
			
			// SEGMENT & ANALYSE CHROMOCENTRES
	       	segmentationChromocentre(topHatID);
			run("Close All");
		}
        else {
       		//print(seriesName+ " not processed, not a z-stack");
		}
	}
}


function findNuclei() {
	// Save the detected nuclei in a ROISet file	
	run("Z Project...", "projection=[Max Intensity]");
	mipID=getImageID();
	run("Grays");
	run("Gaussian Blur...", "sigma=2");
	setAutoThreshold("Triangle dark");
	run("Convert to Mask");
	run("Watershed");
	roiManager("reset");	// reset the ROI Manager before adding the next image ROIs
	run("Analyze Particles...", "size=40-5000 exclude add");
	roiManager("save", dir1+File.separator+newImageTitle+File.separator+newImageTitle+".zip");
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
		saveAs("tiff", dir1+File.separator+newImageTitle+File.separator+newImageTitle+"_nucleus_ROI_"+l+".tiff");
		selectImage(duplicateNucleusID);
		close();
	}
}


function segmentationChromocentre(imageIdentity) {	// image id 
	numberROI=roiManager("count");
	for (indexROI = 0; indexROI <numberROI ; indexROI++) {
		selectImage(imageIdentity);
		roiManager("select", indexROI);
		run("Duplicate...", "duplicate");
		duplicateID=getImageID();
		run("Clear Outside", "stack");
		run("Select None");
		// START SEGMENTATION CHROMOCENTRES
		setAutoThreshold("MaxEntropy dark");
		setOption("BlackBackground", true);
		run("Convert to Mask", "method=MaxEntropy background=Dark calculate black");
		// END SEGMENTATION CHROMOCENTRES
		analyseObjects3D(indexROI);
	}
}

function analyseObjects3D(index){
	run("3D OC Options", "  dots_size=5 font_size=10 redirect_to=none");
	run("3D Objects Counter", "threshold=128 slice=5 min.=10 max.=162162 objects surfaces summary");
	// Statistic Table
	//selectWindow("Statistics for "+newImageTitle+"-White Top Hat-1");
	//saveAs("Results", dir1+File.separator+newImageTitle+File.separator+newImageTitle+"_nucleus_ROI_"+indexROI+"statistics.csv");
	//run("Close");

	// Surface map
	selectWindow("Surface map of "+newImageTitle+"-White Top Hat-1");
	saveAs("tiff", dir1+File.separator+newImageTitle+File.separator+newImageTitle+"_nucleus_ROI_"+indexROI+"_surface_map.tiff");
	run("Close");
		
	// Objects Map
	selectWindow("Objects map of "+newImageTitle+"-White Top Hat-1");
	saveAs("tiff", dir1+File.separator+newImageTitle+File.separator+newImageTitle+"_nucleus_ROI_"+indexROI+"_objects_map.tiff");
	run("Close");
}

}