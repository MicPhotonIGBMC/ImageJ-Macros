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

inputDir = getDirectory("Choose the source directory");
print(inputDir);
outputDir = getDirectory("Choose the target directory");
print(outputDir);

// list is an array
myList = getFileList(inputDir);
//Array.print(myList);
//Array.show(myList);

for (i = 0; i < myList.length ; i++) {
	print("File = "+myList[i]);
	path = inputDir+myList[i];
	if (endsWith(path, ".TIF")){
		index01 = indexOf(myList[i], "_s");
		index02 = indexOf(myList[i], ".TIF");
		print("PROCESSING "+myList[i], index01, index02);
		indexNameROI = substring(myList[i], index01+1, index02);
		print(indexNameROI);
		nameROI = indexNameROI+"_RoiSet.zip";
		print("Processing ROI "+nameROI);
		roiManager("reset");
		open(inputDir+nameROI);	
		open(inputDir+myList[i]);
		fileNameNoExt = File.nameWithoutExtension;
		//waitForUser("Debug");
		originalID = getImageID();
		// select a ROI, index starts at 0
		numberROI = roiManager("count");
		print("Number of ROI to process "+numberROI);
		processROI();
		roiManager("reset");
		selectImage(originalID);
		close();
		print("*********************************");
	}
}
selectWindow("Log");
saveAs("text", outputDir+"log.txt");
print("***** DONE *****");




function processROI(){
for (r = 0; r < numberROI; r++) {
	selectImage(originalID);
	roiManager("Select", r);
	//print(i);
	run("Duplicate...", "duplicate");
	duplicateID = getImageID();
	//waitForUser("Debug");
	run("Clear Outside", "stack");
	saveAs("tiff", outputDir+fileNameNoExt+"_"+r);
	selectImage(duplicateID);
	close();
	//waitForUser("Debug");
	}
}