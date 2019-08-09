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

//VARIABLES
var fileNameWithoutExtension;
roiOption = "Selection";

// INPUT/OUTPUT
dir1 = getDirectory("Select the directory containing the lif files to analyse");
dir2 = dir1;
fs = File.separator;
if (endsWith(dir2, fs)) dir2 = substring(dir2, 0, lastIndexOf(dir2, fs));
dir2 += "_extractedNuclei"+fs;
if (!File.exists(dir2)) File.makeDirectory(dir2);

items = newArray("Selection", "Overlay");
Dialog.create("Extract Nuclei From Overlay");
Dialog.addMessage("");
Dialog.addChoice("ROI in output image", items, roiOption);
Dialog.show();
roiOption = Dialog.getChoice();

//Process LIF files in dir1
list = getFileList(dir1);
for (i=0; i<list.length; i++) {
	//print("list["+i+"] = "+list[i]);
	s = toLowerCase(list[i]);
	if (!endsWith(s, ".tif") && !endsWith(s, ".tiff")) continue;
	indexDot=indexOf(s, ".tif");
	fileNameWithoutExtension=substring(list[i], 0, indexDot);
	//print(fileNameWithoutExtension);
	processFile(list[i]);
}

roiManager("reset");
run("Close All");
setBatchMode(false);
restoreSettings();//restore user options
print("DONE");


/** Processes lif files
 * Requires run("Bio-Formats Macro Extensions") */
function processFile(fname) {
	path=dir1+fname;
	print("Processing file:\n" + fname);
	open(path);
	id=getImageID();
	title = fileNameWithoutExtension;
	//print("Image name: "+title);
	title = replace(title,"/","_");//prevent error with Mark and find files
	//print("After replacement title = "+title);
	extractSingleNuclei(id, title);
	run("Close All");
}

/** Extracts detected nuclei from image with ID 'id' and title 'title'
 * The image must have an overlay containing the nuclei ROIs
 * Extracted nuclei images are saved to output folder with individual ROIs
 * @id: the ID of image from which extract nuclei labeled in overlay
 * @title: the title of image from which extract nuclei */
function extractSingleNuclei(id, title) {
	//print(title+"");
	if (Overlay.size<1) {
		print("No overlay to get Rois from: skipped");
		return;
	}
	roiManager("reset");//empty ROI Manager
	run("To ROI Manager");
	print("outputnames:");
	for (i=0; i<roiManager("count"); i++) {
		selectImage(id);
		roiManager("select", i);
		run("Duplicate...", "duplicate");
		//run("Clear Outside", "stack");
		//run("Select None");
		run("Grays");
		if (roiOption=="Overlay") {
			Overlay.addSelection();
			Overlay.setPosition(0);
			run("Select None");
		}
		outputname = title+"_Nucleus"+i+".tif";
		print(outputname);
		saveAs("tiff", dir2+outputname);
		close();
	}
}