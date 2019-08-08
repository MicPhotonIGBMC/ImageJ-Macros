/* July 2019 - August 2019
 * Initiated by:
 * Bertrand Vernay
 * vernayb@igbmc.fr
 * Continued by:
 * Marcel Boeglin
 * boeglin@igbmc.fr
 * For: Michail AMOIRIDIS, 
 * Soutgoglou Team: http://www.igbmc.fr/research/department/1/team/28/ 
 *  
 * Extraction of Cell Nuclei
 * Data: lif files (Leica SP8-X)
 * Dimensions: 4 channels stack
 * Labels: 
 * 	 channel 1 = H3Ser10 (AF647) : marker G2
 *   channel 2 = Edu (AF594): DNA synthesis
 *   channel 3 = Top2a (AF488)
 *   channel 4 = DAPI
 */ 

saveSettings();//save user options
run("Appearance...", "  menu=15 gui=1 16-bit=Automatic");//to avoid inverting LUT
requires("1.52p");

// INITIALISE MACRO
print("\\Clear");
run("Bio-Formats Macro Extensions");//enable macro functions for Bio-formats Plugin. See
//http://imagej.1557.x6.nabble.com/multiple-series-with-bioformats-importer-td5003491.html
setBatchMode(true);

//Close Results table
if (isOpen("Results")) {
	selectWindow("Results");
	run("Close");
} 

//Close all images
while (nImages>0) close();
//Remove all ROIs from ROI Manager
roiManager("reset");

//DECLARE VARIABLES
var originalTitle;
var fileNameWithoutExtension;
var seriesName;
var tempNucleusTitle;
var indexROI;

// INPUT/OUTPUT
dir1 = getDirectory("Select the directory containing the lif files to analyse");
dir2 = dir1;
fs = File.separator;
if (endsWith(dir2, fs)) dir2 = substring(dir2, 0, lastIndexOf(dir2, fs));
dir2 += "_extractedNuclei"+fs;
if (!File.exists(dir2)) File.makeDirectory(dir2);

//Process LIF files in dir1
list = getFileList(dir1);
for (i=0; i<list.length; i++) {
	print("list["+i+"] = "+list[i]);
	if (!endsWith(list[i], ".lif")) continue;
	indexDot=indexOf(list[i], ".lif");
	fileNameWithoutExtension=substring(list[i], 0, indexDot);
	print(fileNameWithoutExtension);
	processFile(list[i]);
}

roiManager("reset");
run("Close All");
setBatchMode(false);
restoreSettings();//restore user options
print("DONE");


/*
 * FUNCTIONS
 */


/** Processes lif files
 * Requires run("Bio-Formats Macro Extensions") */
function processFile(fname) {
	path=dir1+fname;
	Ext.setId(path);
	Ext.getCurrentFile(fname);
	Ext.getSeriesCount(seriesCount);//returns 'seriesCount' (number of series in lif)
	print("Processing the file = " + fname);
	//fs = File.separator;
	for (j=0; j<seriesCount; j++) {
        Ext.setSeries(j);
        Ext.getSeriesName(seriesName);
        Ext.getSizeZ(sizeZ);
        if (sizeZ<2) continue;
		run("Bio-Formats Importer",
			"open=&path color_mode=Default view=Hyperstack stack_order=XYCZT series_"+j+1); 
        id=getImageID();
        title = fileNameWithoutExtension + "_" + seriesName;
        //print("Image name: "+title);
        title = replace(title,"/","_");//prevent error with Mark and find files
        //print("After replacement title = "+title);
        	
        //IDENTIFY NUCLEI IN Z-STACK, ADD ROIs TO OVERLAY, SAVE IMAGE TO INPUT FOLDER
        findNuclei(title);

		//SAVE INDIVIDUAL IMAGE FOR EACH DETECTED NUCLEUS
		//FOR MEASUREMENT WITH REDIRECT TO IMAGE
		//INDIVIDUAL ROIs ARE ALSO SAVED IN INDIVIDUAL IMAGES
		//extractSingleNuclei(id, title);//Done in ExtractRoisFromOverlay_
		run("Close All");
	}
}

/** Adds detected nuclei as ROIs to overlay of current image and saves it to input folder
 * @title the title of the image in which nuclei are to be detected */
function findNuclei(title) {
	getPixelSize(unit, pixelWidth, pixelHeight);//unit assumed to be micron
	radiusPixels = 50;
	if (unit=="microns" || unit=="µm" || unit=="µ")
		radiusPixels = 20 / pixelWidth;//to subtract background with a radius of 20 microns
	radius = radiusPixels * pixelWidth;
	print("radiusPixels = "+radiusPixels);
	print("radius = "+radius+" "+unit);
	run("Duplicate...", "duplicate channels=4");
	run("Z Project...", "projection=[Median]");//Average Intensity & Max Intensity less good
	run("Gaussian Blur...", "sigma=1 stack");
	run("Subtract Background...", "rolling="+radiusPixels+" stack");//use microns
	setAutoThreshold("Li dark");
	run("Convert to Mask");
	run("Watershed", "slice");
	roiManager("reset");//empty ROI Manager
	//Analyze Particles creates ROIs from current image and adds them to ROI Manager
	run("Analyze Particles...", "size=36-3600 exclude include add");//size in square microns
	close();
	close();
	roiManager("Show All without labels");
	saveAs("tiff", dir1+title+".tif");//ROIs from ROI Manager are saved as Overlay
	//To retrieve the rois, use run("To ROI Manager");
}

/** Extracts detected nuclei from image with ID 'id' and title 'title'
 * @id: the ID of image from which extract nuclei 
 * @title: the title of image from which extract nuclei */
function extractSingleNuclei(id, title) {
	run("Remove Overlay");
	for (i=0; i<roiManager("count"); i++) {
		selectImage(id);
		roiManager("select", i);
		run("Duplicate...", "duplicate");
		//run("Clear Outside", "stack");
		//run("Select None");
		run("Grays");
		saveAs("tiff", dir2+title+"_Nucleus"+i+".tif");
		close();
	}
}