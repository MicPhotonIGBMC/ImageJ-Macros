/* July 2019
 * Bertrand Vernay
 * vernayb@igbmc.fr
 *  
 * For: Michail AMOIRIDIS (Soutgoglou Team: http://www.igbmc.fr/research/department/1/team/28/) 
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
roiManager("reset");
run("Bio-Formats Macro Extensions");	//enable macro functions for Bio-formats Plugin
setBatchMode(false);

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
var fileNameWithoutExtension;

// INPUT/OUTPUT
dir1 = getDirectory("Select the directory containing the nuclei to analyse");
list = getFileList(dir1);

// PROCESS LIF FILES
for (i = 0; i < list.length; i++) {
	path=dir1+list[i];
	open(path);
	Stack.setChannel(4);
	run("View 100%");
	run("Set... ", "zoom=800");
	fileNameWithoutExtension = File.nameWithoutExtension ;
	classifyNuclei(fileNameWithoutExtension);
}

/*
 * 
 * FUNCTIONS
 * 
 */

function classifyNuclei(fileName){
	Dialog.createNonBlocking("Classify nuclei");
	checkLabels = newArray("G1","early S", "mid S stage 1", "mid S stage 2", "G2", "Other", "Unknown");
	checkStates = newArray(0,0,0,0,0,0,0);
	Dialog.addCheckboxGroup(7, 1, checkLabels, checkStates);
	Dialog.show();
	g1Check = Dialog.getCheckbox();
		if (g1Check == 1) {	fileName= fileName+"_CLASS_G1";}
	earlySCheck = Dialog.getCheckbox();
		if (earlySCheck == 1) {	fileName= fileName+"_CLASS_earlyS";}
	midS1Check = Dialog.getCheckbox();
		if (midS1Check == 1) {	fileName= fileName+"_CLASS_midS-stage1";}
	midS2Check = Dialog.getCheckbox();
		if (midS2Check == 1) {	fileName= fileName+"_CLASS_midS-stage2";}
	g2Check = Dialog.getCheckbox();
		if (g2Check == 1) {	fileName= fileName+"_CLASS_G2";}
	otherCheck = Dialog.getCheckbox();
		if (otherCheck == 1) {	fileName= fileName+"_CLASS_other";}		
	unknownCheck = Dialog.getCheckbox();
		if (unknownCheck == 1) {	fileName= fileName+"_CLASS_unknown";}
	//print(g1Check, earlySCheck, midS1Check, midS2Check, g2Check, otherCheck, unknownCheck);
	print(fileName);
	close();
}
selectWindow("Log");
saveAs("text", dir1+"Log.txt");