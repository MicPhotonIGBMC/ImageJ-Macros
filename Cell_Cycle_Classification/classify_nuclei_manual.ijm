/* July 2019 - August 2019
 * First version by Bertrand Vernay
 * vernayb@igbmc.fr
 * Later versions by Marcel Boeglin
 * boeglin@igbmc.fr
 * For: Michail AMOIRIDIS 
 * (Soutgoglou Team: http://www.igbmc.fr/research/department/1/team/28/) 
 *  
 * Manual classification of Cell Nuclei obtained by 'extract_nuclei.ijm'
 * Input data: tiff files
 * Dimensions: 4 channels stack
 * Labels: 
 * 	 channel 1 = H3Ser10 (AF647) : marker G2
 *   channel 2 = Edu (AF594): DNA synthesis
 *   channel 3 = Top2a (AF488)
 *   channel 4 = DAPI
 */ 

// INITIALISE
print("\\Clear");
setBatchMode(false);
if (isOpen("Results")) {
	selectWindow("Results");
	run("Close");
} 
while (nImages>0) close();//Close Images
run("Overlay Options...", "stroke=none width=0 fill=none");

//Variables to be modified if markers are changed
var markers = newArray("H3Ser10", "Edu", "Top2a", "DAPI");
//var channelColors = newArray("Magenta", "Red", "Green", "Cyan");
var channelColors = newArray("Gray", "Red", "Green", "Blue");
var stages = newArray("G1", "early S", "mid S stage 1", "mid S stage 2", "Late S",
					"G2", "Other", "Unclassified");

// VARIABLES
var list;
var extensionlessFname;
var extension;
dbug = true;
dbug = false;
dialogWidth = 151;
dialogHeight = 315;
dialogX = screenWidth() * 0.8 - dialogWidth;
dialogY = screenHeight() * 0.8 - dialogHeight;
currentDialogX = dialogX;
currentDialogY = dialogY;


// INPUT-OUTPUT
dir1 = getDirectory("Select the directory containing the nuclei to analyse");
list = getFileList(dir1);
list = keepTIFFs(list);
if (list.length<1) {
	showMessage("Input folder seems not to contain TIFF files");
	return;
}
if (!File.exists(dir1+"//done"))
	File.makeDirectory(dir1+"done");

for (i=0; i<list.length; i++) {// PROCESS TIFF FILES
	extension = substring(list[i], lastIndexOf(list[i], "."));
	path=dir1+list[i];
	open(path); id = getImageID();
	if (selectionType()>=0 && selectionType()<=4) {
		run("Clear Outside", "stack");
		run("Select None");
	}
	run("Select None");
	title = getTitle();
	extensionlessFname = File.nameWithoutExtension ;
	if (!channelMontage(id)) {
		close();
		return;
	}
	setSlice(floor(nSlices/2));
	run("View 100%");
	zoom = 400;
	getLocationAndSize(x, y, width, height);
	//print("x = "+x + "  y = "+y + "  width = "+width + "  height = "+height);
	if (width*4>screenWidth || height*4>screenHeight) zoom=300;
	if (width*3>screenWidth || height*3>screenHeight) zoom=200;
	if (width*2>screenWidth || height*2>screenHeight) zoom=150;
	if (width*1.5>screenWidth || height*1.5>screenHeight) zoom=100;
	//print("zoom = "+zoom);
	run("Set... ", "zoom="+zoom);
	resetMinAndMax();
	rename(title);
	getLocationAndSize(x, y, width, height);
	x2 = dialogX - width - 50;
	y2 = dialogY - height - 50;
	if (x2<0) {
		currentDialogX = dialogX - x2;
		x2 = 0;
	}
	if (y2<200) {
		currentDialogY = dialogY - 200;
		y2 = 200;
	}
	setLocation(x2, y2);
	run("Set... ", "zoom="+zoom/2);//forces zoom actualization
	run("Set... ", "zoom="+zoom);
	classifyNuclei(extensionlessFname);
}


/* FUNCTIONS */

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
	newImage("Montage", type+" black", width*channels, height*3, slices);
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

	fontSize = 12;
	setFont("SansSerif", fontSize, " antialiased");
	strW = getStringWidth(markers[0]);
	if (strW>=width-2) {
		iter = 0;
		while (getStringWidth(markers[0])>width-2 && iter<12) {
			setFont("SansSerif", --fontSize, " antialiased");
			iter++;
		}
	}
	else if (strW<width-0) {
		iter = 0;
		while (getStringWidth(markers[0])>width-0 && iter<36) {
			setFont("SansSerif", ++fontSize, " antialiased");
			iter++;
		}
	}
	fh = getValue("font.height");
	setColor(channelColors[0]);
	Overlay.drawString(markers[0], 2, height*2.5+fh/2);//text, x, y
	setColor(channelColors[1]);
	strW = getStringWidth(markers[1]);
	Overlay.drawString(markers[1], 2+width+(width-strW)/2, height*2.5+fh/2);
	setColor(channelColors[2]);
	strW = getStringWidth(markers[2]);
	Overlay.drawString(markers[2], 2+width*2+(width-strW)/2, height*2.5+fh/2);
	setColor(channelColors[3]);
	strW = getStringWidth(markers[3]);
	Overlay.drawString(markers[3], 2+width*3+(width-strW)/2, height*2.5+fh/2);
	Overlay.show();
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
	Dialog.addRadioButtonGroup("Stages", stages, 8, 1, "Unclassified");
	Dialog.setLocation(currentDialogX, currentDialogY);
	Dialog.show;//must click OK, return doesn't work
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
	if (!dbug)
		File.rename(dir1+fileName+extension, dir1+"done//"+fileName+extension);
}
