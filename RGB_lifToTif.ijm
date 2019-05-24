macro "Brightfield Leica Colour Camera RGB lif to tif [F1]"{

// INITIALISE MACRO
print("\\Clear");
roiManager("reset");
run("Bio-Formats Macro Extensions");	//enable macro functions for Bio-formats Plugin
setBatchMode(true);

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
		print(image1);
		image2="C2-"+fileNameWithoutExtension+".lif - "+seriesName;
		print(image2);		
		image3="C3-"+fileNameWithoutExtension+".lif - "+seriesName;
		print(image3);		
		run("Merge Channels...", "c1=["+image1+"] c2=["+image2+"] c3=["+image3+"]");
		saveAs("tiff", dir2+fileNameWithoutExtension+"_"+seriesName+".tif");
		run("Close");
	}
}

setBatchMode(false);
print("DONE");

}	