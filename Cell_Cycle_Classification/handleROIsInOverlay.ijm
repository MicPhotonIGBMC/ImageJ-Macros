/* August 2019
 * Marcel Boeglin
 * boeglin@igbmc.fr
 * For: Michail AMOIRIDIS, 
 * Soutgoglou Team: http://www.igbmc.fr/research/department/1/team/28/ 
 *  
 * Deletion of bad ROIs (containing several nuclei or bad ones)
 * Data: tiff files with nuclei ROIs in overlay
 * Dimensions: 4 channel stack
 * Labels: 
 * 	 channel 1 = H3Ser10 (AF647) : marker G2
 *   channel 2 = Edu (AF594): DNA synthesis
 *   channel 3 = Top2a (AF488)
 *   channel 4 = DAPI
 */ 


saveSettings();//save user options
run("Appearance...", "  menu=15 gui=1 16-bit=Automatic");//to avoid inverting LUT
requires("1.52p");

currentTool = IJ.getToolName();
//setTool("multipoint");
setTool("point");

// INITIALISE MACRO
print("\\Clear");

//Close all images
while (nImages>0) close();
//Remove all ROIs from ROI Manager
//roiManager("reset");

//DECLARE VARIABLES
var originalTitle;
var fileNameWithoutExtension;
var seriesName;
var tempNucleusTitle;
var indexROI;

// INPUT/OUTPUT
dir1 = getDirectory("Select the directory containing the tiff files to correct");

//Process TIFF files in dir1
list = getFileList(dir1);
for (i=0; i<list.length; i++) {
	print("list["+i+"] = "+list[i]);
	s = toLowerCase(list[i]);
	if (!endsWith(s, ".tif") && !endsWith(s, ".tiff")) continue;
	processFile(list[i]);
}

roiManager("reset");
run("Close All");
setBatchMode(false);
restoreSettings();//restore user options
setTool(currentTool);
print("DONE");


/*
 * FUNCTIONS
 */


/** Processes lif files
 * Requires run("Bio-Formats Macro Extensions") */
function processFile(fname) {
	roiManager("reset");
	path=dir1+fname;
	print("Processing the file = " + fname);
	open(path);
	if (Overlay.size==0) {
		print(fname+" has no overlay: sipped)"
		close();
		return;
	}
	Stack.getDimensions(width, height, channels, slices, frames);
	Stack.setPosition(channels, slices/2, 1);
	msg = "Click inside ROIs to be deleted"+
		"\n and add to ROI Manager by 't' or 'Ctrl t'";
	Dialog.createNonBlocking("ROIs deletion from overlay");
	Dialog.addMessage(msg);
	Dialog.show();
	nPoints = roiManager("count");
	X = newArray(nPoints); Y = newArray(nPoints); 
	for (i=0; i<nPoints; i++) {
		roiManager("select", i);
		Roi.getBounds(x, y, width, height);
		X[i] = x; Y[i] = y;
	}
	roiManager("reset");
	run("To ROI Manager");
	nRois = roiManager("count");
	for (j=nRois-1; j>=0; j--) {
		roiManager("select", j);
		for (i=0; i<nPoints; i++) {
			if (Roi.contains(X[i], Y[i])) {
				roiManager("delete");
				break;
			}
		}
	}
	roiManager("show all without labels");
	save(path);
	close();
	roiManager("reset");
}
