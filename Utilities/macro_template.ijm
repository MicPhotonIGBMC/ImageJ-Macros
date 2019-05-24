/* May 2019
 * Bertrand Vernay
 * vernayb@igbmc.fr
 *  
 * Title: 
 * Data: 
 * Dimensions: 
 * Label: 
 *  
 * Tools used: 
 * 	 
 *  References/Citation:
 *  
 */ 

macro "name of macro [F1]"{

// INITIALISE MACRO
print("\\Clear");
roiManager("reset");
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

// INPUT/OUTPUT
dir1 = getDirectory("Select the directory containing the lif files to analyse");
dir2 = getDirectory("Select the save directory");
list = getFileList(dir1);


// PROCESS LIF FILES
for (i = 0; i < list.length; i++) {
	/*
	 * 
	 *  YOUR CODE
	 * 
	 */
	
}

setBatchMode(false);
print("DONE");


/*
 * FUNCTIONS
 * 
*/