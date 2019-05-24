/* May 2019
 * Bertrand Vernay
 * vernayb@igbmc.fr
 *  
 *  1- Convert .lif to .tiff and apply a gamma vamue of 0.45
 *  2- Option for flatfield
 *  
 */ 


macro "Brightfield Leica Colour Camera RGB lif to tif [F1]"{

// INITIALISE MACRO
print("\\Clear");
roiManager("reset");
setBatchMode(true);
run("Bio-Formats Macro Extensions");

//Close Images
while (nImages > 0){
	close();
}

// INPUT/OUTPUT
dir1 = getDirectory("Select the directory containing the lif files to convert");
dir2 = getDirectory("Select the directory where to save the converted files");
list = getFileList(dir1);

// PROCESS LIF FILES
for (i = 0; i < list.length; i++) {
	path=dir1+list[i];
	indexDot=indexOf(list[i], ".lif");
	fileNameWithoutExtension=substring(list[i], 0, indexDot);
	print(fileNameWithoutExtension);
	Ext.setId(path);
	Ext.getCurrentFile(list[i]);
	Ext.getSeriesCount(seriesCount); 
	for (j=0; j<seriesCount; j++) {
        Ext.setSeries(j);
        Ext.getSeriesName(seriesName);
        print(seriesName);
		run("Bio-Formats Importer", "open=&path color_mode=Default view=Hyperstack stack_order=XYCZT series_"+j+1); 
        originalID=getImageID();
        originalTitle=getTitle();
        print(originalTitle);
		run("Split Channels");
		for (k = 1; k <4 ; k++){	
			selectWindow("C"+k+"-"+originalTitle);
			//run("Brightness/Contrast...");
			setMinAndMax(0, 4095);
			call("ij.ImagePlus.setDefault16bitRange", 12);
			run("Apply LUT");
			run("Gamma...", "value=0.45");
		}
		image1="C1-"+fileNameWithoutExtension+".lif - "+seriesName;
		//print(image1);
		//image2="C2-"+fileNameWithoutExtension+".lif - "+seriesName;
		print(image2);		
		image3="C3-"+fileNameWithoutExtension+".lif - "+seriesName;
		//print(image3);		
		run("Merge Channels...", "c1=["+image1+"] c2=["+image2+"] c3=["+image3+"]");
		saveAs("tiff", dir2+fileNameWithoutExtension+"_"+seriesName+".tif");
		run("Close");
	}
}

setBatchMode(false);
print("DONE");
}	


macro "Brightfield Leica Colour Camera Flatfield Correction [F2]"{

// INITIALISE MACRO
print("\\Clear");
roiManager("reset");
setBatchMode(true);

//Close Images
while (nImages > 0){
	close();
}

// INPUT/OUTPUT
dir1 = getDirectory("Select the directory containing the TIF files to correct");
dir2 = getDirectory("Select the directory where to save the corrected files");
list = getFileList(dir1);

// VARIABLES
var flatfieldFile, meanFlatfield;

Dialog.create("Flatfield file");
Dialog.addChoice("Flatfield Image:", list);
Dialog.show();
flatfieldFile = Dialog.getChoice();
print("Using "+flatfieldFile+ " as flatfield reference");
open(dir1+flatfieldFile);
getStatistics(area, mean, min, max, std, histogram);
meanFlatfield = mean;
for (i = 0; i < 10; i++) {
	path = dir1 + list[i];
	open(path);
	fileNameWithoutExtension = File.nameWithoutExtension();
	currentFile = list[i];
	run("Calculator Plus", "i1="+currentFile+" i2="+flatfieldFile+" operation=[Divide: i2 = (i1/i2) x k1 + k2] k1="+meanFlatfield+" k2=0 create");
	saveAs("tiff", dir2+fileNameWithoutExtension+"_corrected.tif");
	print(list[i]+" processed");
}
print("DONE");
}
