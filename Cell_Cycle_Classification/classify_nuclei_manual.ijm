/* July 2019
 * Bertrand Vernay
 * vernayb@igbmc.fr
 * Marcel Boeglin
 * boeglin@igbmc.fr
 * For: Michail AMOIRIDIS 
 * (Soutgoglou Team: http://www.igbmc.fr/research/department/1/team/28/) 
 *  
 * Extraction of Cell Nuclei
 * Data: tif files
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

setBatchMode(false);

//Close Results table
if (isOpen("Results")) {
	selectWindow("Results");
	run("Close");
} 

//Close Images
while (nImages>0) close();

// DECLARE VARIABLES
var list;
var fileNameWithoutExtension;
var extension;

//screenW = screenWidth();
//screenH = screenHeight();
dialogX = screenWidth() - 400;
dialogY = screenHeight() - 600;

// INPUT/OUTPUT
dir1 = getDirectory("Select the directory containing the nuclei to analyse");
list = getFileList(dir1);
list = keepTIFFs(list);
//for (i=0; i<list.length; i++) print(list[i]);

if (!File.exists(dir1+"//done"))
	File.makeDirectory(dir1+"done");

// PROCESS TIFF FILES
for (i=0; i<list.length; i++) {
	extension = substring(list[i], lastIndexOf(list[i], "."));
	path=dir1+list[i];
	open(path); id = getImageID();
	title = getTitle();
	fileNameWithoutExtension = File.nameWithoutExtension ;
	if (!channelMontage(id)) {
		close();
		return;
	}
	run("View 100%");
	setSlice(floor(nSlices/2));
	run("Set... ", "zoom=400");
	resetMinAndMax();
	run("Enhance Contrast", "saturated=0.35");
	rename(title);
	classifyNuclei(fileNameWithoutExtension);
}

/*
 * 
 * FUNCTIONS
 * 
 */

/** replaces channels of a XYZC hyperstack by a montage.
 * output image is a XYZ stack. */
function channelMontage(imageid) {
	Stack.getDimensions(width, height, channels, slices, frames);
	if (frames>1) {
		showMessage("channelMontage doesn't manage time dimension");
		return false;
	}
	selectImage(imageid);
	bd = bitDepth();//8, 16, 24, 32
	//print("bd = "+bd);
	type = "8-bit";
	if (bd==16) type = "16-bit";
	else if (bd==24) type = "RGB Color";
	else if (bd==32) type = "32-bit";
	//type = "RGB Color";
	setBatchMode(true);
	newImage("Montage", type+" black", width*channels, height*2, slices);
	montageid = getImageID();
	for (i=1; i<=slices; i++) {
		selectImage(imageid);
		run("Duplicate...", "duplicate slices="+i);
		tmpid = getImageID();
		Stack.setDimensions(1, channels, 1);
		run("Make Montage...", "columns="+channels+" rows=1 scale=1");
		tmp2id = getImageID();
		run("Copy");
		selectImage(montageid);
		setSlice(i);
		makeRectangle(0, 0, width*channels, height);
		run("Paste");
		run("Enhance Contrast", "saturated=0.35");
		selectImage(tmpid); close();
		selectImage(tmp2id); close();
	}
	selectImage(montageid);
	makeRectangle(0, 0, width*channels, height);
	run("Duplicate...", "duplicate");
	tmp3id = getImageID();
	run("Z Project...", "projection=[Max Intensity]");
	rename("MAXPROJ");
	tmp4id = getImageID();
	run("Copy");
	selectImage(tmp4id); close();
	selectImage(tmp3id); close();
	selectImage(imageid); close();
	selectImage(montageid);
	makeRectangle(0, height, width*channels, height);
	for (i=1; i<=slices; i++) {
		setSlice(i);
		run("Paste");
	}
	setBatchMode(false);
	run("Select None");
	return true;
}

function keepTIFFs(files) {
	files2 = newArray(files.length);
	j = 0;
	for (i=0; i<files.length; i++) {
		if (!endsWith(toLowerCase(files[i]), ".tiff") &&
				!endsWith(toLowerCase(files[i]), ".tif")) continue;
		files2[j++] = files[i];
	}
	return Array.trim(files2, j);
}

function classifyNuclei(fileName) {
	Dialog.createNonBlocking("Classify nuclei");
	items = newArray("G1","early S", "mid S stage 1", "mid S stage 2",
					"G2", "Other", "Unclassified");
	//must click OK, return doesn't work:
	Dialog.addRadioButtonGroup("Stages", items, 7, 1, "Unclassified");
	Dialog.setLocation(dialogX, dialogY);
	Dialog.show;
	class = Dialog.getRadioButton;
	str = fileName+"_CLASS_"+class;
	if (File.exists(dir1+"classification.txt"))
		File.append(fileName+"\t"+class+"\r\n", dir1+"classification.txt");
	else
		File.saveString(fileName+"\t"+class+"\r\n", dir1+"classification.txt");
	if (File.exists(dir1+"classification2.txt"))
		File.append(str+"\r\n", dir1+"classification2.txt");
	else
		File.saveString(str+"\r\n", dir1+"classification2.txt");
	close();
	File.rename(dir1+fileName+extension, dir1+"done//"+fileName+extension);
}
